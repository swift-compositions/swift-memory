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

import StandardsTestSupport
import Testing

@testable import Memory

extension Memory {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Test.Unit {
    @Test("page.size is positive")
    func pageSizePositive() {
        #expect(Memory.page.size > 0)
    }

    @Test("page.size is at least 4096")
    func pageSizeAtLeast4K() {
        #expect(Memory.page.size >= 4096)
    }

    @Test("allocation.granularity is positive")
    func allocationGranularityPositive() {
        #expect(Memory.allocation.granularity > 0)
    }

    @Test("allocation.granularity >= page.size")
    func allocationGranularityAtLeastPageSize() {
        #expect(Memory.allocation.granularity >= Memory.page.size)
    }
}

// MARK: - Edge Case Tests

extension Memory.Test.EdgeCase {
    // Memory namespace has no edge cases to test
}

// MARK: - Performance Tests

extension Memory.Test.Performance {
    // Memory namespace has no performance-critical operations
}
