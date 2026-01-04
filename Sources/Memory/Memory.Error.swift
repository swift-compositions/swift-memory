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

extension Memory {
    /// Errors that can occur during memory operations.
    ///
    /// High-level semantic errors are exposed directly. Platform-specific
    /// errors are wrapped in their respective Kernel error types.
    public enum Error: Swift.Error, Sendable {
        // MARK: - Semantic Errors (Memory-layer validation)

        /// Invalid access combination (e.g., `.write` without `.read`).
        case access

        /// The file is too small for the requested mapping.
        case size

        /// The mapping was previously unmapped and cannot be used.
        case unmapped

        // MARK: - Kernel Error Wrappers

        /// Memory mapping operation failed.
        case map(Kernel.Memory.Map.Error)

        /// Shared memory operation failed.
        #if !os(Windows)
        case shared(Kernel.Memory.Shared.Error)
        #endif

        /// Page locking operation failed.
        case page(Kernel.Memory.Lock.Error)

        /// File locking failed during coordinated mapping.
        case lock(Kernel.Lock.Error)

        /// Failed to get file metadata.
        case stat(Kernel.File.Stats.Error)
    }
}

// MARK: - CustomStringConvertible

extension Memory.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .access:
            return "Invalid access combination (write requires read)"
        case .size:
            return "File too small for requested mapping"
        case .unmapped:
            return "Mapping already unmapped"
        case .map(let error):
            return "Memory map: \(error)"
        #if !os(Windows)
        case .shared(let error):
            return "Shared memory: \(error)"
        #endif
        case .page(let error):
            return "Page lock: \(error)"
        case .lock(let error):
            return "File lock: \(error)"
        case .stat(let error):
            return "Stat: \(error)"
        }
    }
}

// MARK: - Convenience Initializers

extension Memory.Error {
    /// Creates an error from a Kernel.Memory.Map.Error.
    @inlinable
    public init(from error: Kernel.Memory.Map.Error) {
        self = .map(error)
    }

    #if !os(Windows)
    /// Creates an error from a Kernel.Memory.Shared.Error.
    @inlinable
    public init(from error: Kernel.Memory.Shared.Error) {
        self = .shared(error)
    }
    #endif

    /// Creates an error from a Kernel.Memory.Lock.Error.
    @inlinable
    public init(from error: Kernel.Memory.Lock.Error) {
        self = .page(error)
    }
}
