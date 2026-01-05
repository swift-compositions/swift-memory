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

extension Memory {
    /// Shared memory operations for inter-process communication.
    ///
    /// Policy layer that provides convenience and error translation on top of
    /// `Kernel.Memory.Shared` syscall wrappers.
    ///
    /// ## Platform Differences
    ///
    /// ### POSIX (macOS, Linux)
    /// - Names must start with '/' (e.g., "/my-shared-mem")
    /// - Size is set after creation via `ftruncate`
    /// - Object persists until `unlink()` is called
    ///
    /// ### Windows
    /// - Names use "Local\\" or "Global\\" prefix
    /// - Size must be specified at creation
    /// - Object is deleted when all handles are closed
    ///
    /// ## Usage (POSIX)
    ///
    /// ```swift
    /// // Create shared memory
    /// let shm = try Memory.Shared.open(
    ///     name: "/my-shared-mem",
    ///     mode: .create.exclusive
    /// )
    /// defer { try? Memory.Shared.unlink(name: "/my-shared-mem") }
    ///
    /// // Resize for initial use
    /// try Kernel.File.truncate(descriptor: shm, size: 4096)
    ///
    /// // Map into address space
    /// let map = try Memory.Map.open(
    ///     fileDescriptor: shm,
    ///     range: .whole,
    ///     access: [.read, .write],
    ///     sharing: .shared
    /// )
    /// ```
    ///
    /// ## Usage (Windows)
    ///
    /// ```swift
    /// // Create shared memory with size
    /// let shm = try Memory.Shared.open(
    ///     name: "Local\\my-shared-mem",
    ///     size: 4096,
    ///     mode: .create.exclusive
    /// )
    /// // No unlink needed - closes automatically
    /// ```
    public enum Shared {}
}

// MARK: - Open Mode

extension Memory.Shared {
    /// Mode for opening shared memory objects.
    public struct Mode: Sendable, Equatable {
        /// Access mode (read, write, or both).
        public let access: Kernel.Memory.Shared.Access

        /// Creation options (create, exclusive, truncate).
        public let options: Kernel.Memory.Shared.Options

        /// Permission mode for creation (POSIX only).
        public let permissions: Kernel.File.Permissions

        public init(
            access: Kernel.Memory.Shared.Access,
            options: Kernel.Memory.Shared.Options = [],
            permissions: Kernel.File.Permissions = .ownerReadWrite
        ) {
            self.access = access
            self.options = options
            self.permissions = permissions
        }

        /// Open existing read-only.
        public static let read = Mode(access: .read)

        /// Nested accessor for create modes.
        public static var create: Create.Type { Create.self }
    }
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
    public init(arrayLiteral elements: Kernel.Memory.Shared.Access...) {
        var access = Kernel.Memory.Shared.Access()
        for element in elements {
            access.formUnion(element)
        }
        self.init(access: access)
    }
}

// MARK: - Create Modes

extension Memory.Shared.Mode {
    /// Create mode variants for shared memory.
    ///
    /// These provide convenience statics for common creation patterns.
    /// For full control, use `Mode(access:options:permissions:)` directly.
    public enum Create {
        /// Create exclusively (fails if exists) with read-write access.
        public static var exclusive: Memory.Shared.Mode {
            Memory.Shared.Mode(access: [.read, .write], options: [.create, .exclusive])
        }

        /// Create with truncate (if exists) with read-write access.
        ///
        /// - Note: On Windows, truncate is ignored. The size is fixed at creation.
        public static var truncate: Memory.Shared.Mode {
            Memory.Shared.Mode(access: [.read, .write], options: [.create, .truncate])
        }
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
            name: String,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {
            var result: Result<Kernel.Descriptor, Kernel.Memory.Shared.Error>!
            name.withCString { namePtr in
                do throws(Kernel.Memory.Shared.Error) {
                    let fd = try Kernel.Memory.Shared.open(
                        name: namePtr,
                        access: mode.access,
                        options: mode.options,
                        permissions: mode.permissions
                    )
                    result = .success(fd)
                } catch {
                    result = .failure(error)
                }
            }
            switch result! {
            case .success(let fd):
                return fd
            case .failure(let error):
                throw Memory.Error(from: error)
            }
        }

        /// Removes a POSIX shared memory object.
        ///
        /// The shared memory object is unlinked from the filesystem namespace.
        /// Existing mappings remain valid until all processes unmap them.
        ///
        /// - Parameter name: The name of the shared memory object to remove.
        /// - Throws: `Memory.Error` if the operation fails.
        public static func unlink(name: String) throws(Memory.Error) {
            var unlinkError: Kernel.Memory.Shared.Error?
            name.withCString { namePtr in
                do throws(Kernel.Memory.Shared.Error) {
                    try Kernel.Memory.Shared.unlink(name: namePtr)
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
            name: String,
            size: Kernel.File.Size,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {
            do throws(Kernel.Memory.Shared.Error) {
                return try Kernel.Memory.Shared.open(
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
            name: String,
            mode: Mode
        ) throws(Memory.Error) -> Kernel.Descriptor {
            do throws(Kernel.Memory.Shared.Error) {
                return try Kernel.Memory.Shared.open(
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
            do throws(Kernel.Memory.Shared.Error) {
                try Kernel.Memory.Shared.close(descriptor)
            } catch {
                throw Memory.Error(from: error)
            }
        }
    }

#endif
