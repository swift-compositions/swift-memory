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

// MARK: - File-backed Initialization (POSIX)

#if !os(Windows)
    extension Memory.Map {
        /// Creates a memory-mapped region from a file descriptor.
        ///
        /// - Parameters:
        ///   - fileDescriptor: The POSIX file descriptor to map.
        ///   - range: The range to map (offset will be aligned to allocation granularity).
        ///   - access: The access mode (default: `.read`).
        ///   - sharing: The sharing mode (default: `.shared`).
        ///   - safety: The safety mode (defaults based on access).
        /// - Throws: `Memory.Error` if mapping fails.
        public init(
            fileDescriptor: borrowing Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(Memory.Error) {
            try access.validate()

            let effectiveSafety = safety ?? (access.allows.write ? .default.write : .default.read)

            let userLen: Kernel.File.Size
            switch range {
            case .bytes(_, let length):
                userLen = length

            case .whole:
                let fileStats: Kernel.File.Stats
                do throws(Kernel.File.Stats.Error) {
                    fileStats = try Kernel.File.Stats.get(descriptor: fileDescriptor)
                } catch {
                    throw .stat(error)
                }
                userLen = fileStats.size
                guard userLen.isPositive else {
                    throw .size
                }
            }

            let requestedOffset = range.offset
            let alignedOffset = Memory.Allocation.align.down(requestedOffset)
            let delta = Kernel.File.Size(requestedOffset - alignedOffset)
            let totalLength = userLen + delta
            let mappingLen = System.Page.align.up(totalLength)

            // Cross-domain conversion: file-domain Kernel.File.Size →
            // memory-domain Memory.Address.Count at the file→memory boundary.
            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let baseAddress: Memory.Address
            do throws(Self.Error) {
                baseAddress = try Self.map(
                    length: mappingLenCount,
                    protection: access.kernelProtection,
                    flags: sharing.kernelOptions,
                    descriptor: fileDescriptor,
                    offset: alignedOffset
                )
            } catch {
                throw Memory.Error(from: error)
            }

            let region = Self.Region(base: baseAddress, length: mappingLenCount)

            let lockToken: Memory.Lock.Token?
            if case .coordinated(let kind, let scope) = effectiveSafety {
                let lockRange = Self.computeLockRange(
                    scope: scope,
                    alignedOffset: alignedOffset,
                    mappingLength: mappingLen
                )
                do throws(Kernel.Lock.Error) {
                    lockToken = try Memory.Lock.Token.acquire(
                        descriptor: fileDescriptor,
                        range: lockRange,
                        kind: kind
                    )
                } catch {
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                    throw .fileLock(error)
                }
            } else {
                lockToken = nil
            }

            self.init(
                region: region,
                offsetDelta: Memory.Address.Count(UInt(delta.underlying)),
                userLength: Memory.Address.Count(UInt(userLen.underlying)),
                access: access,
                sharing: sharing,
                safety: effectiveSafety,
                lockToken: lockToken,
                unmap: { region in
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                }
            )
        }

        /// Creates a memory-mapped region from a file descriptor.
        ///
        /// Static factory for API parity with Windows.
        public static func open(
            fileDescriptor: borrowing Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(Memory.Error) -> Self {
            try Self(
                fileDescriptor: fileDescriptor,
                range: range,
                access: access,
                sharing: sharing,
                safety: safety
            )
        }
    }
#endif

// MARK: - Lock Range Computation (Shared)

extension Memory.Map {
    /// Computes the lock range based on scope.
    static func computeLockRange(
        scope: Safety.Scope,
        alignedOffset: Kernel.File.Offset,
        mappingLength: Kernel.File.Size
    ) -> Kernel.Lock.Range {
        switch scope {
        case .file:
            return .file

        case .mapped:
            return Kernel.Lock.Range(
                forMappingAt: alignedOffset,
                length: mappingLength,
                granularity: Memory.Allocation.system
            )
        }
    }
}

// MARK: - File-backed Initialization (Windows)

#if os(Windows)
    extension Memory.Map {
        public static func open(
            fileHandle: borrowing Kernel.Descriptor,
            range: Range,
            access: Access = .read,
            sharing: Sharing = .shared,
            safety: Safety? = nil
        ) throws(Memory.Error) -> Self {
            try access.validate()

            let effectiveSafety = safety ?? (access.allows.write ? .default.write : .default.read)

            let userLen: Kernel.File.Size
            switch range {
            case .bytes(_, let length):
                userLen = length

            case .whole:
                let fileStats: Kernel.File.Stats
                do throws(Kernel.File.Stats.Error) {
                    fileStats = try Kernel.File.Stats.get(descriptor: fileHandle)
                } catch {
                    throw .stat(error)
                }
                userLen = fileStats.size
                guard userLen.isPositive else {
                    throw .size
                }
            }

            let requestedOffset = range.offset
            let alignedOffset = Memory.Allocation.align.down(requestedOffset)
            let delta = Kernel.File.Size(requestedOffset - alignedOffset)
            let totalLength = userLen + delta
            let mappingLen = System.Page.align.up(totalLength)

            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let region: Memory.Map.Region
            do throws(Self.Error) {
                region = try Self.File.map(
                    descriptor: fileHandle,
                    offset: alignedOffset,
                    length: mappingLenCount,
                    protection: access.kernelProtection,
                    copyOnWrite: sharing == .private
                )
            } catch {
                throw Memory.Error(from: error)
            }

            let lockToken: Memory.Lock.Token? = nil  // Windows lock acquisition deferred

            return Self(
                region: region,
                offsetDelta: Memory.Address.Count(UInt(delta.underlying)),
                userLength: Memory.Address.Count(UInt(userLen.underlying)),
                access: access,
                sharing: sharing,
                safety: effectiveSafety,
                lockToken: lockToken,
                unmap: { region in
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                }
            )
        }
    }
#endif

// MARK: - Anonymous Mapping (POSIX)

#if !os(Windows)
    extension Memory.Map {
        /// Creates an anonymous memory mapping (not backed by a file).
        public init(
            anonymousLength length: Kernel.File.Size,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(Memory.Error) {
            try access.validate()

            let mappingLen = System.Page.align.up(length)
            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let region: Memory.Map.Region
            do throws(Self.Error) {
                region = try Self.Anonymous.map(
                    length: mappingLenCount,
                    protection: access.kernelProtection,
                    shared: sharing == .shared
                )
            } catch {
                throw Memory.Error(from: error)
            }

            self.init(
                region: region,
                offsetDelta: .zero,
                userLength: Memory.Address.Count(UInt(length.underlying)),
                access: access,
                sharing: sharing,
                safety: .unchecked,
                lockToken: nil,
                unmap: { region in
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                }
            )
        }

        /// Static factory for anonymous mapping (API parity with Windows).
        public static func anonymous(
            length: Kernel.File.Size,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(Memory.Error) -> Self {
            try Self(anonymousLength: length, access: access, sharing: sharing)
        }
    }
#endif

// MARK: - Anonymous Mapping (Windows)

#if os(Windows)
    extension Memory.Map {
        public static func anonymous(
            length: Kernel.File.Size,
            access: Access = [.read, .write],
            sharing: Sharing = .private
        ) throws(Memory.Error) -> Self {
            try access.validate()

            let mappingLen = System.Page.align.up(length)
            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let region: Memory.Map.Region
            do throws(Self.Error) {
                region = try Self.Anonymous.map(
                    length: mappingLenCount,
                    protection: access.kernelProtection
                )
            } catch {
                throw Memory.Error(from: error)
            }

            return Self(
                region: region,
                offsetDelta: .zero,
                userLength: Memory.Address.Count(UInt(length.underlying)),
                access: access,
                sharing: sharing,
                safety: .unchecked,
                lockToken: nil,
                unmap: { region in
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                }
            )
        }
    }
#endif

// MARK: - Special Offset Mapping (Linux)

#if os(Linux)
    extension Memory.Map {
        /// Creates a memory-mapped region from a file descriptor with a specific mmap offset.
        ///
        /// Used for special mappings like io_uring ring buffers.
        public init(
            fileDescriptor: borrowing Kernel.Descriptor,
            mmapOffset: Kernel.File.Offset,
            length: Kernel.File.Size,
            access: Access = [.read, .write],
            sharing: Sharing = .shared
        ) throws(Memory.Error) {
            try access.validate()

            let mappingLen = System.Page.align.up(length)
            let mappingLenCount = Memory.Address.Count(UInt(mappingLen.underlying))

            let baseAddress: Memory.Address
            do throws(Self.Error) {
                baseAddress = try Self.map(
                    length: mappingLenCount,
                    protection: access.kernelProtection,
                    flags: sharing.kernelOptions,
                    descriptor: fileDescriptor,
                    offset: mmapOffset
                )
            } catch {
                throw Memory.Error(from: error)
            }

            let region = Self.Region(base: baseAddress, length: mappingLenCount)

            self.init(
                region: region,
                offsetDelta: .zero,
                userLength: Memory.Address.Count(UInt(length.underlying)),
                access: access,
                sharing: sharing,
                safety: .unchecked,
                lockToken: nil,
                unmap: { region in
                    do throws(Self.Error) {
                        try Self.unmap(region)
                    } catch {}
                }
            )
        }
    }
#endif
