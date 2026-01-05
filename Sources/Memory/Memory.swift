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

/// Memory management namespace.
///
/// Provides high-level memory management APIs:
/// - `Map`: Memory-mapped files and anonymous mappings (RAII)
/// - `Shared`: POSIX shared memory for IPC
/// - `Lock`: Page locking to prevent swapping
/// - `Advice`: Higher-level madvise patterns
///
/// Built on `Kernel.Memory.*` syscalls from swift-kernel.
///
/// ## Architecture
///
/// ```
/// swift-kernel.Memory.Map.*     → Raw syscall wrappers
///            ↓
/// swift-memory                  → RAII types, nice APIs
/// ```
public enum Memory {}

// MARK: - Convenience Re-exports

extension Memory {
    /// Nested accessor for page-related properties.
    public static var page: Page.Type { Page.self }

    /// Nested accessor for allocation-related properties.
    public static var allocation: Allocation.Type { Allocation.self }
}

// MARK: - Page Properties

extension Memory.Page {
    /// The system page size in bytes.
    ///
    /// This is the minimum granularity for memory protection changes.
    /// Typical values: 4096 (4KB) on most systems, 16384 (16KB) on Apple Silicon.
    @inlinable
    public static var size: Kernel.Memory.Page.Size {
        Kernel.System.pageSize
    }

    /// The page size as a `Binary.Alignment` for alignment operations.
    @inlinable
    public static var alignment: Binary.Alignment {
        // Safe: page size is always a power of 2
        try! Binary.Alignment(Int(size))
    }

    /// Nested accessor for alignment operations.
    public static var align: Align.Type { Align.self }

    /// Alignment operations for page boundaries.
    public enum Align {
        /// Rounds a size down to the page size boundary.
        ///
        /// - Parameter size: The size to align.
        /// - Returns: The largest page-aligned size ≤ `size`.
        @inlinable
        public static func down(_ size: Kernel.File.Size) -> Kernel.File.Size {
            Kernel.System.alignDown(size, to: Memory.Page.alignment)
        }

        /// Rounds a size up to the page size boundary.
        ///
        /// - Parameter size: The size to align.
        /// - Returns: The smallest page-aligned size ≥ `size`.
        @inlinable
        public static func up(_ size: Kernel.File.Size) -> Kernel.File.Size {
            Kernel.System.alignUp(size, to: Memory.Page.alignment)
        }
    }
}

// MARK: - Allocation Properties

extension Memory {
    /// Allocation-related properties.
    public enum Allocation {}
}

extension Memory.Allocation {
    /// The allocation granularity in bytes.
    ///
    /// This is the minimum granularity for mapping offsets:
    /// - POSIX: Same as page size
    /// - Windows: 64KB (larger than page size)
    ///
    /// When mapping with a non-zero offset, the offset is automatically
    /// aligned down to this granularity.
    @inlinable
    public static var granularity: Kernel.Memory.Allocation.Granularity {
        Kernel.System.allocationGranularity
    }

    /// The allocation granularity as a `Binary.Alignment` for alignment operations.
    @inlinable
    public static var alignment: Binary.Alignment {
        // Safe: allocation granularity is always a power of 2
        try! Binary.Alignment(Int(granularity))
    }

    /// Nested accessor for alignment operations.
    public static var align: Align.Type { Align.self }

    /// Alignment operations for allocation granularity boundaries.
    public enum Align {
        /// Rounds an offset down to the allocation granularity boundary.
        ///
        /// - Parameter offset: The offset to align.
        /// - Returns: The largest granularity-aligned offset ≤ `offset`.
        @inlinable
        public static func down(_ offset: Kernel.File.Offset) -> Kernel.File.Offset {
            Kernel.System.alignDown(offset, to: Memory.Allocation.alignment)
        }

        /// Rounds an offset up to the allocation granularity boundary.
        ///
        /// - Parameter offset: The offset to align.
        /// - Returns: The smallest granularity-aligned offset ≥ `offset`.
        @inlinable
        public static func up(_ offset: Kernel.File.Offset) -> Kernel.File.Offset {
            Kernel.System.alignUp(offset, to: Memory.Allocation.alignment)
        }

        /// Rounds a size down to the allocation granularity boundary.
        ///
        /// - Parameter size: The size to align.
        /// - Returns: The largest granularity-aligned size ≤ `size`.
        @inlinable
        public static func down(_ size: Kernel.File.Size) -> Kernel.File.Size {
            Kernel.System.alignDown(size, to: Memory.Allocation.alignment)
        }

        /// Rounds a size up to the allocation granularity boundary.
        ///
        /// - Parameter size: The size to align.
        /// - Returns: The smallest granularity-aligned size ≥ `size`.
        @inlinable
        public static func up(_ size: Kernel.File.Size) -> Kernel.File.Size {
            Kernel.System.alignUp(size, to: Memory.Allocation.alignment)
        }
    }
}
