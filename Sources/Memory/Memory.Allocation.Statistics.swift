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

extension Memory.Allocation {
    /// Cross-platform allocation statistics.
    ///
    /// Current implementation is a stub returning zero values.
    /// Future: delegate to platform-specific statistics via Kernel.
    public struct Statistics: Sendable, Equatable {
        public let allocations: Int
        public let deallocations: Int
        public let bytesAllocated: Int

        public init(allocations: Int = 0, deallocations: Int = 0, bytesAllocated: Int = 0) {
            self.allocations = allocations
            self.deallocations = deallocations
            self.bytesAllocated = bytesAllocated
        }
    }
}

// MARK: - Nested Accessors

extension Memory.Allocation.Statistics {
    public var bytes: Bytes { Bytes(self) }
    public var net: Net { Net(self) }

    public struct Bytes: Sendable {
        private let stats: Memory.Allocation.Statistics
        init(_ stats: Memory.Allocation.Statistics) { self.stats = stats }
    }

    public struct Net: Sendable {
        private let stats: Memory.Allocation.Statistics
        init(_ stats: Memory.Allocation.Statistics) { self.stats = stats }
    }
}

extension Memory.Allocation.Statistics.Bytes {
    public var allocated: Int { stats.bytesAllocated }
}

extension Memory.Allocation.Statistics.Net {
    public var allocations: Int { stats.allocations - stats.deallocations }
}

// MARK: - Capture and Delta (Stub)

extension Memory.Allocation.Statistics {
    /// Capture current allocation statistics.
    /// Stub: returns zeros. Future: delegate to Kernel platform statistics.
    public static func capture() -> Self { Self() }

    /// Compute delta between two snapshots.
    public static func delta(from baseline: Self, to current: Self) -> Self {
        Self(
            allocations: current.allocations - baseline.allocations,
            deallocations: current.deallocations - baseline.deallocations,
            bytesAllocated: current.bytesAllocated - baseline.bytesAllocated
        )
    }

    /// Ensure platform tracking is active.
    /// Stub: no-op. Future: install malloc hooks via Kernel.
    public static func ensureTracking() {}
}
