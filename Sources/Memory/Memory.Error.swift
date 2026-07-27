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

extension Memory {
    /// Errors that can occur during high-level memory operations.
    ///
    /// Composes L1 domain-specific errors with L3 semantic validation errors.
    /// Per the L1-domain-only / L3-composes architecture, L1 has only
    /// domain-specific errors (Memory.Map.Error, Memory.Shared.Error,
    /// Memory.Lock.Error, Memory.Allocation.Error, Memory.Address.Error);
    /// `Memory.Error` is the L3 top-level wrapper.
    public enum Error: Swift.Error, Sendable {
        // MARK: - L3 Semantic Validation

        /// Invalid access combination (e.g., `.write` without `.read`).
        case access

        /// The file is too small for the requested mapping.
        case size

        /// The mapping was previously unmapped and cannot be used.
        case unmapped

        // MARK: - L1 Domain Error Wrappers

        /// Memory mapping operation failed.
        case map(Memory.Map.Error)

        /// Shared memory operation failed.
        case shared(Memory.Shared.Error)

        /// Memory locking operation failed (mlock/munlock vocabulary).
        case lock(Memory.Lock.Error)

        // MARK: - Cross-Domain Wrappers

        /// File locking failed during coordinated mapping.
        case fileLock(Kernel.Lock.Error)

        /// Failed to get file metadata.
        case stat(Kernel.File.Stats.Error)
    }
}

// MARK: - CustomStringConvertible

extension Memory.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .access:
            return "Invalid access combination (write requires read)"

        case .size:
            return "File too small for requested mapping"

        case .unmapped:
            return "Mapping already unmapped"

        case .map(let error):
            return "Memory map: \(error)"

        case .shared(let error):
            return "Shared memory: \(error)"

        case .lock(let error):
            return "Memory lock: \(error)"

        case .fileLock(let error):
            return "File lock: \(error)"

        case .stat(let error):
            return "Stat: \(error)"
        }
    }
}

// MARK: - Convenience Initializers

extension Memory.Error {
    /// Creates an error from a Memory.Map.Error.
    @inlinable
    public init(from error: Memory.Map.Error) {
        self = .map(error)
    }

    /// Creates an error from a Memory.Shared.Error.
    @inlinable
    public init(from error: Memory.Shared.Error) {
        self = .shared(error)
    }

    /// Creates an error from a Memory.Lock.Error.
    @inlinable
    public init(from error: Memory.Lock.Error) {
        self = .lock(error)
    }
}
