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
    /// `Memory.Map` is `@unchecked Sendable`. The mapping itself is safe
    /// to share across tasks, but:
    /// - Concurrent writes to the same offset are data races
    /// - Caller must synchronize access when multiple tasks write
    /// - Read-only mappings can be safely shared across tasks without synchronization
    ///
    /// ## Executor Guarantees
    ///
    /// All operations are synchronous and execute on the caller's context.
    /// No internal scheduling or dispatching occurs. Operations complete
    /// before returning.
    ///
    /// ## Cancellation
    ///
    /// Operations do not check for Swift Concurrency task cancellation.
    /// Long-running operations (large mappings, slow I/O) will complete
    /// even if the task is cancelled. Callers must implement their own
    /// cancellation checks if needed.
    ///
    /// ## Resource Scope
    ///
    /// The mapping holds resources until explicitly unmapped via `unmap()` or
    /// when the value goes out of scope (deinit). File descriptors are NOT
    /// owned by the mapping—the caller retains responsibility for closing them.
    /// Lock tokens (in `.coordinated` safety mode) are released with the mapping.
    ///
    /// ## Example
    /// ```swift
    /// let region = try Memory.Map(
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
    public struct Map: ~Copyable, @unchecked Sendable {
        /// The underlying kernel memory region.
        var region: Kernel.Memory.Map.Region?

        /// Delta between user-requested offset and mapping base.
        ///
        /// This is always non-negative (alignment rounds down).
        let offsetDelta: Kernel.File.Size

        /// The user-visible length (requested length).
        let userLength: Kernel.File.Size

        /// The access mode for this mapping.
        ///
        /// This property reflects the current protection. It may be changed
        /// via `protect(_:)` after mapping.
        public internal(set) var access: Access

        /// The sharing mode for this mapping.
        public let sharing: Sharing

        /// The safety mode for this mapping.
        public let safety: Safety

        /// Lock token for `.coordinated` safety mode.
        var lockToken: Lock.Token?

        /// Internal memberwise initializer.
        internal init(
            region: Kernel.Memory.Map.Region?,
            offsetDelta: Kernel.File.Size,
            userLength: Kernel.File.Size,
            access: Access,
            sharing: Sharing,
            safety: Safety,
            lockToken: Lock.Token?
        ) {
            self.region = region
            self.offsetDelta = offsetDelta
            self.userLength = userLength
            self.access = access
            self.sharing = sharing
            self.safety = safety
            self.lockToken = lockToken
        }

        deinit {
            guard let region else { return }

            lockToken?.release()

            try? Kernel.Memory.Map.unmap(region)
        }
    }
}

// MARK: - Address Space Types

extension Memory.Map {
    /// Phantom type for memory mapping address space.
    ///
    /// Used to distinguish memory mapping positions and offsets from
    /// other address spaces like file offsets.
    public enum Space {}

    /// Absolute byte index within a memory mapping.
    ///
    /// Type-safe coordinate for indexing into mapped memory.
    /// Supports affine arithmetic with `Offset`:
    /// - `Index - Index = Offset` (distance between positions)
    /// - `Index + Offset = Index` (translate position)
    /// - `Index - Offset = Index` (translate position)
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let start: Memory.Map.Index = 0
    /// let end: Memory.Map.Index = 100
    /// let distance = end - start  // Memory.Map.Offset (100 bytes)
    /// ```
    public typealias Index = Binary.Position<Int, Space>

    /// Relative byte offset within a memory mapping.
    ///
    /// The result of subtracting two indices. Can be positive or negative.
    public typealias Offset = Binary.Offset<Int, Space>
}

// MARK: - Index Constants

extension Memory.Map.Index {
    /// Zero index (beginning of mapping).
    public static let zero: Self = 0
}

// MARK: - Computed Properties

extension Memory.Map {
    /// The base address of the actual OS mapping (granularity-aligned).
    var mappingBaseAddress: Kernel.Memory.Address? { region?.base }

    /// The length of the actual OS mapping.
    var mappingLength: Kernel.File.Size { region?.length ?? .zero }

    /// The base address for user access (adjusted for offset delta).
    public var baseAddress: UnsafeRawPointer? {
        guard let base = mappingBaseAddress else { return nil }
        return base.pointer?.advanced(by: Int(offsetDelta))
    }

    /// Mutable base address (only valid if access includes write).
    public var mutableBaseAddress: UnsafeMutableRawPointer? {
        guard access.allows.write, let base = mappingBaseAddress else { return nil }
        return base.mutablePointer?.advanced(by: Int(offsetDelta))
    }

    /// The length of the mapped region visible to the user.
    public var length: Kernel.File.Size { userLength }

    /// Whether the mapping is still valid.
    public var isMapped: Bool { region != nil }
}
