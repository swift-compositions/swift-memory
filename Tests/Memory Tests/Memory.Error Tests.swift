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

extension Memory.Error {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Error.Test.Unit {
    @Test("access error has description")
    func accessErrorDescription() {
        let error = Memory.Error.access
        #expect(!error.description.isEmpty)
        #expect(error.description.contains("access"))
    }

    @Test("size error has description")
    func sizeErrorDescription() {
        let error = Memory.Error.size
        #expect(!error.description.isEmpty)
        #expect(error.description.contains("size") || error.description.contains("small"))
    }

    @Test("unmapped error has description")
    func unmappedErrorDescription() {
        let error = Memory.Error.unmapped
        #expect(!error.description.isEmpty)
        #expect(error.description.contains("unmapped"))
    }

    @Test("map error wrapper has description")
    func mapErrorDescription() {
        let error = Memory.Error.map(.map(.posix(22)))
        #expect(!error.description.isEmpty)
    }

    @Test("page error wrapper has description")
    func pageErrorDescription() {
        let error = Memory.Error.page(.lock(.posix(1)))
        #expect(!error.description.isEmpty)
    }

    @Test("convenience init from map error")
    func convenienceInitFromMapError() {
        let kernelError = Kernel.Memory.Map.Error.map(.posix(22))
        let error = Memory.Error(from: kernelError)
        if case .map = error {
            // Correct case
        } else {
            Issue.record("Expected .map case")
        }
    }

    @Test("convenience init from page lock error")
    func convenienceInitFromPageError() {
        let kernelError = Kernel.Memory.Lock.Error.lock(.posix(1))
        let error = Memory.Error(from: kernelError)
        if case .page = error {
            // Correct case
        } else {
            Issue.record("Expected .page case")
        }
    }

    #if os(macOS) || os(Linux)
    @Test("shared error wrapper has description")
    func sharedErrorDescription() {
        let error = Memory.Error.shared(.open(.posix(2)))
        #expect(!error.description.isEmpty)
    }

    @Test("convenience init from shared error")
    func convenienceInitFromSharedError() {
        let kernelError = Kernel.Memory.Shared.Error.open(.posix(2))
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

extension Memory.Error.Test.EdgeCase {
    // Error types have no edge cases to test
}

// MARK: - Performance Tests

extension Memory.Error.Test.Performance {
    // Error types have no performance-critical operations
}
