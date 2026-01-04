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
    public static var size: Int {
        Kernel.System.pageSize
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
    public static var granularity: Int {
        Kernel.System.allocationGranularity
    }

    /// Rounds an offset down to the allocation granularity boundary.
    ///
    /// - Parameter offset: The offset to align.
    /// - Returns: The largest granularity-aligned offset ≤ `offset`.
    @inlinable
    public static func alignDown(_ offset: Kernel.File.Offset) -> Kernel.File.Offset {
        Kernel.System.alignDown(offset, to: granularity)
    }

    /// Rounds an offset up to the allocation granularity boundary.
    ///
    /// - Parameter offset: The offset to align.
    /// - Returns: The smallest granularity-aligned offset ≥ `offset`.
    @inlinable
    public static func alignUp(_ offset: Kernel.File.Offset) -> Kernel.File.Offset {
        Kernel.System.alignUp(offset, to: granularity)
    }

    /// Rounds a size down to the allocation granularity boundary.
    ///
    /// - Parameter size: The size to align.
    /// - Returns: The largest granularity-aligned size ≤ `size`.
    @inlinable
    public static func alignDown(_ size: Kernel.File.Size) -> Kernel.File.Size {
        Kernel.System.alignDown(size, to: granularity)
    }

    /// Rounds a size up to the allocation granularity boundary.
    ///
    /// - Parameter size: The size to align.
    /// - Returns: The smallest granularity-aligned size ≥ `size`.
    @inlinable
    public static func alignUp(_ size: Kernel.File.Size) -> Kernel.File.Size {
        Kernel.System.alignUp(size, to: granularity)
    }
}
