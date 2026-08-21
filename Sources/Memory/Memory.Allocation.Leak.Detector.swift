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

extension Memory.Allocation.Leak {
    /// Memory leak detector.
    ///
    /// Detects memory leaks by tracking net allocations over time.
    ///
    /// Example:
    /// ```swift
    /// let detector = Memory.Allocation.Leak.Detector()
    ///
    /// for _ in 0..<100 {
    ///     let array = Array(repeating: 0, count: 1000)
    ///     _ = array.count
    /// }
    ///
    /// if detector.detected {
    ///     print("Detected \(detector.net.allocations) leaked allocations")
    /// }
    /// ```
    public final class Detector: Sendable {
        private let baseline: Memory.Allocation.Statistics

        /// Initialize a leak detector.
        ///
        /// Captures baseline allocation statistics at initialization.
        public init() {
            self.baseline = Memory.Allocation.Statistics.capture()
        }
    }
}

// MARK: - Detection

extension Memory.Allocation.Leak.Detector {
    /// Whether leaks have been detected.
    ///
    /// - Returns: True if net allocations have increased since initialization.
    public var detected: Bool {
        net.allocations > 0
    }

    /// Assert that no leaks have occurred.
    ///
    /// - Parameter file: Source file location.
    /// - Parameter line: Source line location.
    /// - Throws: `Leak.Error` if leaks are detected.
    public func assertNone(
        file: StaticString = #file,
        line: UInt = #line
    ) throws(Memory.Allocation.Leak.Error) {
        let netAllocs = net.allocations
        guard netAllocs == 0 else {
            throw .detected(
                allocations: netAllocs,
                bytes: net.bytes,
                file: file,
                line: line
            )
        }
    }
}

// MARK: - Nested Accessors

extension Memory.Allocation.Leak.Detector {
    /// Accessor for net allocation values.
    public var net: Net { Net(self) }
}

extension Memory.Allocation.Leak.Detector {
    /// Net allocation accessors for leak detector.
    public struct Net: Sendable {
        private let detector: Memory.Allocation.Leak.Detector

        internal init(_ detector: Memory.Allocation.Leak.Detector) {
            self.detector = detector
        }
    }
}

extension Memory.Allocation.Leak.Detector.Net {
    /// Net allocations since initialization.
    ///
    /// Positive values indicate potential leaks.
    public var allocations: Int {
        let current = Memory.Allocation.Statistics.capture()
        let delta = Memory.Allocation.Statistics.delta(from: detector.baseline, to: current)
        return delta.net.allocations
    }

    /// Net bytes allocated since initialization.
    ///
    /// Positive values indicate potential memory leaks.
    public var bytes: Int {
        let current = Memory.Allocation.Statistics.capture()
        let delta = Memory.Allocation.Statistics.delta(from: detector.baseline, to: current)
        return delta.bytes.allocated
    }
}

// MARK: - Delta

extension Memory.Allocation.Leak.Detector {
    /// Get current allocation delta from baseline.
    ///
    /// - Returns: Allocation statistics delta from initialization.
    public func delta() -> Memory.Allocation.Statistics {
        let current = Memory.Allocation.Statistics.capture()
        return Memory.Allocation.Statistics.delta(from: baseline, to: current)
    }
}
