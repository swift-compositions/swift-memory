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

#if !os(Windows)

extension Memory {
    /// POSIX shared memory operations.
    ///
    /// Policy layer that provides convenience and error translation on top of
    /// `Kernel.Memory.Shared` syscall wrappers.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Create shared memory
    /// let shm = try Memory.Shared.open(
    ///     name: "/my-shared-mem",
    ///     mode: .create.readWrite
    /// )
    /// defer { try? Memory.Shared.unlink(name: "/my-shared-mem") }
    ///
    /// // Resize for initial use
    /// try Kernel.File.truncate(descriptor: shm, size: 4096)
    ///
    /// // Map into address space
    /// let map = try Memory.Map(
    ///     fileDescriptor: shm,
    ///     range: .whole,
    ///     access: [.read, .write],
    ///     sharing: .shared
    /// )
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

        /// Permission mode for creation.
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

        /// Open existing read-write.
        public static let readWrite = Mode(access: [.read, .write])

        /// Nested accessor for create modes.
        public static var create: Create.Type { Create.self }
    }
}

// MARK: - Create Modes

extension Memory.Shared.Mode {
    /// Create mode variants for shared memory.
    public enum Create {
        /// Create or open read-write.
        public static var readWrite: Memory.Shared.Mode {
            Memory.Shared.Mode(access: [.read, .write], options: .create)
        }

        /// Create exclusively (fails if exists).
        public static var exclusive: Memory.Shared.Mode {
            Memory.Shared.Mode(access: [.read, .write], options: [.create, .exclusive])
        }

        /// Create, truncate if exists.
        public static var truncate: Memory.Shared.Mode {
            Memory.Shared.Mode(access: [.read, .write], options: [.create, .truncate])
        }
    }
}

// MARK: - Operations

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
    ///     mode: .create.readWrite
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
