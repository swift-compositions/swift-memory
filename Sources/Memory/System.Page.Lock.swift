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

extension System.Page {
    /// Page locking operations (prevent swapping).
    ///
    /// Thin wrapper over `Memory.Lock` that provides convenience
    /// methods for locking memory mappings.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
    ///
    /// // Lock the mapping in RAM
    /// try System.Page.Lock.lock(map)
    /// defer { do throws(Memory.Error) { try System.Page.Lock.unlock(map) } catch {} }
    ///
    /// // Memory is now guaranteed to not be swapped
    /// ```
    ///
    /// ## Platform Notes
    ///
    /// ### macOS
    /// Requires `com.apple.developer.kernel.memory-allocation` entitlement.
    /// Without the entitlement, `mlock` calls fail with `EPERM`.
    ///
    /// ### Linux
    /// Subject to `RLIMIT_MEMLOCK` resource limit (default often 64KB).
    /// Use `ulimit -l` to check/increase the limit.
    ///
    /// ### Windows
    /// Uses `VirtualLock`/`VirtualUnlock` for individual ranges.
    ///
    /// **Limitations:**
    /// - No process-wide locking (`all.lock`/`all.unlock` unavailable)
    /// - Locked pages count against the process working set quota
    /// - The minimum working set size may need adjustment via `SetProcessWorkingSetSize`
    /// - Use `System.Page.Lock.all.isSupported` to check availability at runtime
    public enum Lock {}
}

// MARK: - All Pages Accessor

extension System.Page.Lock {
    /// Nested accessor for all-pages operations.
    public static var all: All.Type { All.self }

    /// Operations that affect all pages in the process address space.
    public enum All {}
}

extension System.Page.Lock.All {
    /// Whether process-wide page locking is supported on this platform.
    ///
    /// - Returns: `true` on POSIX systems (macOS, Linux), `false` on Windows.
    ///
    /// Use this to conditionally enable process-wide locking:
    /// ```swift
    /// if System.Page.Lock.all.isSupported {
    ///     try System.Page.Lock.all.lock(.current)
    /// }
    /// ```
    public static var isSupported: Bool {
        #if os(Windows)
            return false
        #else
            return true
        #endif
    }
}

// MARK: - Lock/Unlock Individual Ranges

extension System.Page.Lock {
    /// Locks a memory range in RAM, preventing it from being swapped.
    ///
    /// - Parameters:
    ///   - address: The starting address of the memory range.
    ///   - size: The number of bytes to lock.
    /// - Throws: `Memory.Error` if locking fails.
    public static func lock(address: UnsafeRawPointer, size: Memory.Address.Count) throws(Memory.Error) {
        do throws(Memory.Lock.Error) {
            try unsafe Memory.Lock.lock(address: address, length: size)
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
    public static func unlock(address: UnsafeRawPointer, size: Memory.Address.Count) throws(Memory.Error) {
        do throws(Memory.Lock.Error) {
            try unsafe Memory.Lock.unlock(address: address, length: size)
        } catch {
            throw Memory.Error(from: error)
        }
    }
}

// MARK: - Convenience for Memory.Map

extension System.Page.Lock {
    /// Locks an entire memory mapping in RAM.
    ///
    /// - Parameter map: The memory mapping to lock.
    /// - Throws: `Memory.Error` if locking fails.
    public static func lock(_ map: borrowing Memory.Map) throws(Memory.Error) {
        guard let base = unsafe map.baseAddress else {
            throw .unmapped
        }
        try unsafe lock(address: base, size: map.length)
    }

    /// Unlocks an entire memory mapping.
    ///
    /// - Parameter map: The memory mapping to unlock.
    /// - Throws: `Memory.Error` if unlocking fails.
    public static func unlock(_ map: borrowing Memory.Map) throws(Memory.Error) {
        guard let base = unsafe map.baseAddress else {
            throw .unmapped
        }
        try unsafe unlock(address: base, size: map.length)
    }
}

// MARK: - Lock All (POSIX only)

#if !os(Windows)
    extension System.Page.Lock.All {
        /// Options for locking all pages.
        public typealias Options = Memory.Lock.All.Options

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
        /// try System.Page.Lock.all.lock(.current | .future)
        /// defer { do throws(Memory.Error) { try System.Page.Lock.all.unlock() } catch {} }
        /// ```
        public static func lock(_ options: Options) throws(Memory.Error) {
            do throws(Memory.Lock.Error) {
                try Memory.Lock.lockAll(options)
            } catch {
                throw Memory.Error(from: error)
            }
        }

        /// Unlocks all pages in the process address space.
        ///
        /// - Throws: `Memory.Error` if unlocking fails.
        public static func unlock() throws(Memory.Error) {
            do throws(Memory.Lock.Error) {
                try Memory.Lock.unlockAll()
            } catch {
                throw Memory.Error(from: error)
            }
        }
    }
#endif
