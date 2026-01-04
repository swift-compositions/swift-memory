// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-memory open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-memory project authors
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
    extension Memory.Map {
        /// Creates a memory-mapped region from a file descriptor.
        ///
        /// - Parameters:
        ///   - fileDescriptor: The POSIX file descriptor to map.
        ///   - range: The range to map (offset will be aligned to allocation granularity).
        ///   - access: The access mode (default: `.read`).
        ///   - sharing: The sharing mode (default: `.shared`).
        ///   - safety: The safety mode (defaults based on access).
        /// - Throws: `Memory.Error` if mapping fails.
        ///
        /// ## Copy-on-Write
        ///
        /// To create a copy-on-write mapping, use `.private` sharing with write access:
        /// ```swift
        /// let region = try Memory.Map(
        ///     fileDescriptor: fd,
        ///     range: .whole,
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
        ) throws(Memory.Error) {
            // Phase 1: All validation and computation (no resources acquired)
            try access.validate()

            let effectiveSafety = safety ?? (access.allows.write ? .default.write : .default.read)

            let userLen: Int
            switch range {
            case .bytes(_, let length):
                userLen = length
            case .whole:
                let fileStats: Kernel.File.Stats
                do throws(Kernel.File.Stats.Error) {
                    fileStats = try Kernel.File.Stats.get(descriptor: fileDescriptor)
                } catch {
                    throw .stat(error)
                }
                userLen = Int(fileStats.size)
                guard userLen > 0 else {
                    throw .size
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
        ) throws(Memory.Error) -> (UnsafeMutableRawPointer, Memory.Lock.Token?) {
            // Map the file
            let baseAddress: UnsafeMutableRawPointer
            do throws(Kernel.Memory.Map.Error) {
                baseAddress = try Kernel.Memory.Map.map(
                    length: Kernel.File.Size(mappingLen),
                    protection: access.kernelProtection,
                    flags: sharing.kernelFlags,
                    fd: fileDescriptor,
                    offset: Kernel.File.Offset(alignedOffset)
                )
            } catch {
                throw Memory.Error(from: error)
            }

            // Acquire lock if needed
            let lockToken: Memory.Lock.Token?
            if case .coordinated(let kind, let scope) = effectiveSafety {
                let lockRange = computeLockRange(
                    scope: scope,
                    alignedOffset: alignedOffset,
                    mappingLength: mappingLen
                )
                do {
                    lockToken = try Memory.Lock.Token(
                        descriptor: fileDescriptor,
                        range: lockRange,
                        kind: kind
                    )
                } catch {
                    try? Kernel.Memory.Map.unmap(addr: baseAddress, length: Kernel.File.Size(mappingLen))
                    throw .lock(error)
                }
            } else {
                lockToken = nil
            }

            return (baseAddress, lockToken)
        }

    }
#endif

// MARK: - Lock Range Computation (Shared)

extension Memory.Map {
    /// Computes the lock range based on scope.
    ///
    /// For `.mapped`, the lock range is rounded to the platform's mapping granularity:
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
        case .mapped:
            let granularity = Kernel.System.allocationGranularity
            let end = alignedOffset + mappingLength
            let roundedEnd = Kernel.System.alignUp(end, to: granularity)
            return .bytes(start: Kernel.File.Offset(alignedOffset), end: Kernel.File.Offset(roundedEnd))
        }
    }
}

// MARK: - File-backed Initialization (Windows)

#if os(Windows)
    extension Memory.Map {
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
        /// - Throws: `Memory.Error` if mapping fails.
        public static func open(
            fileHandle: Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(Memory.Error) -> Self {
            // Validate access
            try access.validate()

            let effectiveSafety = safety ?? (access.allows.write ? .default.write : .default.read)

            // Compute user length
            let userLen: Int
            switch range {
            case .bytes(_, let length):
                userLen = length
            case .whole:
                var fileSize = LARGE_INTEGER()
                guard GetFileSizeEx(fileHandle.rawValue, &fileSize) else {
                    throw .map(.map(.captureLastError()))
                }
                userLen = Int(fileSize.QuadPart)
                guard userLen > 0 else {
                    throw .size
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
            let mapping: Kernel.Memory.Map.WindowsMapping
            do throws(Kernel.Memory.Map.Error) {
                mapping = try Kernel.Memory.Map.mapFile(
                    handle: fileHandle.rawValue,
                    offset: Int64(alignedOffset),
                    length: mappingLen,
                    protection: access.kernelProtection,
                    copyOnWrite: sharing == .private
                )
            } catch {
                throw Memory.Error(from: error)
            }

            // Acquire lock if needed
            let lockToken: Memory.Lock.Token?
            if case .coordinated(let kind, let scope) = effectiveSafety {
                let lockRange = computeLockRange(
                    scope: scope,
                    alignedOffset: alignedOffset,
                    mappingLength: mappingLen
                )
                do {
                    lockToken = try Memory.Lock.Token(
                        descriptor: fileHandle,
                        range: lockRange,
                        kind: kind
                    )
                } catch {
                    try? Kernel.Memory.Map.unmap(mapping)
                    throw .lock(error)
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
    extension Memory.Map {
        /// Creates an anonymous memory mapping (not backed by a file).
        ///
        /// Anonymous mappings are backed by swap/memory only.
        ///
        /// - Parameters:
        ///   - length: The number of bytes to map.
        ///   - access: The access mode (default: `[.read, .write]`).
        ///   - sharing: The sharing mode (default: `.private`).
        /// - Throws: `Memory.Error` if mapping fails.
        public init(
            anonymousLength length: Int,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(Memory.Error) {
            try access.validate()

            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(length, to: pageSize)

            let region: Kernel.Memory.Map.Region
            do throws(Kernel.Memory.Map.Error) {
                region = try Kernel.Memory.Map.Anonymous.map(
                    length: Kernel.File.Size(mappingLen),
                    protection: access.kernelProtection,
                    shared: sharing == .shared
                )
            } catch {
                throw Memory.Error(from: error)
            }

            self.mappingBaseAddress = region.base
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
    extension Memory.Map {
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
        /// - Throws: `Memory.Error` if mapping fails.
        public static func anonymous(
            length: Int,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(Memory.Error) -> Self {
            try access.validate()

            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(length, to: pageSize)

            let mapping: Kernel.Memory.Map.WindowsMapping
            do {
                mapping = try Kernel.Memory.Map.mapAnonymous(
                    length: mappingLen,
                    protection: access.kernelProtection
                )
            } catch {
                throw Memory.Error(from: error)
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
    extension Memory.Map {
        /// Creates a memory-mapped region from a file descriptor with a specific mmap offset.
        ///
        /// This is used for special mappings like io_uring ring buffers where the
        /// offset is not a file offset but a magic value that selects a specific region.
        ///
        /// ## io_uring Example
        ///
        /// ```swift
        /// // Map the io_uring SQ ring
        /// let sqRing = try Memory.Map(
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
        /// - Throws: `Memory.Error` if mapping fails.
        public init(
            fileDescriptor: Kernel.Descriptor,
            mmapOffset: Int64,
            length: Int,
            access: Access = [.read, .write],
            sharing: Sharing = .shared
        ) throws(Memory.Error) {
            try access.validate()

            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(length, to: pageSize)

            let baseAddress: UnsafeMutableRawPointer
            do {
                baseAddress = try Kernel.Memory.Map.map(
                    length: mappingLen,
                    protection: access.kernelProtection,
                    flags: sharing.kernelFlags,
                    fd: fileDescriptor,
                    offset: mmapOffset
                )
            } catch {
                throw Memory.Error(from: error)
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
