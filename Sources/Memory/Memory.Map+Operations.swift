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

// MARK: - Consuming Operations

extension Memory.Map {
    /// Unmaps the region and releases all resources.
    ///
    /// This is the canonical way to release a mapping. After calling `unmap()`,
    /// the region cannot be used.
    ///
    /// - Note: This is a consuming function - the region is moved and destroyed.
    public consuming func unmap() {
        guard let base = mappingBaseAddress else { return }

        // Release lock token first
        lockToken?.release()

        // Unmap the region
        #if os(Windows)
            if let handle = mappingHandle {
                try? Kernel.Memory.Map.unmap(Kernel.Memory.Map.WindowsMapping(baseAddress: base, mappingHandle: handle))
            }
            mappingHandle = nil
        #else
            try? Kernel.Memory.Map.unmap(addr: base, length: Kernel.File.Size(mappingLength))
        #endif

        // Mark as unmapped so deinit becomes a no-op
        mappingBaseAddress = nil
    }
}

// MARK: - Remap

#if !os(Windows)
    extension Memory.Map {
        /// Remaps the region to a new range.
        ///
        /// This is a consuming operation that:
        /// 1. Unmaps the current region
        /// 2. Creates a new mapping with the specified range
        /// 3. Returns the new region
        ///
        /// - Parameters:
        ///   - fileDescriptor: The file descriptor to map.
        ///   - range: The new range to map.
        /// - Returns: A new `Region` with the specified range.
        /// - Throws: `Memory.Error` if remapping fails.
        ///
        /// - Note: On Linux, this may use `mremap()` for efficiency when possible.
        public consuming func remap(
            fileDescriptor: Kernel.Descriptor,
            range: Range
        ) throws(Memory.Error) -> Self {
            // Capture values before consuming self
            let capturedAccess = access
            let capturedSharing = sharing
            let capturedSafety = safety

            // For now, we do unmap + map
            // Linux optimization with mremap could be added later
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
        /// Remaps the region to a new range.
        ///
        /// This is a consuming operation that:
        /// 1. Unmaps the current region
        /// 2. Creates a new mapping with the specified range
        /// 3. Returns the new region
        ///
        /// - Parameters:
        ///   - fileHandle: The file handle to map.
        ///   - range: The new range to map.
        /// - Returns: A new `Region` with the specified range.
        /// - Throws: `Memory.Error` if remapping fails.
        public consuming func remap(
            fileHandle: Kernel.Descriptor,
            range: Range
        ) throws(Memory.Error) -> Self {
            // Capture values before consuming self
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
    ///
    /// - Parameter index: The byte index (0-based).
    /// - Returns: The byte value at that index.
    /// - Precondition: `index` must be in bounds.
    public subscript(index: Int) -> UInt8 {
        precondition(index >= 0 && index < userLength, "Index out of bounds")
        guard let base = baseAddress else {
            preconditionFailure("Mapping is not valid")
        }
        return base.load(fromByteOffset: index, as: UInt8.self)
    }

    /// Provides read-only access to the mapped bytes.
    ///
    /// - Parameter body: A closure that receives an `UnsafeRawBufferPointer`.
    /// - Returns: The result of the closure.
    /// - Throws: Rethrows any error from the closure.
    public func withUnsafeBytes<T>(
        _ body: (UnsafeRawBufferPointer) throws -> T
    ) rethrows -> T {
        guard let base = baseAddress else {
            preconditionFailure("Mapping is not valid")
        }
        let buffer = UnsafeRawBufferPointer(start: base, count: userLength)
        return try body(buffer)
    }

    /// Provides mutable access to the mapped bytes.
    ///
    /// - Parameter body: A closure that receives an `UnsafeMutableRawBufferPointer`.
    /// - Returns: The result of the closure.
    /// - Throws: Rethrows any error from the closure.
    /// - Precondition: The mapping must have write access.
    public func withUnsafeMutableBytes<T>(
        _ body: (UnsafeMutableRawBufferPointer) throws -> T
    ) rethrows -> T {
        precondition(access.allows.write, "Mapping does not allow writes")
        guard let base = mutableBaseAddress else {
            preconditionFailure("Mapping is not valid")
        }
        let buffer = UnsafeMutableRawBufferPointer(start: base, count: userLength)
        return try body(buffer)
    }

    /// Writes a byte at the given index.
    ///
    /// - Parameters:
    ///   - value: The byte value to write.
    ///   - index: The byte index (0-based).
    /// - Precondition: The mapping must have write access.
    /// - Precondition: `index` must be in bounds.
    public func write(_ value: UInt8, at index: Int) {
        precondition(access.allows.write, "Mapping does not allow writes")
        precondition(index >= 0 && index < userLength, "Index out of bounds")
        guard let base = mutableBaseAddress else {
            preconditionFailure("Mapping is not valid")
        }
        base.storeBytes(of: value, toByteOffset: index, as: UInt8.self)
    }
}

// MARK: - Protection

extension Memory.Map {
    /// Changes the memory protection of the mapped region.
    ///
    /// This allows runtime modification of access permissions, for example:
    /// - Making a region writable after initial read-only mapping
    /// - Removing write access after initialization is complete
    ///
    /// - Parameter newAccess: The new access permissions.
    /// - Throws: `Memory.Error` if protection change fails.
    ///
    /// - Note: The new access must be compatible with the original file
    ///   descriptor's open mode. You cannot add write access to a region
    ///   mapped from a read-only file descriptor.
    public mutating func protect(_ newAccess: Access) throws(Memory.Error) {
        try newAccess.validate()

        guard let base = mappingBaseAddress else {
            throw .unmapped
        }

        do throws(Kernel.Memory.Map.Error) {
            try Kernel.Memory.Map.protect(
                addr: base,
                length: Kernel.File.Size(mappingLength),
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
    ///
    /// - Parameter async: If `true`, returns immediately and syncs asynchronously.
    ///                    (Ignored on Windows, which only has synchronous flush.)
    /// - Throws: `Memory.Error` if sync fails.
    public func sync(async: Bool = false) throws(Memory.Error) {
        guard let base = mappingBaseAddress else {
            throw .unmapped
        }

        do throws(Kernel.Memory.Map.Error) {
            #if os(Windows)
                try Kernel.Memory.Map.sync(addr: base, length: Kernel.File.Size(mappingLength))
            #else
                let flags: Kernel.Memory.Map.Sync.Flags = async ? .async : .sync
                try Kernel.Memory.Map.sync(addr: base, length: Kernel.File.Size(mappingLength), flags: flags)
            #endif
        } catch {
            throw Memory.Error(from: error)
        }
    }

    /// Provides a hint about expected access patterns.
    ///
    /// This is advisory - the system may ignore the hint.
    ///
    /// - Parameter advice: The access pattern hint.
    public func advise(_ advice: Kernel.Memory.Map.Advice) {
        guard let base = mappingBaseAddress else { return }
        Kernel.Memory.Map.advise(addr: base, length: Kernel.File.Size(mappingLength), advice: advice)
    }
}

// MARK: - Debug Description

extension Memory.Map {
    /// A textual representation for debugging.
    public var debugDescription: String {
        let status = isMapped ? "mapped" : "unmapped"
        return "Region(\(status), length: \(userLength), access: \(access), sharing: \(sharing), safety: \(safety))"
    }
}
