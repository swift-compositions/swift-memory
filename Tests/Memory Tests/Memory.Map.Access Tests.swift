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

import Test_Primitives
import Testing

@testable import Memory

extension Memory.Map.Access {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Map.Access.Test.Unit {
    @Test("read permission")
    func readPermission() {
        let access: Memory.Map.Access = .read
        #expect(access.allows.read)
        #expect(!access.allows.write)
    }

    @Test("write permission")
    func writePermission() {
        let access: Memory.Map.Access = .write
        #expect(!access.allows.read)
        #expect(access.allows.write)
    }

    @Test("read-write permission")
    func readWritePermission() {
        let access: Memory.Map.Access = [.read, .write]
        #expect(access.allows.read)
        #expect(access.allows.write)
    }

    @Test("read-only validates")
    func readOnlyValidates() throws {
        let access: Memory.Map.Access = .read
        try access.validate()
        // Should not throw
    }

    @Test("read-write validates")
    func readWriteValidates() throws {
        let access: Memory.Map.Access = [.read, .write]
        try access.validate()
        // Should not throw
    }

    // Kernel.Memory.Map.Protection conversions are tested in swift-kernel

    @Test("empty access")
    func emptyAccess() {
        let access: Memory.Map.Access = []
        #expect(!access.allows.read)
        #expect(!access.allows.write)
    }

    @Test("access is equatable")
    func accessIsEquatable() {
        let a: Memory.Map.Access = .read
        let b: Memory.Map.Access = .read
        let c: Memory.Map.Access = [.read, .write]

        #expect(a == b)
        #expect(a != c)
    }

    @Test("access is hashable")
    func accessIsHashable() {
        let access: Memory.Map.Access = .read
        let set: Set<Memory.Map.Access> = [access]
        #expect(set.contains(.read))
    }
}

// MARK: - Edge Case Tests

extension Memory.Map.Access.Test.EdgeCase {
    @Test("write-only validation fails")
    func writeOnlyValidationFails() {
        let access: Memory.Map.Access = .write

        #expect(throws: Memory.Error.self) {
            try access.validate()
        }
    }

    @Test("empty access validation succeeds")
    func emptyAccessValidationSucceeds() throws {
        let access: Memory.Map.Access = []
        // Empty access is technically valid (no write without read)
        try access.validate()
    }
}

// MARK: - Performance Tests

extension Memory.Map.Access.Test.Performance {
    // Access is a simple OptionSet with no performance-critical operations
}
