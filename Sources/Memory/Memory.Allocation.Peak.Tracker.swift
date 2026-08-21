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

extension Memory.Allocation.Peak {
    /// Peak memory tracker.
    ///
    /// Tracks the peak memory usage during program execution.
    ///
    /// Example:
    /// ```swift
    /// let tracker = Memory.Allocation.Peak.Tracker()
    ///
    /// for i in 0..<100 {
    ///     let array = Array(repeating: 0, count: i * 100)
    ///     tracker.sample()
    /// }
    ///
    /// print("Peak memory: \(tracker.peak.bytes) bytes")
    /// print("Peak allocations: \(tracker.peak.allocations)")
    /// ```
    public final class Tracker: Sendable {
        private let state: Mutex<State>
        private let baseline: Memory.Allocation.Statistics

        /// Initialize a peak memory tracker.
        public init() {
            self.baseline = Memory.Allocation.Statistics.capture()
            self.state = Mutex(State())
        }
    }
}

extension Memory.Allocation.Peak.Tracker {
    private struct State: Sendable {
        var peakBytes: Int = 0
        var peakAllocations: Int = 0
        var samples: [Memory.Allocation.Statistics] = []
    }
}

// MARK: - Sampling

extension Memory.Allocation.Peak.Tracker {
    /// Record a sample of current memory usage.
    ///
    /// Call this periodically to track peak memory.
    public func sample() {
        let current = Memory.Allocation.Statistics.capture()
        let delta = Memory.Allocation.Statistics.delta(from: baseline, to: current)

        state.withLock { state in
            state.samples.append(delta)
            state.peakBytes = max(state.peakBytes, delta.bytes.allocated)
            state.peakAllocations = max(state.peakAllocations, delta.allocations)
        }
    }

    /// All samples collected.
    public var samples: [Memory.Allocation.Statistics] {
        state.withLock { $0.samples }
    }

    /// Current memory usage.
    public var current: Memory.Allocation.Statistics {
        let current = Memory.Allocation.Statistics.capture()
        return Memory.Allocation.Statistics.delta(from: baseline, to: current)
    }

    /// Reset peak tracking.
    ///
    /// Clears samples and resets peak values to current state.
    public func reset() {
        state.withLock { state in
            state.samples.removeAll()
            state.peakBytes = 0
            state.peakAllocations = 0
        }
    }
}

// MARK: - Peak Accessors

extension Memory.Allocation.Peak.Tracker {
    /// Accessor for peak values.
    public var peak: Peak { Peak(self) }
}

extension Memory.Allocation.Peak.Tracker {
    /// Peak value accessors.
    public struct Peak: Sendable {
        private let tracker: Memory.Allocation.Peak.Tracker

        internal init(_ tracker: Memory.Allocation.Peak.Tracker) {
            self.tracker = tracker
        }
    }
}

extension Memory.Allocation.Peak.Tracker.Peak {
    /// Peak bytes allocated since initialization.
    public var bytes: Int {
        tracker.state.withLock { $0.peakBytes }
    }

    /// Peak number of allocations since initialization.
    public var allocations: Int {
        tracker.state.withLock { $0.peakAllocations }
    }
}

// MARK: - Static Track

extension Memory.Allocation.Peak.Tracker {
    /// Track peak memory during an operation.
    ///
    /// Samples memory at regular intervals during the operation.
    ///
    /// - Parameters:
    ///   - sampleInterval: Number of iterations between samples.
    ///   - operation: The operation to track.
    /// - Returns: Peak allocation statistics and operation result.
    public static func track<T, E: Swift.Error>(
        sampleInterval: Int = 1,
        _ operation: (Memory.Allocation.Peak.Tracker) throws(E) -> T
    ) throws(E) -> (result: T, peak: Memory.Allocation.Statistics) {
        let tracker = Memory.Allocation.Peak.Tracker()
        let result = try operation(tracker)

        return (
            result,
            Memory.Allocation.Statistics(
                allocations: tracker.peak.allocations,
                deallocations: 0,
                bytesAllocated: tracker.peak.bytes
            )
        )
    }

    /// Track peak memory during an async operation.
    ///
    /// - Parameters:
    ///   - sampleInterval: Number of iterations between samples.
    ///   - operation: The async operation to track.
    /// - Returns: Peak allocation statistics and operation result.
    public static func track<T, E: Swift.Error>(
        sampleInterval: Int = 1,
        _ operation: (Memory.Allocation.Peak.Tracker) async throws(E) -> T
    ) async throws(E) -> (result: T, peak: Memory.Allocation.Statistics) {
        let tracker = Memory.Allocation.Peak.Tracker()
        let result = try await operation(tracker)

        return (
            result,
            Memory.Allocation.Statistics(
                allocations: tracker.peak.allocations,
                deallocations: 0,
                bytesAllocated: tracker.peak.bytes
            )
        )
    }
}
