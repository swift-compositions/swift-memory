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
        private static func computeLockRange(
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
#endif

// MARK: - File-backed Initialization (Windows)

#if os(Windows)
    extension MMap.Region {
        /// Creates a memory-mapped region from a Windows file handle.
        ///
        /// - Parameters:
        ///   - fileHandle: The Windows file handle to map.
        ///   - range: The range to map (offset will be aligned to allocation granularity).
        ///   - access: The access mode (default: `.read`).
        ///   - sharing: The sharing mode (default: `.shared`).
        ///   - safety: The safety mode (defaults based on access).
        /// - Throws: `MMap.Error` if mapping fails.
        ///
        /// - Note: Implementation uses a static helper to work around Swift compiler
        ///   SIL verification issues with typed throws and ~Copyable on Windows.
        public init(
            fileHandle: Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(MMap.Error) {
            // All throwing code must complete before any property assignment.
            // This works around a Swift SIL bug on Windows with typed throws + ~Copyable.
            let result = try Self._prepareFileMapping(
                fileHandle: fileHandle,
                range: range,
                access: access,
                sharing: sharing,
                safety: safety
            )

            // Initialize all stored properties at once (no throws after this point)
            self.mappingBaseAddress = result.baseAddress
            self.mappingLength = result.mappingLen
            self.mappingHandle = result.mappingHandle
            self.offsetDelta = result.delta
            self.userLength = result.userLen
            self.access = access
            self.sharing = sharing
            self.safety = result.effectiveSafety
            self.lockToken = result.lockToken
        }

        /// Prepares all values needed for file-backed mapping initialization.
        /// This static helper isolates all throwing code from property assignment.
        private static func _prepareFileMapping(
            fileHandle: Kernel.Descriptor,
            range: Range,
            access: Access,
            sharing: Sharing,
            safety: Safety?
        ) throws(MMap.Error) -> (
            baseAddress: UnsafeMutableRawPointer,
            mappingLen: Int,
            mappingHandle: HANDLE,
            delta: Int,
            userLen: Int,
            effectiveSafety: Safety,
            lockToken: MMap.Lock.Token?
        ) {
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

            return (
                baseAddress: mapping.baseAddress,
                mappingLen: mappingLen,
                mappingHandle: mapping.mappingHandle,
                delta: delta,
                userLen: userLen,
                effectiveSafety: effectiveSafety,
                lockToken: lockToken
            )
        }

        /// Computes the lock range based on scope.
        private static func computeLockRange(
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
#endif

// MARK: - Anonymous Mapping

extension MMap.Region {
    /// Creates an anonymous memory mapping (not backed by a file).
    ///
    /// Anonymous mappings are backed by:
    /// - POSIX: Swap/memory only
    /// - Windows: The system pagefile
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
        // Validate access
        try access.validate()

        let pageSize = Kernel.System.pageSize
        let mappingLen = Kernel.System.alignUp(length, to: pageSize)

        #if os(Windows)
            let mapping: Kernel.Mmap.WindowsMapping
            do {
                mapping = try Kernel.Mmap.mapAnonymous(
                    length: mappingLen,
                    protection: access.kernelProtection
                )
            } catch {
                throw MMap.Error(from: error)
            }

            self.mappingBaseAddress = mapping.baseAddress
            self.mappingLength = mappingLen
            self.mappingHandle = mapping.mappingHandle
        #else
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
        #endif

        self.offsetDelta = 0
        self.userLength = length
        self.access = access
        self.sharing = sharing
        self.safety = .unchecked  // Anonymous mappings don't need lock coordination
        self.lockToken = nil
    }
}
