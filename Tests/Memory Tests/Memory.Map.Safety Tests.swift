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

extension Memory.Map.Safety {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension Memory.Map.Safety.Test.Unit {
    @Test
    func `unchecked safety`() {
        let safety = Memory.Map.Safety.unchecked
        if case .unchecked = safety {
            // Correct
        } else {
            Issue.record("Expected unchecked")
        }
    }

    @Test
    func `coordinated shared safety`() {
        let safety = Memory.Map.Safety.coordinated(.shared, scope: .file)
        if case .coordinated(let kind, let scope) = safety {
            #expect(kind == .shared)
            #expect(scope == .file)
        } else {
            Issue.record("Expected coordinated")
        }
    }

    @Test
    func `coordinated exclusive safety`() {
        let safety = Memory.Map.Safety.coordinated(.exclusive, scope: .mapped)
        if case .coordinated(let kind, let scope) = safety {
            #expect(kind == .exclusive)
            #expect(scope == .mapped)
        } else {
            Issue.record("Expected coordinated")
        }
    }

    @Test
    func `default read safety`() {
        let safety = Memory.Map.Safety.default.read
        if case .coordinated(let kind, let scope) = safety {
            #expect(kind == .shared)
            #expect(scope == .mapped)
        } else {
            Issue.record("Expected coordinated")
        }
    }

    @Test
    func `default write safety`() {
        let safety = Memory.Map.Safety.default.write
        if case .coordinated(let kind, let scope) = safety {
            #expect(kind == .exclusive)
            #expect(scope == .mapped)
        } else {
            Issue.record("Expected coordinated")
        }
    }

    @Test
    func `scope file`() {
        let scope = Memory.Map.Safety.Scope.file
        #expect(scope == .file)
    }

    @Test
    func `scope mapped`() {
        let scope = Memory.Map.Safety.Scope.mapped
        #expect(scope == .mapped)
    }

    @Test
    func `safety is equatable`() {
        let a = Memory.Map.Safety.unchecked
        let b = Memory.Map.Safety.unchecked
        let c = Memory.Map.Safety.coordinated(.shared, scope: .file)

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `scope is equatable`() {
        let a = Memory.Map.Safety.Scope.file
        let b = Memory.Map.Safety.Scope.file
        let c = Memory.Map.Safety.Scope.mapped

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `coordinated with different scopes are not equal`() {
        let fileScope = Memory.Map.Safety.coordinated(.shared, scope: .file)
        let mappedScope = Memory.Map.Safety.coordinated(.shared, scope: .mapped)

        #expect(fileScope != mappedScope)
    }

    @Test
    func `coordinated with different kinds are not equal`() {
        let shared = Memory.Map.Safety.coordinated(.shared, scope: .file)
        let exclusive = Memory.Map.Safety.coordinated(.exclusive, scope: .file)

        #expect(shared != exclusive)
    }
}

// MARK: - Edge Case Tests

extension Memory.Map.Safety.Test.`Edge Case` {
    // Safety is a simple enum with no edge cases
}

// MARK: - Performance Tests

extension Memory.Map.Safety.Test.Performance {
    // Safety is a simple enum with no performance-critical operations
}
