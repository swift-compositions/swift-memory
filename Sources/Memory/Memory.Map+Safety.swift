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
    /// Safety mode for SIGBUS/access-violation protection.
    public enum Safety: Sendable, Equatable {
        /// Coordinated access with file locking.
        ///
        /// The mapping holds a file lock for its entire lifetime.
        /// This prevents SIGBUS from truncation **if all writers respect the same lock discipline**.
        ///
        /// - Parameters:
        ///   - kind: The lock kind (.shared for read, .exclusive for write).
        ///   - scope: The lock scope (.file or .mapped).
        case coordinated(Kernel.Lock.Kind, scope: Scope)

        /// Unchecked access with no locking.
        ///
        /// The caller accepts the risk of SIGBUS/access-violation if the file
        /// is truncated or modified by another process.
        ///
        /// Use for: append-only files, immutable snapshots, WAL segments.
        case unchecked
    }
}

// MARK: - Scope

extension Memory.Map.Safety {
    /// Lock scope for coordinated safety.
    public enum Scope: Sendable, Equatable {
        /// Lock the entire file.
        case file
        /// Lock the mapped range (rounded to granularity).
        case mapped
    }
}

// MARK: - Default Accessor

extension Memory.Map.Safety {
    /// Nested accessor for default safety modes.
    public static var `default`: Default.Type { Default.self }

    /// Default safety modes.
    public enum Default {
        /// Default safety for read access.
        public static var read: Memory.Map.Safety {
            .coordinated(.shared, scope: .mapped)
        }

        /// Default safety for write access.
        public static var write: Memory.Map.Safety {
            .coordinated(.exclusive, scope: .mapped)
        }
    }
}
