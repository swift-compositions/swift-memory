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

internal import Kernel

#if os(Windows)
public import WinSDK
#endif

extension MMap {
    /// A move-only memory-mapped file region.
    ///
    /// `Region` provides safe access to memory-mapped files with:
    /// - Fixed-length semantics (no auto-grow)
    /// - Platform-abstracted offset alignment
    /// - Optional lock-based SIGBUS safety
    ///
    /// ## Lifetime
    /// - `Region` is `~Copyable` (move-only)
    /// - Use `unmap()` to explicitly release the mapping
    /// - `deinit` releases the mapping as a backstop
    ///
    /// ## Safety Modes
    /// - `.coordinated`: Holds a file lock for the mapping lifetime (prevents SIGBUS from truncation)
    /// - `.unchecked`: No lock held; caller accepts crash risk from concurrent truncation
    ///
    /// ## Thread Safety
    ///
    /// `Region` is `@unchecked Sendable` because:
    /// - The underlying memory mapping is a raw pointer to shared memory
    /// - The compiler cannot verify thread-safe access patterns
    /// - Callers must ensure appropriate synchronization when accessing
    ///   the mapped memory from multiple threads/tasks
    ///
    /// ## Example
    /// ```swift
    /// let region = try MMap.Region(
    ///     fileDescriptor: fd,
    ///     range: .bytes(offset: 0, length: 4096),
    ///     access: .read,
    ///     sharing: .shared,
    ///     safety: .unchecked
    /// )
    /// defer { region.unmap() }
    ///
    /// let byte = region[0]
    /// ```
    public struct Region: ~Copyable, @unchecked Sendable {
        // MARK: - Internal State

        /// The base address of the actual OS mapping (granularity-aligned).
        var mappingBaseAddress: UnsafeMutableRawPointer?

        /// The length of the actual OS mapping.
        let mappingLength: Int

        /// Delta between user-requested offset and mapping base.
        let offsetDelta: Int

        /// The user-visible length (requested length).
        let userLength: Int

        /// The access mode for this mapping.
        ///
        /// This property reflects the current protection. It may be changed
        /// via `protect(_:)` after mapping.
        public internal(set) var access: Access

        /// The sharing mode for this mapping.
        public let sharing: Sharing

        /// The safety mode for this mapping.
        public let safety: Safety

        #if os(Windows)
        /// Windows file mapping handle (must be closed on unmap).
        var mappingHandle: HANDLE?
        #endif

        /// Lock token for `.coordinated` safety mode.
        var lockToken: Lock.Token?

        // MARK: - Computed Properties

        /// The base address for user access (adjusted for offset delta).
        public var baseAddress: UnsafeRawPointer? {
            guard let base = mappingBaseAddress else { return nil }
            return UnsafeRawPointer(base.advanced(by: offsetDelta))
        }

        /// Mutable base address (only valid if access includes write).
        public var mutableBaseAddress: UnsafeMutableRawPointer? {
            guard access.allowsWrite, let base = mappingBaseAddress else { return nil }
            return base.advanced(by: offsetDelta)
        }

        /// The length of the mapped region visible to the user.
        public var length: Int { userLength }

        /// Whether the mapping is still valid.
        public var isMapped: Bool { mappingBaseAddress != nil }

        // MARK: - deinit

        deinit {
            guard let base = mappingBaseAddress else { return }

            lockToken?.release()

            #if os(Windows)
            if let handle = mappingHandle {
                try? Kernel.Mmap.unmap(WindowsMapping(baseAddress: base, mappingHandle: handle))
            }
            #else
            try? Kernel.Mmap.unmap(addr: base, length: mappingLength)
            #endif
        }
    }
}
