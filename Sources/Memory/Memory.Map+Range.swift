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

public import Kernel

extension Memory.Map {
    /// Range specification for mapping.
    public enum Range: Sendable, Equatable {
        /// Map a specific byte range.
        ///
        /// - Parameters:
        ///   - offset: Starting offset in the file (will be aligned down to granularity).
        ///   - length: Number of bytes to map.
        case bytes(offset: Kernel.File.Offset, length: Kernel.File.Size)

        /// Map the whole file.
        ///
        /// The file size is queried at map time via `fstat` (POSIX) or
        /// `GetFileSizeEx` (Windows). This provides a **snapshot** of the size
        /// at the moment of mapping.
        ///
        /// - Important: This is not a live view. If the file grows after mapping,
        ///   the region does **not** automatically extend.
        case whole
    }
}

// MARK: - Computed Properties

extension Memory.Map.Range {
    /// The starting offset.
    public var offset: Kernel.File.Offset {
        switch self {
        case .bytes(let offset, _): return offset
        case .whole: return .zero
        }
    }

    /// The length for a specific byte range.
    ///
    /// - Note: For `.whole`, returns nil. The actual length is resolved
    ///         at map time by querying the file.
    public var length: Kernel.File.Size? {
        switch self {
        case .bytes(_, let length): return length
        case .whole: return nil
        }
    }
}
