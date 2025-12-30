// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-mmap open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-mmap project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

internal import Kernel

extension MMap.Region {
    /// Sharing semantics for the mapped region.
    public enum Sharing: Sendable, Equatable {
        /// Changes are visible to other mappings of the same file.
        ///
        /// Maps to:
        /// - POSIX: `MAP_SHARED`
        /// - Windows: Normal file mapping
        case shared

        /// Changes are private to this mapping (copy-on-write).
        ///
        /// Maps to:
        /// - POSIX: `MAP_PRIVATE`
        /// - Windows: `PAGE_WRITECOPY`
        case `private`

        /// Converts to Kernel mapping flags.
        var kernelFlags: Kernel.Mmap.Flags {
            switch self {
            case .shared: return .shared
            case .private: return .private
            }
        }
    }
}
