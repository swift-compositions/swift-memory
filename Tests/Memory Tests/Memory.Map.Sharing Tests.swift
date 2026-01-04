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

extension Memory.Map.Sharing {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Map.Sharing.Test.Unit {
    @Test("shared mode")
    func sharedMode() {
        let sharing = Memory.Map.Sharing.shared
        #expect(sharing == .shared)
    }

    @Test("private mode")
    func privateMode() {
        let sharing = Memory.Map.Sharing.private
        #expect(sharing == .private)
    }

    @Test("sharing is equatable")
    func sharingIsEquatable() {
        let a = Memory.Map.Sharing.shared
        let b = Memory.Map.Sharing.shared
        let c = Memory.Map.Sharing.private

        #expect(a == b)
        #expect(a != c)
    }

    @Test("kernel flags for shared")
    func kernelFlagsForShared() {
        let sharing = Memory.Map.Sharing.shared
        #expect(sharing.kernelFlags == .shared)
    }

    @Test("kernel flags for private")
    func kernelFlagsForPrivate() {
        let sharing = Memory.Map.Sharing.private
        #expect(sharing.kernelFlags == .private)
    }

    #if !os(Windows)
    @Test("anonymous mapping default is private")
    func anonymousMappingDefaultIsPrivate() throws {
        let map = try Memory.Map(anonymousLength: 4096)
        let sharing = map.sharing
        map.unmap()
        #expect(sharing == .private)
    }

    @Test("anonymous mapping with shared")
    func anonymousMappingWithShared() throws {
        let map = try Memory.Map(anonymousLength: 4096, sharing: .shared)
        let sharing = map.sharing
        map.unmap()
        #expect(sharing == .shared)
    }

    @Test("anonymous mapping with private")
    func anonymousMappingWithPrivate() throws {
        let map = try Memory.Map(anonymousLength: 4096, sharing: .private)
        let sharing = map.sharing
        map.unmap()
        #expect(sharing == .private)
    }
    #endif
}

// MARK: - Edge Case Tests

extension Memory.Map.Sharing.Test.EdgeCase {
    // Sharing is a simple enum with no edge cases
}

// MARK: - Performance Tests

extension Memory.Map.Sharing.Test.Performance {
    // Sharing is a simple enum with no performance-critical operations
}
