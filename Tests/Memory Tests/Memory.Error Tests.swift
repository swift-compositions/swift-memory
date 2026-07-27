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

extension Memory.Error {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension Memory.Error.Test.Unit {
    @Test
    func `access error has description`() {
        let error = Memory.Error.access
        #expect(!error.description.isEmpty)
        #expect(error.description.contains("access"))
    }

    @Test
    func `size error has description`() {
        let error = Memory.Error.size
        #expect(!error.description.isEmpty)
        #expect(error.description.contains("size") || error.description.contains("small"))
    }

    @Test
    func `unmapped error has description`() {
        let error = Memory.Error.unmapped
        #expect(!error.description.isEmpty)
        #expect(error.description.contains("unmapped"))
    }

    @Test
    func `map error wrapper has description`() {
        let error = Memory.Error.map(.map(.posix(22)))
        #expect(!error.description.isEmpty)
    }

    @Test
    func `lock error wrapper has description`() {
        let error = Memory.Error.lock(.lock(.posix(1)))
        #expect(!error.description.isEmpty)
    }

    @Test
    func `convenience init from map error`() {
        let kernelError = Memory.Map.Error.map(.posix(22))
        let error = Memory.Error(from: kernelError)
        if case .map = error {
            // Correct case
        } else {
            Issue.record("Expected .map case")
        }
    }

    @Test
    func `convenience init from memory lock error`() {
        let kernelError = Memory.Lock.Error.lock(.posix(1))
        let error = Memory.Error(from: kernelError)
        if case .lock = error {
            // Correct case
        } else {
            Issue.record("Expected .lock case")
        }
    }

    #if os(macOS) || os(Linux)
        @Test
        func `shared error wrapper has description`() {
            let error = Memory.Error.shared(.open(.posix(2)))
            #expect(!error.description.isEmpty)
        }

        @Test
        func `convenience init from shared error`() {
            let kernelError = Memory.Shared.Error.open(.posix(2))
            let error = Memory.Error(from: kernelError)
            if case .shared = error {
                // Correct case
            } else {
                Issue.record("Expected .shared case")
            }
        }
    #endif
}

// MARK: - Edge Case Tests

extension Memory.Error.Test.`Edge Case` {
    // Error types have no edge cases to test
}

// MARK: - Performance Tests

extension Memory.Error.Test.Performance {
    // Error types have no performance-critical operations
}
