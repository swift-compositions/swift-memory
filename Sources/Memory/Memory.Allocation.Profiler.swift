// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-memory open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-memory project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Synchronization

extension Memory.Allocation {
    /// Allocation profiler.
    ///
    /// Profiles memory allocations over multiple runs to generate statistics
    /// and histograms.
    ///
    /// Example:
    /// ```swift
    /// let profiler = Memory.Allocation.Profiler()
    ///
    /// for _ in 0..<100 {
    ///     profiler.profile {
    ///         let array = Array(repeating: 0, count: 1000)
    ///         _ = array.count
    ///     }
    /// }
    ///
    /// print("Mean: \(profiler.bytes.mean) bytes")
    /// print("Median: \(profiler.bytes.median) bytes")
    /// print("P95: \(profiler.bytes.percentile(95)) bytes")
    /// ```
    public final class Profiler: Sendable {
        internal let measurements: Mutex<[Memory.Allocation.Statistics]>

        /// Initialize an allocation profiler.
        public init() {
            self.measurements = Mutex([])
        }
    }
}

// MARK: - Profiling

extension Memory.Allocation.Profiler {
    /// Profile a single execution.
    ///
    /// - Parameter operation: The operation to profile.
    /// - Returns: The operation result.
    /// - Throws: The typed error from the operation.
    @discardableResult
    public func profile<T, E: Swift.Error>(
        _ operation: () throws(E) -> T
    ) throws(E) -> T {
        let (result, stats) = try Memory.Allocation.Tracker.measure(operation)

        measurements.withLock { m in
            m.append(stats)
        }

        return result
    }

    /// Profile a single async execution.
    ///
    /// - Parameter operation: The async operation to profile.
    /// - Returns: The operation result.
    /// - Throws: The typed error from the operation.
    @discardableResult
    nonisolated(nonsending)
        public func profile<T, E: Swift.Error>(
            _ operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        let (result, stats) = try await Memory.Allocation.Tracker.measure(operation)

        measurements.withLock { m in
            m.append(stats)
        }

        return result
    }
}

// MARK: - Measurements

extension Memory.Allocation.Profiler {
    /// Number of profiled executions.
    public var count: Int {
        measurements.withLock { $0.count }
    }

    /// All measurements.
    public var all: [Memory.Allocation.Statistics] {
        measurements.withLock { $0 }
    }

    /// Reset profiler.
    ///
    /// Clears all measurements.
    public func reset() {
        measurements.withLock { m in
            m.removeAll()
        }
    }
}

// MARK: - Nested Accessors

extension Memory.Allocation.Profiler {
    /// Accessor for byte-related statistics.
    public var bytes: Bytes { Bytes(self) }

    /// Accessor for allocation count statistics.
    public var allocations: Allocations { Allocations(self) }
}

extension Memory.Allocation.Profiler {
    /// Byte statistics accessor.
    public struct Bytes: Sendable {
        private let profiler: Memory.Allocation.Profiler

        internal init(_ profiler: Memory.Allocation.Profiler) {
            self.profiler = profiler
        }
    }
}

extension Memory.Allocation.Profiler.Bytes {
    /// Mean bytes allocated across all executions.
    public var mean: Double {
        profiler.measurements.withLock { m in
            guard !m.isEmpty else { return 0 }
            let total = m.reduce(0) { $0 + $1.bytes.allocated }
            return Double(total) / Double(m.count)
        }
    }

    /// Median bytes allocated.
    public var median: Int {
        percentile(50)
    }

    /// Calculate percentile for bytes allocated.
    ///
    /// - Parameter p: Percentile to calculate (0-100).
    /// - Returns: Bytes allocated at the given percentile.
    public func percentile(_ p: Int) -> Int {
        profiler.measurements.withLock { m in
            guard !m.isEmpty else { return 0 }

            let sorted = m.map(\.bytes.allocated).sorted()
            let index = Int(Double(sorted.count) * Double(p) / 100.0)
            return sorted[min(index, sorted.count - 1)]
        }
    }
}

extension Memory.Allocation.Profiler {
    /// Allocation count statistics accessor.
    public struct Allocations: Sendable {
        private let profiler: Memory.Allocation.Profiler

        internal init(_ profiler: Memory.Allocation.Profiler) {
            self.profiler = profiler
        }
    }
}

extension Memory.Allocation.Profiler.Allocations {
    /// Mean allocations across all executions.
    public var mean: Double {
        profiler.measurements.withLock { m in
            guard !m.isEmpty else { return 0 }
            let total = m.reduce(0) { $0 + $1.allocations }
            return Double(total) / Double(m.count)
        }
    }

    /// Median allocations.
    public var median: Int {
        percentile(50)
    }

    /// Calculate percentile for allocation count.
    ///
    /// - Parameter p: Percentile to calculate (0-100).
    /// - Returns: Allocation count at the given percentile.
    public func percentile(_ p: Int) -> Int {
        profiler.measurements.withLock { m in
            guard !m.isEmpty else { return 0 }

            let sorted = m.map(\.allocations).sorted()
            let index = Int(Double(sorted.count) * Double(p) / 100.0)
            return sorted[min(index, sorted.count - 1)]
        }
    }
}

// MARK: - Histogram

extension Memory.Allocation.Profiler {
    /// Generate allocation histogram.
    ///
    /// - Parameter buckets: Number of buckets in the histogram.
    /// - Returns: Histogram of allocation counts.
    public func histogram(buckets: Int = 10) -> Memory.Allocation.Histogram {
        measurements.withLock { m in
            let bytes = m.map(\.bytes.allocated)
            return Memory.Allocation.Histogram(values: bytes, buckets: buckets)
        }
    }
}
