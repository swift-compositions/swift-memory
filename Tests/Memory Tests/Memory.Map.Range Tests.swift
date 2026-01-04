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

import Kernel
import StandardsTestSupport
import Testing

@testable import Memory

extension Memory.Map.Range {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Map.Range.Test.Unit {
    @Test("bytes range offset")
    func bytesRangeOffset() {
        let range = Memory.Map.Range.bytes(offset: 100, length: 500)
        #expect(range.offset == 100)
    }

    @Test("bytes range length")
    func bytesRangeLength() {
        let range = Memory.Map.Range.bytes(offset: 100, length: 500)
        #expect(range.length == 500)
    }

    @Test("whole range offset is zero")
    func wholeRangeOffsetIsZero() {
        let range = Memory.Map.Range.whole
        #expect(range.offset == 0)
    }

    @Test("whole range length is nil")
    func wholeRangeLengthIsNil() {
        let range = Memory.Map.Range.whole
        #expect(range.length == nil)
    }

    @Test("range is equatable")
    func rangeIsEquatable() {
        let a = Memory.Map.Range.bytes(offset: 0, length: 100)
        let b = Memory.Map.Range.bytes(offset: 0, length: 100)
        let c = Memory.Map.Range.bytes(offset: 0, length: 200)

        #expect(a == b)
        #expect(a != c)
        #expect(Memory.Map.Range.whole == Memory.Map.Range.whole)
        #expect(a != Memory.Map.Range.whole)
    }

    @Test("bytes range with zero offset")
    func bytesRangeWithZeroOffset() {
        let range = Memory.Map.Range.bytes(offset: 0, length: 4096)
        #expect(range.offset == 0)
        #expect(range.length == 4096)
    }

    @Test("bytes range with large offset")
    func bytesRangeWithLargeOffset() {
        let range = Memory.Map.Range.bytes(offset: 1_000_000_000, length: 4096)
        #expect(range.offset == 1_000_000_000)
    }
}

// MARK: - Edge Case Tests

extension Memory.Map.Range.Test.EdgeCase {
    // Range is a simple enum with no edge cases
}

// MARK: - Performance Tests

extension Memory.Map.Range.Test.Performance {
    // Range is a simple enum with no performance-critical operations
}
