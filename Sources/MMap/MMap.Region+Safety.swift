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

public import Kernel

extension MMap.Region {
    /// Safety mode for SIGBUS/access-violation protection.
    public enum Safety: Sendable, Equatable {
        /// Coordinated access with file locking.
        ///
        /// The mapping holds a file lock for its entire lifetime.
        /// This prevents SIGBUS from truncation **if all writers respect the same lock discipline**.
        ///
        /// - Parameters:
        ///   - kind: The lock kind (.shared for read, .exclusive for write).
        ///   - scope: The lock scope (.file or .mappedRange).
        case coordinated(Kernel.Lock.Kind, scope: Scope)

        /// Unchecked access with no locking.
        ///
        /// The caller accepts the risk of SIGBUS/access-violation if the file
        /// is truncated or modified by another process.
        ///
        /// Use for: append-only files, immutable snapshots, WAL segments.
        case unchecked

        /// Lock scope for coordinated safety.
        public enum Scope: Sendable, Equatable {
            /// Lock the entire file.
            case file
            /// Lock the mapped range (rounded to granularity).
            case mappedRange
        }

        /// Default safety for read access.
        public static var defaultForRead: Safety {
            .coordinated(.shared, scope: .mappedRange)
        }

        /// Default safety for write access.
        public static var defaultForWrite: Safety {
            .coordinated(.exclusive, scope: .mappedRange)
        }
    }
}
