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

extension Memory.Map.Safety {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Map.Safety.Test.Unit {
    @Test("unchecked safety")
    func uncheckedSafety() {
        let safety = Memory.Map.Safety.unchecked
        if case .unchecked = safety {
            // Correct
        } else {
            Issue.record("Expected unchecked")
        }
    }

    @Test("coordinated shared safety")
    func coordinatedSharedSafety() {
        let safety = Memory.Map.Safety.coordinated(.shared, scope: .file)
        if case .coordinated(let kind, let scope) = safety {
            #expect(kind == .shared)
            #expect(scope == .file)
        } else {
            Issue.record("Expected coordinated")
        }
    }

    @Test("coordinated exclusive safety")
    func coordinatedExclusiveSafety() {
        let safety = Memory.Map.Safety.coordinated(.exclusive, scope: .mapped)
        if case .coordinated(let kind, let scope) = safety {
            #expect(kind == .exclusive)
            #expect(scope == .mapped)
        } else {
            Issue.record("Expected coordinated")
        }
    }

    @Test("default read safety")
    func defaultReadSafety() {
        let safety = Memory.Map.Safety.default.read
        if case .coordinated(let kind, let scope) = safety {
            #expect(kind == .shared)
            #expect(scope == .mapped)
        } else {
            Issue.record("Expected coordinated")
        }
    }

    @Test("default write safety")
    func defaultWriteSafety() {
        let safety = Memory.Map.Safety.default.write
        if case .coordinated(let kind, let scope) = safety {
            #expect(kind == .exclusive)
            #expect(scope == .mapped)
        } else {
            Issue.record("Expected coordinated")
        }
    }

    @Test("scope file")
    func scopeFile() {
        let scope = Memory.Map.Safety.Scope.file
        #expect(scope == .file)
    }

    @Test("scope mapped")
    func scopeMapped() {
        let scope = Memory.Map.Safety.Scope.mapped
        #expect(scope == .mapped)
    }

    @Test("safety is equatable")
    func safetyIsEquatable() {
        let a = Memory.Map.Safety.unchecked
        let b = Memory.Map.Safety.unchecked
        let c = Memory.Map.Safety.coordinated(.shared, scope: .file)

        #expect(a == b)
        #expect(a != c)
    }

    @Test("scope is equatable")
    func scopeIsEquatable() {
        let a = Memory.Map.Safety.Scope.file
        let b = Memory.Map.Safety.Scope.file
        let c = Memory.Map.Safety.Scope.mapped

        #expect(a == b)
        #expect(a != c)
    }

    @Test("coordinated with different scopes are not equal")
    func coordinatedDifferentScopes() {
        let fileScope = Memory.Map.Safety.coordinated(.shared, scope: .file)
        let mappedScope = Memory.Map.Safety.coordinated(.shared, scope: .mapped)

        #expect(fileScope != mappedScope)
    }

    @Test("coordinated with different kinds are not equal")
    func coordinatedDifferentKinds() {
        let shared = Memory.Map.Safety.coordinated(.shared, scope: .file)
        let exclusive = Memory.Map.Safety.coordinated(.exclusive, scope: .file)

        #expect(shared != exclusive)
    }
}

// MARK: - Edge Case Tests

extension Memory.Map.Safety.Test.EdgeCase {
    // Safety is a simple enum with no edge cases
}

// MARK: - Performance Tests

extension Memory.Map.Safety.Test.Performance {
    // Safety is a simple enum with no performance-critical operations
}
