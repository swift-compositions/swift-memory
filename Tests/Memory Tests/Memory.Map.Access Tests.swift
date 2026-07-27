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

extension Memory.Map.Access {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension Memory.Map.Access.Test.Unit {
    @Test
    func `read permission`() {
        let access: Memory.Map.Access = .read
        #expect(access.allows.read)
        #expect(!access.allows.write)
    }

    @Test
    func `write permission`() {
        let access: Memory.Map.Access = .write
        #expect(!access.allows.read)
        #expect(access.allows.write)
    }

    @Test
    func `read-write permission`() {
        let access: Memory.Map.Access = [.read, .write]
        #expect(access.allows.read)
        #expect(access.allows.write)
    }

    @Test
    func `read-only validates`() throws {
        let access: Memory.Map.Access = .read
        try access.validate()
        // Should not throw
    }

    @Test
    func `read-write validates`() throws {
        let access: Memory.Map.Access = [.read, .write]
        try access.validate()
        // Should not throw
    }

    // Memory.Map.Protection conversions are tested in swift-kernel

    @Test
    func `empty access`() {
        let access: Memory.Map.Access = []
        #expect(!access.allows.read)
        #expect(!access.allows.write)
    }

    @Test
    func `access is equatable`() {
        let a: Memory.Map.Access = .read
        let b: Memory.Map.Access = .read
        let c: Memory.Map.Access = [.read, .write]

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `access is hashable`() {
        let access: Memory.Map.Access = .read
        let set: Set<Memory.Map.Access> = [access]
        #expect(set.contains(.read))
    }
}

// MARK: - Edge Case Tests

extension Memory.Map.Access.Test.`Edge Case` {
    @Test
    func `write-only validation fails`() {
        let access: Memory.Map.Access = .write

        #expect(throws: Memory.Error.self) {
            try access.validate()
        }
    }

    @Test
    func `empty access validation succeeds`() throws {
        let access: Memory.Map.Access = []
        // Empty access is technically valid (no write without read)
        try access.validate()
    }
}

// MARK: - Performance Tests

extension Memory.Map.Access.Test.Performance {
    // Access is a simple OptionSet with no performance-critical operations
}
