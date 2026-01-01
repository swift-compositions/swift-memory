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

#if canImport(Darwin)
    internal import Darwin
#elseif canImport(Glibc)
    internal import Glibc
#elseif canImport(Musl)
    internal import Musl
#elseif os(Windows)
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
            // Validate access
            try access.validate()

            let effectiveSafety = safety ?? (access.allowsWrite ? .defaultForWrite : .defaultForRead)

            // Resolve range length (query file size for .wholeFile)
            let userLen: Int
            switch range {
            case .bytes(_, let length):
                userLen = length
            case .wholeFile:
                var statBuf = stat()
                guard fstat(fileDescriptor.rawValue, &statBuf) == 0 else {
                    throw .fromErrno(errno, operation: "fstat")
                }
                userLen = Int(statBuf.st_size)
                guard userLen > 0 else {
                    throw .fileTooSmall
                }
            }

            // Calculate alignment
            let requestedOffset = range.offset
            let granularity = Kernel.System.allocationGranularity
            let alignedOffset = Kernel.System.alignDown(requestedOffset, to: granularity)
            let delta = requestedOffset - alignedOffset
            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(userLen + delta, to: pageSize)

            // Perform all throwing work before initializing any stored properties
            // (required for ~Copyable types)

            // 1. Map the file
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

            // 2. Acquire lock if needed
            let acquiredLockToken: MMap.Lock.Token?
            if case .coordinated(let kind, let scope) = effectiveSafety {
                let lockRange = Self.computeLockRange(
                    scope: scope,
                    alignedOffset: alignedOffset,
                    mappingLength: mappingLen
                )
                do {
                    acquiredLockToken = try MMap.Lock.Token(
                        descriptor: fileDescriptor,
                        range: lockRange,
                        kind: kind
                    )
                } catch {
                    // Unmap on lock failure (before we've initialized self)
                    try? Kernel.Mmap.unmap(addr: baseAddress, length: mappingLen)
                    throw .lockFailed(error)
                }
            } else {
                acquiredLockToken = nil
            }

            // Now initialize all stored properties at once
            self.mappingBaseAddress = baseAddress
            self.mappingLength = mappingLen
            self.offsetDelta = delta
            self.userLength = userLen
            self.access = access
            self.sharing = sharing
            self.safety = effectiveSafety
            self.lockToken = acquiredLockToken
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
        public init(
            fileHandle: Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(MMap.Error) {
            // Validate access
            try access.validate()

            let effectiveSafety = safety ?? (access.allowsWrite ? .defaultForWrite : .defaultForRead)

            // Resolve range length (query file size for .wholeFile)
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

            // Calculate alignment (Windows uses 64KB granularity)
            let requestedOffset = range.offset
            let granularity = Kernel.System.allocationGranularity
            let alignedOffset = Kernel.System.alignDown(requestedOffset, to: granularity)
            let delta = requestedOffset - alignedOffset
            let pageSize = Kernel.System.pageSize
            let mappingLen = Kernel.System.alignUp(userLen + delta, to: pageSize)

            // 1. Map the file
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

            // 2. Acquire lock if needed
            let acquiredLockToken: MMap.Lock.Token?
            if case .coordinated(let kind, let scope) = effectiveSafety {
                let lockRange = Self.computeLockRange(
                    scope: scope,
                    alignedOffset: alignedOffset,
                    mappingLength: mappingLen
                )
                do {
                    acquiredLockToken = try MMap.Lock.Token(
                        descriptor: fileHandle,
                        range: lockRange,
                        kind: kind
                    )
                } catch {
                    // Unmap on lock failure
                    try? Kernel.Mmap.unmap(mapping)
                    throw .lockFailed(error)
                }
            } else {
                acquiredLockToken = nil
            }

            // Initialize all stored properties
            self.mappingBaseAddress = mapping.baseAddress
            self.mappingLength = mappingLen
            self.mappingHandle = mapping.mappingHandle
            self.offsetDelta = delta
            self.userLength = userLen
            self.access = access
            self.sharing = sharing
            self.safety = effectiveSafety
            self.lockToken = acquiredLockToken
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
