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
    /// Memory access advice patterns.
    ///
    /// Re-exports `Kernel.Memory.Map.Advice` constants and provides
    /// convenience methods for common access patterns.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let map = try Memory.Map(fileDescriptor: fd, range: .whole)
    ///
    /// // Tell the kernel we'll read sequentially
    /// map.advise(.sequential)
    ///
    /// // Or use the convenience method
    /// Memory.Advice.sequential(map)
    /// ```
    ///
    /// ## Advice Types
    ///
    /// - `.normal`: Default access pattern
    /// - `.sequential`: Sequential access (read-ahead is beneficial)
    /// - `.random`: Random access (read-ahead is not beneficial)
    /// - `.willNeed`: Pages will be needed soon (use `prefetch()`)
    /// - `.dontNeed`: Pages won't be needed soon (use `forget()`)
    public typealias Advice = Kernel.Memory.Map.Advice
}

// MARK: - Convenience Methods

extension Memory.Advice {
    /// Advise sequential access pattern for a mapping.
    ///
    /// Tells the kernel that pages will be accessed sequentially,
    /// enabling aggressive read-ahead.
    ///
    /// - Parameter map: The memory mapping.
    public static func sequential(_ map: borrowing Memory.Map) {
        map.advise(.sequential)
    }

    /// Advise random access pattern for a mapping.
    ///
    /// Tells the kernel that pages will be accessed randomly,
    /// disabling read-ahead optimization.
    ///
    /// - Parameter map: The memory mapping.
    public static func random(_ map: borrowing Memory.Map) {
        map.advise(.random)
    }

    /// Advise that pages will be needed soon (prefetch).
    ///
    /// Triggers prefetching of pages into memory. Useful before
    /// a known access pattern.
    ///
    /// - Parameter map: The memory mapping.
    public static func prefetch(_ map: borrowing Memory.Map) {
        map.advise(.willNeed)
    }

    /// Advise that pages won't be needed soon.
    ///
    /// Allows the kernel to forget about keeping these pages ready.
    /// The pages can be re-faulted if accessed again.
    ///
    /// - Parameter map: The memory mapping.
    public static func forget(_ map: borrowing Memory.Map) {
        map.advise(.dontNeed)
    }

    /// Reset to normal/default access pattern.
    ///
    /// Clears any previous access pattern advice.
    ///
    /// - Parameter map: The memory mapping.
    public static func normal(_ map: borrowing Memory.Map) {
        map.advise(.normal)
    }
}
