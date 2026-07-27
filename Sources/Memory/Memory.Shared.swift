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

// Memory.Shared namespace is declared at L1 (swift-memory-primitives).
// L3 extends it with policy-layer types (Mode, Access, Options, open(), unlink()).

// MARK: - Open Mode

extension Memory.Shared {
    /// Mode for opening shared memory objects.
    public struct Mode: Sendable, Equatable {
        /// Access mode (read, write, or both).
        public let access: Memory.Shared.Access

        /// Creation options (create, exclusive, truncate).
        public let options: Memory.Shared.Options

        /// Permission mode for creation (POSIX only).
        public let permissions: Kernel.File.Permissions

        public init(
            access: Memory.Shared.Access,
            options: Memory.Shared.Options = [],
            permissions: Kernel.File.Permissions = .ownerReadWrite
        ) {
            self.access = access
            self.options = options
            self.permissions = permissions
        }
    }
}

extension Memory.Shared.Mode {
    /// Open existing read-only.
    public static let read = Self(access: .read)

    /// Nested accessor for create modes.
    public static var create: Create.Type { Create.self }
}

// MARK: - ExpressibleByArrayLiteral

extension Memory.Shared.Mode: ExpressibleByArrayLiteral {
    /// Creates a mode from an array literal of access flags.
    ///
    /// This allows concise mode specification:
    /// ```swift
    /// mode: [.read, .write]  // read-write access, no options
    /// mode: [.read]          // read-only access
    /// ```
    public init(arrayLiteral elements: Memory.Shared.Access...) {
        var read = false
        var write = false
        for element in elements {
            if element.read { read = true }
            if element.write { write = true }
        }
        self.init(access: Memory.Shared.Access(read: read, write: write))
    }
}

// MARK: - Create Modes

extension Memory.Shared.Mode {
    /// Create mode variants for shared memory.
    ///
    /// These provide convenience statics for common creation patterns.
    /// For full control, use `Mode(access:options:permissions:)` directly.
    public enum Create {}
}

extension Memory.Shared.Mode.Create {
    /// Create exclusively (fails if exists) with read-write access.
    public static var exclusive: Memory.Shared.Mode {
        Memory.Shared.Mode(
            access: .readWrite,
            options: [.create, .exclusive]
        )
    }

    /// Create with truncate (if exists) with read-write access.
    ///
    /// - Note: On Windows, truncate is ignored. The size is fixed at creation.
    public static var truncate: Memory.Shared.Mode {
        Memory.Shared.Mode(
            access: .readWrite,
            options: [.create, .truncate]
        )
    }
}

// MARK: - POSIX Operations

#if !os(Windows)

    extension Memory.Shared {
        /// Opens or creates a POSIX shared memory object.
        ///
        /// - Parameters:
        ///   - name: The name of the shared memory object (must start with '/').
        ///   - mode: The open mode and permissions.
        /// - Returns: A file descriptor for the shared memory object.
        /// - Throws: `Memory.Error` if the operation fails.
        ///
        /// ## Name Requirements
        ///
        /// The name must:
        /// - Start with a forward slash ('/')
        /// - Not contain additional slashes
        /// - Not exceed `NAME_MAX` characters (typically 255)
        ///
        /// ## Example
        ///
        /// ```swift
        /// let shm = try Memory.Shared.open(
        ///     name: "/my-ipc-buffer",
        ///     mode: .create.exclusive
        /// )
        /// ```
        public static func open(
            name: Swift.String,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {
            // Avoid Result<Kernel.Descriptor, ...> — Result requires Copyable.
            // withCString also requires Copyable return, so capture via side channel.
            var fd: Kernel.Descriptor? = nil
            var openError: Memory.Shared.Error? = nil
            unsafe name.withCString { namePtr in
                do throws(Self.Error) {
                    fd = try unsafe Self.open(
                        name: namePtr,
                        access: mode.access,
                        options: mode.options,
                        permissions: mode.permissions
                    )
                } catch {
                    openError = error
                }
            }
            if let fd {
                return fd
            }
            if let openError {
                throw Memory.Error(from: openError)
            }
            preconditionFailure("unreachable: withCString must set fd or openError")
        }

        /// Removes a POSIX shared memory object.
        ///
        /// The shared memory object is unlinked from the filesystem namespace.
        /// Existing mappings remain valid until all processes unmap them.
        ///
        /// - Parameter name: The name of the shared memory object to remove.
        /// - Throws: `Memory.Error` if the operation fails.
        public static func unlink(name: Swift.String) throws(Memory.Error) {
            var unlinkError: Memory.Shared.Error?
            unsafe name.withCString { namePtr in
                do throws(Self.Error) {
                    try unsafe Self.unlink(name: namePtr)
                } catch {
                    unlinkError = error
                }
            }
            if let unlinkError {
                throw Memory.Error(from: unlinkError)
            }
        }
    }

#endif

// MARK: - Windows Operations

#if os(Windows)

    extension Memory.Shared {
        /// Creates or opens a named shared memory object on Windows.
        ///
        /// - Parameters:
        ///   - name: The name of the shared memory object.
        ///     Use "Local\\" prefix for session-local or "Global\\" for system-wide.
        ///   - size: The size of the shared memory region (required on Windows).
        ///   - mode: The open mode.
        /// - Returns: A descriptor for the shared memory object.
        /// - Throws: `Memory.Error` if the operation fails.
        ///
        /// ## Name Format
        ///
        /// Unlike POSIX, Windows names don't require a "/" prefix:
        /// - `"Local\\my-buffer"` - visible only in current session
        /// - `"Global\\my-buffer"` - visible system-wide (requires privileges)
        ///
        /// ## Example
        ///
        /// ```swift
        /// let shm = try Memory.Shared.open(
        ///     name: "Local\\my-ipc-buffer",
        ///     size: 4096,
        ///     mode: .create.exclusive
        /// )
        /// ```
        public static func open(
            name: Swift.String,
            size: Kernel.File.Size,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {
            do throws(Self.Error) {
                return try Self.open(
                    name: name,
                    size: size,
                    access: mode.access,
                    options: mode.options
                )
            } catch {
                throw Memory.Error(from: error)
            }
        }

        /// Opens an existing named shared memory object on Windows.
        ///
        /// - Parameters:
        ///   - name: The name of the shared memory object.
        ///   - mode: The open mode (only access is used; options ignored).
        /// - Returns: A descriptor for the shared memory object.
        /// - Throws: `Memory.Error` if the operation fails.
        public static func open(
            name: Swift.String,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {
            do throws(Self.Error) {
                return try Self.open(
                    name: name,
                    access: mode.access
                )
            } catch {
                throw Memory.Error(from: error)
            }
        }

        /// Closes a shared memory object handle.
        ///
        /// On Windows, shared memory objects are reference-counted.
        /// The object is deleted when all handles are closed.
        ///
        /// - Note: This is different from POSIX where `unlink` removes the name
        ///   but the object persists until all mappings are unmapped.
        ///
        /// - Parameter descriptor: The descriptor to close.
        /// - Throws: `Memory.Error` if the operation fails.
        public static func close(_ descriptor: Kernel.Descriptor) throws(Memory.Error) {
            do throws(Self.Error) {
                try Self.close(descriptor)
            } catch {
                throw Memory.Error(from: error)
            }
        }
    }

#endif
