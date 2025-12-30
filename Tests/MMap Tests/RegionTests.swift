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

import Testing
import MMap

@Suite
struct RegionTests {

    // MARK: - Anonymous Mapping Tests

    @Test
    func anonymousMapping() throws {
        let region = try MMap.Region(anonymousLength: 4096)
        let length = region.length
        let isMapped = region.isMapped

        #expect(length == 4096)
        #expect(isMapped)

        region.unmap()
    }

    @Test
    func anonymousMappingReadWrite() throws {
        let region = try MMap.Region(
            anonymousLength: 4096,
            access: [.read, .write]
        )

        // Write and read back
        region.write(42, at: 0)
        region.write(123, at: 100)

        #expect(region[0] == 42)
        #expect(region[100] == 123)

        region.unmap()
    }

    @Test
    func anonymousMappingDefaultAccess() throws {
        // Default for anonymous should be [.read, .write]
        let region = try MMap.Region(anonymousLength: 4096)

        #expect(region.access.allowsRead)
        #expect(region.access.allowsWrite)

        region.unmap()
    }

    @Test
    func anonymousMappingReadOnly() throws {
        let region = try MMap.Region(
            anonymousLength: 4096,
            access: .read
        )

        #expect(region.access.allowsRead)
        #expect(!region.access.allowsWrite)
        #expect(region.mutableBaseAddress == nil)

        region.unmap()
    }

    // MARK: - Buffer Access Tests

    @Test
    func withUnsafeBytes() throws {
        let region = try MMap.Region(
            anonymousLength: 4096,
            access: [.read, .write]
        )

        // Write some data
        region.write(1, at: 0)
        region.write(2, at: 1)
        region.write(3, at: 2)

        // Read via buffer
        let sum = region.withUnsafeBytes { buffer -> Int in
            Int(buffer[0]) + Int(buffer[1]) + Int(buffer[2])
        }

        #expect(sum == 6)

        region.unmap()
    }

    @Test
    func withUnsafeMutableBytes() throws {
        let region = try MMap.Region(
            anonymousLength: 4096,
            access: [.read, .write]
        )

        // Write via mutable buffer
        region.withUnsafeMutableBytes { buffer in
            buffer[0] = 10
            buffer[1] = 20
            buffer[2] = 30
        }

        #expect(region[0] == 10)
        #expect(region[1] == 20)
        #expect(region[2] == 30)

        region.unmap()
    }

    // MARK: - Protection Tests

    @Test
    func protectChangeAccess() throws {
        var region = try MMap.Region(
            anonymousLength: 4096,
            access: [.read, .write]
        )

        // Write some data first
        region.write(42, at: 0)

        // Change to read-only
        try region.protect(.read)

        #expect(region.access == .read)
        #expect(!region.access.allowsWrite)
        #expect(region[0] == 42)  // Can still read

        // Change back to read-write
        try region.protect([.read, .write])

        #expect(region.access.allowsWrite)
        region.write(100, at: 0)
        #expect(region[0] == 100)

        region.unmap()
    }

    // MARK: - Convenience Re-export Tests

    @Test
    func pageSizeIsPositive() {
        #expect(MMap.pageSize > 0)
        // Common page sizes: 4096, 16384
        #expect(MMap.pageSize >= 4096)
    }

    @Test
    func allocationGranularityIsPositive() {
        #expect(MMap.allocationGranularity > 0)
        // Must be at least page size
        #expect(MMap.allocationGranularity >= MMap.pageSize)
    }

    // MARK: - Access Validation Tests

    @Test
    func accessValidation() throws {
        // Read-only is valid
        let readAccess: MMap.Region.Access = .read
        #expect(readAccess.allowsRead)
        #expect(!readAccess.allowsWrite)

        // Read-write is valid
        let rwAccess: MMap.Region.Access = [.read, .write]
        #expect(rwAccess.allowsRead)
        #expect(rwAccess.allowsWrite)
    }

    // MARK: - Sharing Tests

    @Test
    func sharingModes() throws {
        // Private (copy-on-write) - default for anonymous
        let privateRegion = try MMap.Region(
            anonymousLength: 4096,
            sharing: .private
        )
        #expect(privateRegion.sharing == .private)
        privateRegion.unmap()

        // Shared
        let sharedRegion = try MMap.Region(
            anonymousLength: 4096,
            sharing: .shared
        )
        #expect(sharedRegion.sharing == .shared)
        sharedRegion.unmap()
    }

    // MARK: - Sync Tests

    @Test
    func syncAnonymous() throws {
        let region = try MMap.Region(
            anonymousLength: 4096,
            access: [.read, .write]
        )

        region.write(42, at: 0)

        // Sync on anonymous memory may fail on some platforms (no backing file)
        // This is expected behavior - we just verify it doesn't crash
        do {
            try region.sync()
        } catch {
            // Expected on some platforms
        }

        region.unmap()
    }

    // MARK: - Safety Tests

    @Test
    func uncheckedSafety() throws {
        let region = try MMap.Region(
            anonymousLength: 4096,
            access: [.read, .write]
        )

        // Anonymous mappings always use .unchecked
        #expect(region.safety == .unchecked)

        region.unmap()
    }
}

// MARK: - Range Tests

@Suite
struct RangeTests {
    @Test
    func bytesRange() {
        let range = MMap.Region.Range.bytes(offset: 100, length: 500)
        #expect(range.offset == 100)
    }

    @Test
    func wholeFileRange() {
        let range = MMap.Region.Range.wholeFile
        #expect(range.offset == 0)
    }
}

// MARK: - Error Tests

@Suite
struct ErrorTests {
    @Test
    func errorDescriptions() {
        let errors: [MMap.Error] = [
            .unsupported,
            .invalidRange,
            .invalidAlignment,
            .invalidAccess,
            .permissionDenied,
            .outOfMemory,
            .fileTooSmall,
            .mappingSizeLimit,
            .unsupportedConfiguration,
            .invalidHandle,
            .unsupportedFileType,
            .alreadyUnmapped,
            .platform(code: 42, message: "test error")
        ]

        for error in errors {
            // Each error should have a non-empty description
            #expect(!error.description.isEmpty)
        }
    }
}
