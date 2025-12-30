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

extension MMap.Region {
    /// Access permissions for the mapped region.
    ///
    /// This is an OptionSet-like structure that allows combining permissions:
    /// - `.read` - read-only access
    /// - `[.read, .write]` - read and write access
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Read-only
    /// let region = try MMap.Region(fd: fd, range: .wholeFile, access: .read)
    ///
    /// // Read and write
    /// let region = try MMap.Region(fd: fd, range: .wholeFile, access: [.read, .write])
    ///
    /// // Copy-on-write (use private sharing)
    /// let region = try MMap.Region(fd: fd, range: .wholeFile, access: [.read, .write], sharing: .private)
    /// ```
    ///
    /// ## Notes
    ///
    /// - `.write` requires `.read` on most platforms (POSIX constraint)
    /// - `.execute` is intentionally not included due to portability and security concerns
    public struct Access: OptionSet, Sendable, Hashable {
        public let rawValue: Int32

        public init(rawValue: Int32) {
            self.rawValue = rawValue
        }

        /// Read permission.
        public static let read = Access(rawValue: 1 << 0)

        /// Write permission.
        ///
        /// - Important: On POSIX systems, `.write` implicitly requires `.read`.
        ///   Use `[.read, .write]` for clarity.
        public static let write = Access(rawValue: 1 << 1)

        // Note: .execute is intentionally not included in v1
        // due to portability and security policy concerns

        /// Whether this access mode allows reading.
        @inlinable
        public var allowsRead: Bool { contains(.read) }

        /// Whether this access mode allows writing.
        @inlinable
        public var allowsWrite: Bool { contains(.write) }

        /// Converts to Kernel protection flags.
        @inlinable
        var kernelProtection: Kernel.Mmap.Protection {
            switch (contains(.read), contains(.write)) {
            case (true, true):
                return Kernel.Mmap.Protection.read | Kernel.Mmap.Protection.write
            case (true, false):
                return .read
            case (false, true):
                // Should not happen due to validation, but handle it
                return .write
            case (false, false):
                return .none
            }
        }

        /// Validates that the access combination is supported.
        ///
        /// - Throws: `MMap.Error.invalidAccess` if `.write` is specified without `.read`.
        @inlinable
        func validate() throws(MMap.Error) {
            // POSIX requires read permission for write-mapped regions
            if contains(.write) && !contains(.read) {
                throw .invalidAccess
            }
        }
    }
}
