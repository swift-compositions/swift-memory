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

public import Kernel

// MARK: - Kernel Conversion (L3 — references L2-extended Protection constants)

extension Memory.Map.Access {
    /// Converts to Memory.Map protection flags.
    @inlinable
    public var kernelProtection: Memory.Map.Protection {
        switch (contains(.read), contains(.write)) {
        case (true, true):
            return Memory.Map.Protection.read | Memory.Map.Protection.write

        case (true, false):
            return .read

        case (false, true):
            return .write

        case (false, false):
            return .none
        }
    }
}

// MARK: - Validation (L3 — references L3-extended Memory.Error.access)

extension Memory.Map.Access {
    /// Validates that the access combination is supported.
    ///
    /// - Throws: `Memory.Error.access` if `.write` is specified without `.read`.
    @inlinable
    public func validate() throws(Memory.Error) {
        if contains(.write) && !contains(.read) {
            throw .access
        }
    }
}
