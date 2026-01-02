// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-mmap open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-mmap project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Kernel

#if os(Windows)
    internal import WinSDK
#endif

// MARK: - File-backed Initialization (POSIX)

#if !os(Windows)
    extension MMap.Region {
        /// Creates a memory-mapped region from a file descriptor.
        ///
        /// - Parameters:
        ///   - fileDescriptor: The POSIX file descriptor to map.
        ///   - range: The range to map (offset will be aligned to allocation granularity).
        ///   - access: The access mode (default: `.read`).
        ///   - sharing: The sharing mode (default: `.shared`).
        ///   - safety: The safety mode (defaults based on access).
        /// - Throws: `MMap.Error` if mapping fails.
        ///
        /// ## Copy-on-Write
        ///
        /// To create a copy-on-write mapping, use `.private` sharing with write access:
        /// ```swift
        /// let region = try MMap.Region(
        ///     fileDescriptor: fd,
        ///     range: .wholeFile,
        ///     access: [.read, .write],
        ///     sharing: .private  // Changes are private to this mapping
        /// )
        /// ```
        public init(
            fileDescriptor: Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(MMap.Error) {
            // Phase 1: All validation and computation (no resources acquired)
            try access.validate()

            let effectiveSafety = safety ?? (access.allowsWrite ? .defaultForWrite : .defaultForRead)

            let userLen: Int
            switch range {
            case .bytes(_, let length):
                userLen = length
            case .wholeFile:
                let fileStat: Kernel.Stat
                do {
                    fileStat = try Kernel.File.stat(fileDescriptor)
                } catch {
                    throw .statFailed(error)
                }
                userLen = Int(fileStat.size)
                guard userLen > 0 else {
                    throw .fileTooSmall
                }
            }

            let requestedOffset = range.offset
            let granularity = Kernel.System.allocationGranularity
            let alignedOffset = Kernel.System.alignDown(requestedOffset, to: granularity)
            let delta = requestedOffset - alignedOffset
            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(userLen + delta, to: pageSize)

            // Phase 2: Acquire resources using helper that handles cleanup
            let (baseAddress, lockToken) = try Self.acquireResources(
                fileDescriptor: fileDescriptor,
                alignedOffset: alignedOffset,
                mappingLen: mappingLen,
                access: access,
                sharing: sharing,
                effectiveSafety: effectiveSafety
            )

            // Phase 3: Initialize all stored properties (no throws after this point)
            self.mappingBaseAddress = baseAddress
            self.mappingLength = mappingLen
            self.offsetDelta = delta
            self.userLength = userLen
            self.access = access
            self.sharing = sharing
            self.safety = effectiveSafety
            self.lockToken = lockToken
        }

        /// Acquires mapping and lock resources, handling cleanup on failure.
        private static func acquireResources(
            fileDescriptor: Kernel.Descriptor,
            alignedOffset: Int,
            mappingLen: Int,
            access: Access,
            sharing: Sharing,
            effectiveSafety: Safety
        ) throws(MMap.Error) -> (UnsafeMutableRawPointer, MMap.Lock.Token?) {
            // Map the file
            let baseAddress: UnsafeMutableRawPointer
            do {
                baseAddress = try Kernel.Mmap.map(
                    length: mappingLen,
                    protection: access.kernelProtection,
                    flags: sharing.kernelFlags,
                    fd: fileDescriptor,
                    offset: Int64(alignedOffset)
                )
            } catch {
                throw MMap.Error(from: error)
            }

            // Acquire lock if needed
            let lockToken: MMap.Lock.Token?
            if case .coordinated(let kind, let scope) = effectiveSafety {
                let lockRange = computeLockRange(
                    scope: scope,
                    alignedOffset: alignedOffset,
                    mappingLength: mappingLen
                )
                do {
                    lockToken = try MMap.Lock.Token(
                        descriptor: fileDescriptor,
                        range: lockRange,
                        kind: kind
                    )
                } catch {
                    try? Kernel.Mmap.unmap(addr: baseAddress, length: mappingLen)
                    throw .lockFailed(error)
                }
            } else {
                lockToken = nil
            }

            return (baseAddress, lockToken)
        }

    }
#endif

// MARK: - Lock Range Computation (Shared)

extension MMap.Region {
    /// Computes the lock range based on scope.
    ///
    /// For `.mappedRange`, the lock range is rounded to the platform's mapping granularity:
    /// - POSIX: page size
    /// - Windows: allocation granularity (64KB typically)
    ///
    /// This ensures the lock covers exactly the memory region that could be faulted.
    ///
    /// - Note: Rounding may lock bytes beyond the logical user-requested range.
    ///   This is intentional: the lock must cover every byte that the OS mapping
    ///   could fault on, which includes the padding bytes up to the next granularity
    ///   boundary.
    static func computeLockRange(
        scope: Safety.Scope,
        alignedOffset: Int,
        mappingLength: Int
    ) -> Kernel.Lock.Range {
        switch scope {
        case .file:
            return .file
        case .mappedRange:
            let granularity = Kernel.System.allocationGranularity
            let end = alignedOffset + mappingLength
            let roundedEnd = Kernel.System.alignUp(end, to: granularity)
            return .bytes(start: UInt64(alignedOffset), end: UInt64(roundedEnd))
        }
    }
}

// MARK: - File-backed Initialization (Windows)

#if os(Windows)
    extension MMap.Region {
        /// Creates a memory-mapped region from a Windows file handle.
        ///
        /// This is a static factory method that works around Swift compiler bugs
        /// on Windows where throwing inits on ~Copyable structs with Optional<Class>
        /// fields generate incorrect SIL.
        ///
        /// - Parameters:
        ///   - fileHandle: The Windows file handle to map.
        ///   - range: The range to map (offset will be aligned to allocation granularity).
        ///   - access: The access mode (default: `.read`).
        ///   - sharing: The sharing mode (default: `.shared`).
        ///   - safety: The safety mode (defaults based on access).
        /// - Returns: A new `Region` mapping the file.
        /// - Throws: `MMap.Error` if mapping fails.
        public static func open(
            fileHandle: Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(MMap.Error) -> Self {
            // Validate access
            try access.validate()

            let effectiveSafety = safety ?? (access.allowsWrite ? .defaultForWrite : .defaultForRead)

            // Compute user length
            let userLen: Int
            switch range {
            case .bytes(_, let length):
                userLen = length
            case .wholeFile:
                var fileSize = LARGE_INTEGER()
                guard GetFileSizeEx(fileHandle.rawValue, &fileSize) else {
                    throw .fromWindowsError(GetLastError(), operation: "GetFileSizeEx")
                }
                userLen = Int(fileSize.QuadPart)
                guard userLen > 0 else {
                    throw .fileTooSmall
                }
            }

            // Compute alignment
            let requestedOffset = range.offset
            let granularity = Kernel.System.allocationGranularity
            let alignedOffset = Kernel.System.alignDown(requestedOffset, to: granularity)
            let delta = requestedOffset - alignedOffset
            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(userLen + delta, to: pageSize)

            // Map the file
            let mapping: Kernel.Mmap.WindowsMapping
            do {
                mapping = try Kernel.Mmap.mapFile(
                    handle: fileHandle.rawValue,
                    offset: Int64(alignedOffset),
                    length: mappingLen,
                    protection: access.kernelProtection,
                    copyOnWrite: sharing == .private
                )
            } catch {
                throw MMap.Error(from: error)
            }

            // Acquire lock if needed
            let lockToken: MMap.Lock.Token?
            if case .coordinated(let kind, let scope) = effectiveSafety {
                let lockRange = computeLockRange(
                    scope: scope,
                    alignedOffset: alignedOffset,
                    mappingLength: mappingLen
                )
                do {
                    lockToken = try MMap.Lock.Token(
                        descriptor: fileHandle,
                        range: lockRange,
                        kind: kind
                    )
                } catch {
                    try? Kernel.Mmap.unmap(mapping)
                    throw .lockFailed(error)
                }
            } else {
                lockToken = nil
            }

            return Self(
                mappingBaseAddress: mapping.baseAddress,
                mappingLength: mappingLen,
                mappingHandle: mapping.mappingHandle,
                offsetDelta: delta,
                userLength: userLen,
                access: access,
                sharing: sharing,
                safety: effectiveSafety,
                lockToken: lockToken
            )
        }
    }
#endif

// MARK: - Anonymous Mapping (POSIX)

#if !os(Windows)
    extension MMap.Region {
        /// Creates an anonymous memory mapping (not backed by a file).
        ///
        /// Anonymous mappings are backed by swap/memory only.
        ///
        /// - Parameters:
        ///   - length: The number of bytes to map.
        ///   - access: The access mode (default: `[.read, .write]`).
        ///   - sharing: The sharing mode (default: `.private`).
        /// - Throws: `MMap.Error` if mapping fails.
        public init(
            anonymousLength length: Int,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(MMap.Error) {
            try access.validate()

            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(length, to: pageSize)

            let baseAddress: UnsafeMutableRawPointer
            do {
                baseAddress = try Kernel.Mmap.mapAnonymous(
                    length: mappingLen,
                    protection: access.kernelProtection,
                    shared: sharing == .shared
                )
            } catch {
                throw MMap.Error(from: error)
            }

            self.mappingBaseAddress = baseAddress
            self.mappingLength = mappingLen
            self.offsetDelta = 0
            self.userLength = length
            self.access = access
            self.sharing = sharing
            self.safety = .unchecked
            self.lockToken = nil
        }
    }
#endif

// MARK: - Anonymous Mapping (Windows)

#if os(Windows)
    extension MMap.Region {
        /// Creates an anonymous memory mapping (backed by the system pagefile).
        ///
        /// This is a static factory method that works around Swift compiler bugs
        /// on Windows where throwing inits on ~Copyable structs generate incorrect SIL.
        ///
        /// - Parameters:
        ///   - length: The number of bytes to map.
        ///   - access: The access mode (default: `[.read, .write]`).
        ///   - sharing: The sharing mode (default: `.private`).
        /// - Returns: A new anonymous `Region`.
        /// - Throws: `MMap.Error` if mapping fails.
        public static func anonymous(
            length: Int,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(MMap.Error) -> Self {
            try access.validate()

            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(length, to: pageSize)

            let mapping: Kernel.Mmap.WindowsMapping
            do {
                mapping = try Kernel.Mmap.mapAnonymous(
                    length: mappingLen,
                    protection: access.kernelProtection
                )
            } catch {
                throw MMap.Error(from: error)
            }

            return Self(
                mappingBaseAddress: mapping.baseAddress,
                mappingLength: mappingLen,
                mappingHandle: mapping.mappingHandle,
                offsetDelta: 0,
                userLength: length,
                access: access,
                sharing: sharing,
                safety: .unchecked,
                lockToken: nil
            )
        }
    }
#endif

// MARK: - Special Offset Mapping (Linux)

#if os(Linux)
    extension MMap.Region {
        /// Creates a memory-mapped region from a file descriptor with a specific mmap offset.
        ///
        /// This is used for special mappings like io_uring ring buffers where the
        /// offset is not a file offset but a magic value that selects a specific region.
        ///
        /// ## io_uring Example
        ///
        /// ```swift
        /// // Map the io_uring SQ ring
        /// let sqRing = try MMap.Region(
        ///     fileDescriptor: ringFd,
        ///     mmapOffset: Kernel.IOUring.MmapOffset.sqRing,
        ///     length: sqRingSize,
        ///     access: [.read, .write],
        ///     sharing: .shared
        /// )
        /// ```
        ///
        /// - Parameters:
        ///   - fileDescriptor: The file descriptor to map (e.g., io_uring fd).
        ///   - mmapOffset: The mmap offset (e.g., `Kernel.IOUring.MmapOffset.sqRing`).
        ///   - length: Number of bytes to map.
        ///   - access: The access mode (default: `[.read, .write]`).
        ///   - sharing: The sharing mode (default: `.shared`).
        /// - Throws: `MMap.Error` if mapping fails.
        public init(
            fileDescriptor: Kernel.Descriptor,
            mmapOffset: Int64,
            length: Int,
            access: Access = [.read, .write],
            sharing: Sharing = .shared
        ) throws(MMap.Error) {
            try access.validate()

            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(length, to: pageSize)

            let baseAddress: UnsafeMutableRawPointer
            do {
                baseAddress = try Kernel.Mmap.map(
                    length: mappingLen,
                    protection: access.kernelProtection,
                    flags: sharing.kernelFlags,
                    fd: fileDescriptor,
                    offset: mmapOffset
                )
            } catch {
                throw MMap.Error(from: error)
            }

            self.mappingBaseAddress = baseAddress
            self.mappingLength = mappingLen
            self.offsetDelta = 0
            self.userLength = length
            self.access = access
            self.sharing = sharing
            self.safety = .unchecked
            self.lockToken = nil
        }
    }
#endif
