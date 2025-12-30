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

public import Kernel

/// Memory mapping namespace.
///
/// Provides high-level memory mapping with:
/// - `Region`: RAII wrapper for mapped memory
/// - `Access`: `.read`, `.write` (OptionSet)
/// - `Sharing`: `.shared`, `.private` (copy-on-write)
/// - `Safety`: `.coordinated` (with file locking), `.unchecked`
///
/// Built on `Kernel.Mmap` syscalls from swift-kernel.
public enum MMap {}

// MARK: - Convenience Re-exports

extension MMap {
    /// The system page size in bytes.
    ///
    /// This is the minimum granularity for memory protection changes.
    /// Typical values: 4096 (4KB) on most systems, 16384 (16KB) on Apple Silicon.
    @inlinable
    public static var pageSize: Int {
        Kernel.System.pageSize
    }

    /// The allocation granularity in bytes.
    ///
    /// This is the minimum granularity for mapping offsets:
    /// - POSIX: Same as page size
    /// - Windows: 64KB (larger than page size)
    ///
    /// When mapping with a non-zero offset, the offset is automatically
    /// aligned down to this granularity.
    @inlinable
    public static var allocationGranularity: Int {
        Kernel.System.allocationGranularity
    }
}
