// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-memory open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-memory project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

internal import Kernel

// MARK: - Kernel Conversion (L3 — references L2-extended Options constants)

extension Memory.Map.Sharing {
    /// Converts to Memory.Map mapping options.
    @inlinable
    public var kernelOptions: Memory.Map.Options {
        switch self {
        case .shared: return .shared
        case .private: return .private
        }
    }
}
