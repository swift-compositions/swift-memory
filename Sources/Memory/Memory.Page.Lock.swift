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
    /// Page-level memory operations.
    public enum Page {}
}

extension Memory.Page {
    /// Page locking operations (prevent swapping).
    ///
    /// Thin wrapper over `Kernel.Memory.Lock` that provides convenience
    /// methods for locking memory mappings.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
    ///
    /// // Lock the mapping in RAM
    /// try Memory.Page.Lock.lock(map)
    /// defer { try? Memory.Page.Lock.unlock(map) }
    ///
    /// // Memory is now guaranteed to not be swapped
    /// ```
    ///
    /// ## Platform Notes
    ///
    /// - **macOS**: Requires `com.apple.developer.kernel.memory-allocation` entitlement
    /// - **Linux**: Subject to `RLIMIT_MEMLOCK` resource limit
    /// - **Windows**: Uses `VirtualLock`; no `all.lock`/`all.unlock` equivalent
    public enum Lock {}
}

// MARK: - Lock/Unlock Individual Ranges

extension Memory.Page.Lock {
    /// Locks a memory range in RAM, preventing it from being swapped.
    ///
    /// - Parameters:
    ///   - address: The starting address of the memory range.
    ///   - size: The number of bytes to lock.
    /// - Throws: `Memory.Error` if locking fails.
    public static func lock(address: UnsafeRawPointer, size: Int) throws(Memory.Error) {
        do throws(Kernel.Memory.Lock.Error) {
            try Kernel.Memory.Lock.lock(address: address, length: size)
        } catch {
            throw Memory.Error(from: error)
        }
    }

    /// Unlocks a memory range, allowing it to be swapped.
    ///
    /// - Parameters:
    ///   - address: The starting address of the memory range.
    ///   - size: The number of bytes to unlock.
    /// - Throws: `Memory.Error` if unlocking fails.
    public static func unlock(address: UnsafeRawPointer, size: Int) throws(Memory.Error) {
        do throws(Kernel.Memory.Lock.Error) {
            try Kernel.Memory.Lock.unlock(address: address, length: size)
        } catch {
            throw Memory.Error(from: error)
        }
    }
}

// MARK: - Convenience for Memory.Map

extension Memory.Page.Lock {
    /// Locks an entire memory mapping in RAM.
    ///
    /// - Parameter map: The memory mapping to lock.
    /// - Throws: `Memory.Error` if locking fails.
    public static func lock(_ map: borrowing Memory.Map) throws(Memory.Error) {
        guard let base = map.baseAddress else {
            throw .unmapped
        }
        try lock(address: base, size: Int(map.length))
    }

    /// Unlocks an entire memory mapping.
    ///
    /// - Parameter map: The memory mapping to unlock.
    /// - Throws: `Memory.Error` if unlocking fails.
    public static func unlock(_ map: borrowing Memory.Map) throws(Memory.Error) {
        guard let base = map.baseAddress else {
            throw .unmapped
        }
        try unlock(address: base, size: Int(map.length))
    }
}

// MARK: - Lock All (POSIX only)

#if !os(Windows)
extension Memory.Page.Lock {
    /// Nested accessor for all-pages operations.
    public static var all: All.Type { All.self }

    /// Operations that affect all pages in the process address space.
    public enum All {
        /// Flags for locking all pages.
        public typealias Flags = Kernel.Memory.Lock.All.Flags

        /// Locks all current and/or future pages in the process address space.
        ///
        /// - Parameter flags: Which pages to lock.
        /// - Throws: `Memory.Error` if locking fails.
        ///
        /// ## Flags
        ///
        /// - `.current`: Lock all pages currently mapped
        /// - `.future`: Lock pages mapped in the future
        /// - `.onFault` (Linux only): Lock pages when they are faulted in
        ///
        /// ## Example
        ///
        /// ```swift
        /// // Lock all current and future pages
        /// try Memory.Page.Lock.all.lock(.current | .future)
        /// defer { try? Memory.Page.Lock.all.unlock() }
        /// ```
        public static func lock(_ flags: Flags) throws(Memory.Error) {
            do throws(Kernel.Memory.Lock.Error) {
                try Kernel.Memory.Lock.lockAll(flags)
            } catch {
                throw Memory.Error(from: error)
            }
        }

        /// Unlocks all pages in the process address space.
        ///
        /// - Throws: `Memory.Error` if unlocking fails.
        public static func unlock() throws(Memory.Error) {
            do throws(Kernel.Memory.Lock.Error) {
                try Kernel.Memory.Lock.unlockAll()
            } catch {
                throw Memory.Error(from: error)
            }
        }
    }
}
#endif
