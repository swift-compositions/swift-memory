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
import Testing

@testable import Memory

extension Memory.Map.Range {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension Memory.Map.Range.Test.Unit {
    @Test
    func `bytes range offset`() {
        let range = Memory.Map.Range.bytes(offset: 100, length: 500)
        #expect(range.offset == 100)
    }

    @Test
    func `bytes range length`() {
        let range = Memory.Map.Range.bytes(offset: 100, length: 500)
        #expect(range.length == 500)
    }

    @Test
    func `whole range offset is zero`() {
        let range = Memory.Map.Range.whole
        #expect(range.offset == 0)
    }

    @Test
    func `whole range length is nil`() {
        let range = Memory.Map.Range.whole
        #expect(range.length == nil)
    }

    @Test
    func `range is equatable`() {
        let a = Memory.Map.Range.bytes(offset: 0, length: 100)
        let b = Memory.Map.Range.bytes(offset: 0, length: 100)
        let c = Memory.Map.Range.bytes(offset: 0, length: 200)

        #expect(a == b)
        #expect(a != c)
        #expect(Memory.Map.Range.whole == Memory.Map.Range.whole)
        #expect(a != Memory.Map.Range.whole)
    }

    @Test
    func `bytes range with zero offset`() {
        let range = Memory.Map.Range.bytes(offset: 0, length: 4096)
        #expect(range.offset == 0)
        #expect(range.length == 4096)
    }

    @Test
    func `bytes range with large offset`() {
        let range = Memory.Map.Range.bytes(offset: 1_000_000_000, length: 4096)
        #expect(range.offset == 1_000_000_000)
    }
}

// MARK: - Edge Case Tests

extension Memory.Map.Range.Test.`Edge Case` {
    // Range is a simple enum with no edge cases
}

// MARK: - Performance Tests

extension Memory.Map.Range.Test.Performance {
    // Range is a simple enum with no performance-critical operations
}
