// This source file is part of the swift-memory open source project
// Copyright (c) 2026 Coen ten Thije Boonkkamp and project authors
// Licensed under Apache License v2.0

import Testing

@testable import Memory

extension Memory.Test.Unit {
    @Test func `allocation delta preserves observation semantics`() {
        let baseline = Memory.Allocation.Statistics(
            allocations: 3,
            deallocations: 1,
            bytesAllocated: 16,
            availability: .available,
            scope: .thread,
            instrumentation: .interposed
        )
        let current = Memory.Allocation.Statistics(
            allocations: 8,
            deallocations: 4,
            bytesAllocated: 80,
            availability: .available,
            scope: .thread,
            instrumentation: .interposed
        )

        let delta = Memory.Allocation.Statistics.delta(from: baseline, to: current)
        #expect(delta.allocations == 5)
        #expect(delta.deallocations == 3)
        #expect(delta.bytesAllocated == 64)
        #expect(delta.availability == .available)
        #expect(delta.scope == .thread)
        #expect(delta.instrumentation == .interposed)
    }
}

extension Memory.Test.Performance {
    @Test func `platform allocation observation is real and labelled`() {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS) || os(Linux)
            let snapshot = Memory.Allocation.Statistics.capture()
            let (storage, statistics) = Memory.Allocation.Tracker.measure {
                Array(repeating: UInt8(1), count: 1_048_576)
            }
            #expect(storage.count == 1_048_576)
            #expect(snapshot.availability == .available)
            #expect(snapshot.bytesAllocated > 0)
            #expect(statistics.availability == .available)

            #if os(Linux)
                #expect(statistics.scope == .thread)
                #expect(statistics.instrumentation == .interposed)
            #else
                #expect(statistics.scope == .process)
                #expect(statistics.instrumentation == .snapshot)
            #endif
        #else
            #expect(Memory.Allocation.Statistics.capture().availability == .unavailable)
        #endif
    }
}
