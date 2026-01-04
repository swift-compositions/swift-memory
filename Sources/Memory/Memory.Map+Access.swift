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

extension Memory.Map {
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
    /// let region = try Memory.Map(fd: fd, range: .whole, access: .read)
    ///
    /// // Read and write
    /// let region = try Memory.Map(fd: fd, range: .whole, access: [.read, .write])
    ///
    /// // Copy-on-write (use private sharing)
    /// let region = try Memory.Map(fd: fd, range: .whole, access: [.read, .write], sharing: .private)
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
    }
}

// MARK: - Static Constants

extension Memory.Map.Access {
    /// Read permission.
    public static let read = Self(rawValue: 1 << 0)

    /// Write permission.
    ///
    /// - Important: On POSIX systems, `.write` implicitly requires `.read`.
    ///   Use `[.read, .write]` for clarity.
    public static let write = Self(rawValue: 1 << 1)

    // Note: .execute is intentionally not included in v1
    // due to portability and security policy concerns
}

// MARK: - Allows Accessor

extension Memory.Map.Access {
    /// Nested accessor for permission queries.
    public var allows: Allows { Allows(access: self) }
}

// MARK: - Kernel Conversion

extension Memory.Map.Access {
    /// Converts to Kernel protection flags.
    @inlinable
    var kernelProtection: Kernel.Memory.Map.Protection {
        switch (contains(.read), contains(.write)) {
        case (true, true):
            return Kernel.Memory.Map.Protection.read | Kernel.Memory.Map.Protection.write
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
    /// - Throws: `Memory.Error.access` if `.write` is specified without `.read`.
    @inlinable
    func validate() throws(Memory.Error) {
        // POSIX requires read permission for write-mapped regions
        if contains(.write) && !contains(.read) {
            throw .access
        }
    }
}

// MARK: - Allows (nested accessor)

extension Memory.Map.Access {
    /// Nested accessor for permission queries.
    ///
    /// Usage:
    /// ```swift
    /// if access.allows.read { ... }
    /// if access.allows.write { ... }
    /// ```
    public struct Allows: Sendable {
        let access: Memory.Map.Access

        init(access: Memory.Map.Access) {
            self.access = access
        }

        /// Whether read access is permitted.
        public var read: Bool { access.contains(.read) }

        /// Whether write access is permitted.
        public var write: Bool { access.contains(.write) }
    }
}
