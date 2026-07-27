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

extension Memory {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension Memory.Test.Unit {
    // Kernel.System properties (pageSize, allocationGranularity) are tested in swift-kernel
}

// MARK: - Edge Case Tests

extension Memory.Test.`Edge Case` {
    // Memory namespace has no edge cases to test
}

// MARK: - Performance Tests

extension Memory.Test.Performance {
    // Memory namespace has no performance-critical operations
}
