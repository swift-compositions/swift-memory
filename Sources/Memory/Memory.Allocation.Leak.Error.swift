// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-memory open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-memory project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

extension Memory.Allocation.Leak {
    /// Leak detection error.
    public enum Error: Swift.Error, Sendable {
        /// Memory leaks were detected.
        case detected(allocations: Int, bytes: Int, file: StaticString, line: UInt)
    }
}

// MARK: - CustomStringConvertible

extension Memory.Allocation.Leak.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .detected(let allocations, let bytes, let file, let line):
            return """
                Memory leak detected at \(file):\(line)
                Net allocations: \(allocations)
                Net bytes: \(bytes)
                """
        }
    }
}
