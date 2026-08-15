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
@_spi(MemoryInternal) public import Memory_Map_Primitives

// MARK: - Consuming Operations

extension Memory.Map {
    /// Unmaps the region and releases all resources.
    ///
    /// After calling `unmap()`, the region cannot be used.
    public consuming func unmap() {
        guard let currentRegion = _region else { return }

        // Release lock token (its release closure unlocks + closes the dup'd fd)
        _lockToken?.release()

        // Unmap the region via the witness closure (resolves to L2 syscall on active platform)
        do throws(Self.Error) {
            try Self.unmap(currentRegion)
        } catch {}

        // Mark unmapped so deinit becomes a no-op
        _region = nil
    }
}

// MARK: - Remap

#if !os(Windows)
    extension Memory.Map {
        /// Remaps the region to a new range.
        public consuming func remap(
            fileDescriptor: borrowing Kernel.Descriptor,
            range: Range
        ) throws(Memory.Error) -> Self {
            let capturedAccess = access
            let capturedSharing = sharing
            let capturedSafety = safety

            self.unmap()

            return try Self(
                fileDescriptor: fileDescriptor,
                range: range,
                access: capturedAccess,
                sharing: capturedSharing,
                safety: capturedSafety
            )
        }
    }
#endif

#if os(Windows)
    extension Memory.Map {
        public consuming func remap(
            fileHandle: borrowing Kernel.Descriptor,
            range: Range
        ) throws(Memory.Error) -> Self {
            let capturedAccess = access
            let capturedSharing = sharing
            let capturedSafety = safety

            self.unmap()

            return try Self.open(
                fileHandle: fileHandle,
                range: range,
                access: capturedAccess,
                sharing: capturedSharing,
                safety: capturedSafety
            )
        }
    }
#endif

// MARK: - Access Methods

extension Memory.Map {
    /// Accesses a byte at the given index.
    public subscript(index: Index) -> Byte {
        get {
            precondition(index < endIndex, "Index out of bounds")
            guard let base = unsafe baseAddress else {
                preconditionFailure("Mapping is not valid")
            }
            return Byte(
                unsafe base.load(
                    fromByteOffset: Int(bitPattern: index.underlying.rawValue),
                    as: UInt8.self
                )
            )
        }
        nonmutating set {
            precondition(access.allows.write, "Mapping does not allow writes")
            precondition(index < endIndex, "Index out of bounds")
            guard let base = unsafe mutableBaseAddress else {
                preconditionFailure("Mapping is not valid")
            }
            unsafe base.storeBytes(
                of: newValue.underlying,
                toByteOffset: Int(bitPattern: index.underlying.rawValue),
                as: UInt8.self
            )
        }
    }

    /// Provides read-only access to the mapped bytes.
    public func withUnsafeBytes<T, E: Swift.Error>(
        _ body: (UnsafeRawBufferPointer) throws(E) -> T
    ) throws(E) -> T {
        guard let base = unsafe baseAddress else {
            preconditionFailure("Mapping is not valid")
        }
        let buffer = unsafe UnsafeRawBufferPointer(
            start: base,
            count: Int(bitPattern: _userLength.underlying.rawValue)
        )
        return try unsafe body(buffer)
    }

    /// Provides mutable access to the mapped bytes.
    public func withUnsafeMutableBytes<T, E: Swift.Error>(
        _ body: (UnsafeMutableRawBufferPointer) throws(E) -> T
    ) throws(E) -> T {
        precondition(access.allows.write, "Mapping does not allow writes")
        guard let base = unsafe mutableBaseAddress else {
            preconditionFailure("Mapping is not valid")
        }
        let buffer = unsafe UnsafeMutableRawBufferPointer(
            start: base,
            count: Int(bitPattern: _userLength.underlying.rawValue)
        )
        return try unsafe body(buffer)
    }
}

// MARK: - Protection

extension Memory.Map {
    /// Changes the memory protection of the mapped region.
    public mutating func protect(_ newAccess: Access) throws(Memory.Error) {
        try newAccess.validate()

        guard let base = mappingBaseAddress else {
            throw .unmapped
        }

        do throws(Self.Error) {
            try Self.protect(
                addr: base,
                length: mappingLength,
                protection: newAccess.kernelProtection
            )
            access = newAccess
        } catch {
            throw Memory.Error(from: error)
        }
    }
}

// MARK: - Synchronization

extension Memory.Map {
    /// Synchronizes the mapped region to disk.
    public func sync(async: Bool = false) throws(Memory.Error) {
        guard let base = mappingBaseAddress else {
            throw .unmapped
        }

        do throws(Self.Error) {
            #if os(Windows)
                try unsafe Self.sync(addr: base, length: mappingLength)
            #else
                let flags: Memory.Map.Sync.Options = async ? .async : .sync
                try Self.sync(addr: base, length: mappingLength, flags: flags)
            #endif
        } catch {
            throw Memory.Error(from: error)
        }
    }

    /// Provides a hint about expected access patterns.
    public func advise(_ advice: Memory.Map.Advice) {
        guard let base = mappingBaseAddress else { return }
        Self.advise(addr: base, length: mappingLength, advice: advice)
    }
}

// MARK: - Computed Properties (formerly in Memory.Map.swift L3)

extension Memory.Map {
    /// The base address of the actual OS mapping (granularity-aligned).
    var mappingBaseAddress: Memory.Address? { _region?.base }

    /// The length of the actual OS mapping.
    var mappingLength: Memory.Address.Count { _region?.length ?? .zero }

    /// The base address for user access (adjusted for offset delta).
    public var baseAddress: UnsafeRawPointer? {
        guard let base = mappingBaseAddress else { return nil }
        return unsafe base.pointer.advanced(by: Int(bitPattern: _offsetDelta.underlying.rawValue))
    }

    /// Mutable base address (only valid if access includes write).
    public var mutableBaseAddress: UnsafeMutableRawPointer? {
        guard access.allows.write, let base = mappingBaseAddress else { return nil }
        return unsafe base.mutablePointer.advanced(
            by: Int(bitPattern: _offsetDelta.underlying.rawValue)
        )
    }

    /// The length of the mapped region visible to the user.
    public var length: Memory.Address.Count { _userLength }

    /// The past-the-end index for bounds checking.
    public var endIndex: Index {
        Index(Ordinal(_userLength.underlying.rawValue))
    }

    /// Whether the mapping is still valid.
    public var isMapped: Bool { _region != nil }
}

// MARK: - Address Space Types

extension Memory.Map {
    /// Absolute byte index within a memory mapping.
    public typealias Index = Tagged<Memory.Map, Ordinal>

    /// Relative byte offset within a memory mapping.
    public typealias Offset = Index.Offset
}

// MARK: - Debug Description

extension Memory.Map {
    /// A textual representation for debugging.
    public var debugDescription: Swift.String {
        let status = isMapped ? "mapped" : "unmapped"
        return
            "Map(\(status), length: \(_userLength), access: \(access), sharing: \(sharing), safety: \(safety))"
    }
}
