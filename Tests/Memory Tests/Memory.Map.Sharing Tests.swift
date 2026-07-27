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

import Testing

@testable import Memory

extension Memory.Map.Sharing {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension Memory.Map.Sharing.Test.Unit {
    @Test
    func `shared mode`() {
        let sharing = Memory.Map.Sharing.shared
        #expect(sharing == .shared)
    }

    @Test
    func `private mode`() {
        let sharing = Memory.Map.Sharing.private
        #expect(sharing == .private)
    }

    @Test
    func `sharing is equatable`() {
        let a = Memory.Map.Sharing.shared
        let b = Memory.Map.Sharing.shared
        let c = Memory.Map.Sharing.private

        #expect(a == b)
        #expect(a != c)
    }

    // Memory.Map.Sharing conversions are tested in swift-kernel

    #if os(macOS) || os(Linux)
        @Test
        func `anonymous mapping default is private`() throws {
            let map = try Memory.Map(anonymousLength: 4096)
            let sharing = map.sharing
            map.unmap()
            #expect(sharing == .private)
        }

        @Test
        func `anonymous mapping with shared`() throws {
            let map = try Memory.Map(anonymousLength: 4096, sharing: .shared)
            let sharing = map.sharing
            map.unmap()
            #expect(sharing == .shared)
        }

        @Test
        func `anonymous mapping with private`() throws {
            let map = try Memory.Map(anonymousLength: 4096, sharing: .private)
            let sharing = map.sharing
            map.unmap()
            #expect(sharing == .private)
        }
    #endif
}

// MARK: - Edge Case Tests

extension Memory.Map.Sharing.Test.`Edge Case` {
    // Sharing is a simple enum with no edge cases
}

// MARK: - Performance Tests

extension Memory.Map.Sharing.Test.Performance {
    // Sharing is a simple enum with no performance-critical operations
}
