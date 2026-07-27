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
    /// Measures allocation statistics during an operation.
    /// Stub: captures before/after snapshots.
    public enum Tracker {}
}

extension Memory.Allocation.Tracker {
    public static func measure<T, E: Swift.Error>(
        _ operation: () throws(E) -> T
    ) throws(E) -> (T, Memory.Allocation.Statistics) {
        let before = Memory.Allocation.Statistics.capture()
        let result = try operation()
        let after = Memory.Allocation.Statistics.capture()
        return (result, Memory.Allocation.Statistics.delta(from: before, to: after))
    }

    nonisolated(nonsending)
        public static func measure<T, E: Swift.Error>(
            _ operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> (T, Memory.Allocation.Statistics)
    {
        let before = Memory.Allocation.Statistics.capture()
        let result = try await operation()
        let after = Memory.Allocation.Statistics.capture()
        return (result, Memory.Allocation.Statistics.delta(from: before, to: after))
    }
}
