// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-memory open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-memory project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Kernel
import Memory_Primitives

// MARK: - Convenience Re-exports

extension Memory {
    /// Nested accessor for allocation-related properties.
    public static var allocation: Allocation.Type { Allocation.self }
}

// MARK: - System.Page Foundation Helpers

extension System.Page {
    /// The page size as a `Memory.Alignment` for alignment operations.
    @inlinable
    public static var alignment: Memory.Alignment {
        System.pageSize.alignment
    }

    /// Nested accessor for alignment operations.
    public static var align: Align.Type { Align.self }

    /// Alignment operations for page boundaries.
    public enum Align {}
}

extension System.Page.Align {
    /// Rounds a size down to the page size boundary.
    ///
    /// - Parameter size: The size to align.
    /// - Returns: The largest page-aligned size ≤ `size`.
    @inlinable
    public static func down(_ size: Kernel.File.Size) -> Kernel.File.Size {
        size.alignedDown(to: System.Page.alignment)
    }

    /// Rounds a size up to the page size boundary.
    ///
    /// - Parameter size: The size to align.
    /// - Returns: The smallest page-aligned size ≥ `size`.
    @inlinable
    public static func up(_ size: Kernel.File.Size) -> Kernel.File.Size {
        size.alignedUp(to: System.Page.alignment)
    }
}

// MARK: - Allocation Properties

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
    public static var granularity: Memory.Allocation.Granularity {
        Self.system
    }

    /// The allocation granularity as a `Memory.Alignment` for alignment operations.
    @inlinable
    public static var alignment: Memory.Alignment {
        granularity.underlying
    }

    /// Nested accessor for alignment operations.
    public static var align: Align.Type { Align.self }

    /// Alignment operations for allocation granularity boundaries.
    public enum Align {}
}

extension Memory.Allocation.Align {
    /// Rounds an offset down to the allocation granularity boundary.
    @inlinable
    public static func down(_ offset: Kernel.File.Offset) -> Kernel.File.Offset {
        let magnitude: Int64 = Memory.Allocation.alignment.magnitude()
        let aligned = offset.underlying & ~(magnitude - 1)
        return Kernel.File.Offset(aligned)
    }

    /// Rounds an offset up to the allocation granularity boundary.
    @inlinable
    public static func up(_ offset: Kernel.File.Offset) -> Kernel.File.Offset {
        let magnitude: Int64 = Memory.Allocation.alignment.magnitude()
        let aligned = (offset.underlying + magnitude - 1) & ~(magnitude - 1)
        return Kernel.File.Offset(aligned)
    }

    /// Rounds a size down to the allocation granularity boundary.
    @inlinable
    public static func down(_ size: Kernel.File.Size) -> Kernel.File.Size {
        size.alignedDown(to: Memory.Allocation.alignment)
    }

    /// Rounds a size up to the allocation granularity boundary.
    @inlinable
    public static func up(_ size: Kernel.File.Size) -> Kernel.File.Size {
        size.alignedUp(to: Memory.Allocation.alignment)
    }
}
