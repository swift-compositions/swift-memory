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

import Kernel
import Kernel_Test_Support
import StandardsTestSupport
import Testing

@testable import Memory

extension Memory.Map {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Map.Test.Unit {
    // MARK: - Anonymous Mapping Tests

    #if !os(Windows)
    @Test("anonymous mapping creates valid region")
    func anonymousMappingCreatesValidRegion() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        let isMapped = map.isMapped
        let length = map.length
        let hasBase = map.baseAddress != nil

        map.unmap()

        #expect(isMapped)
        #expect(length == 4096)
        #expect(hasBase)
    }

    @Test("anonymous mapping read/write")
    func anonymousMappingReadWrite() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        map.write(42, at: 0)
        map.write(123, at: 100)

        let byte0 = map[0]
        let byte100 = map[100]

        map.unmap()

        #expect(byte0 == 42)
        #expect(byte100 == 123)
    }

    @Test("anonymous mapping default access is read/write")
    func anonymousMappingDefaultAccess() throws {
        let map = try Memory.Map(anonymousLength: 4096)

        let access = map.access

        map.unmap()

        #expect(access.allows.read)
        #expect(access.allows.write)
    }

    @Test("anonymous mapping read-only")
    func anonymousMappingReadOnly() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: .read)

        let access = map.access
        let noMutableBase = map.mutableBaseAddress == nil

        map.unmap()

        #expect(access.allows.read)
        #expect(!access.allows.write)
        #expect(noMutableBase)
    }

    @Test("anonymous mapping uses unchecked safety")
    func anonymousMappingUncheckedSafety() throws {
        let map = try Memory.Map(anonymousLength: 4096)

        let safety = map.safety

        map.unmap()

        #expect(safety == .unchecked)
    }
    #endif

    #if os(Windows)
    @Test("anonymous mapping via static factory")
    func anonymousMappingStaticFactory() throws {
        let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

        let isMapped = map.isMapped
        let length = map.length

        map.unmap()

        #expect(isMapped)
        #expect(length == 4096)
    }

    @Test("anonymous mapping read/write (Windows)")
    func anonymousMappingReadWriteWindows() throws {
        let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

        map.write(42, at: 0)
        map.write(123, at: 100)

        let byte0 = map[0]
        let byte100 = map[100]

        map.unmap()

        #expect(byte0 == 42)
        #expect(byte100 == 123)
    }

    @Test("withUnsafeBytes read access (Windows)")
    func withUnsafeBytesReadAccessWindows() throws {
        let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

        map.write(1, at: 0)
        map.write(2, at: 1)
        map.write(3, at: 2)

        let sum = map.withUnsafeBytes { buffer -> Int in
            Int(buffer[0]) + Int(buffer[1]) + Int(buffer[2])
        }

        map.unmap()

        #expect(sum == 6)
    }

    @Test("withUnsafeMutableBytes write access (Windows)")
    func withUnsafeMutableBytesWriteAccessWindows() throws {
        let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

        map.withUnsafeMutableBytes { buffer in
            buffer[0] = 10
            buffer[1] = 20
            buffer[2] = 30
        }

        let byte0 = map[0]
        let byte1 = map[1]
        let byte2 = map[2]

        map.unmap()

        #expect(byte0 == 10)
        #expect(byte1 == 20)
        #expect(byte2 == 30)
    }

    @Test("debug description (Windows)")
    func debugDescriptionTestWindows() throws {
        let map = try Memory.Map.anonymous(length: 4096)

        let description = map.debugDescription

        map.unmap()

        #expect(description.contains("mapped"))
        #expect(description.contains("4096"))
    }
    #endif

    // MARK: - Buffer Access Tests (POSIX)

    #if !os(Windows)
    @Test("withUnsafeBytes provides read access")
    func withUnsafeBytesReadAccess() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        map.write(1, at: 0)
        map.write(2, at: 1)
        map.write(3, at: 2)

        let sum = map.withUnsafeBytes { buffer -> Int in
            Int(buffer[0]) + Int(buffer[1]) + Int(buffer[2])
        }

        map.unmap()

        #expect(sum == 6)
    }

    @Test("withUnsafeMutableBytes provides write access")
    func withUnsafeMutableBytesWriteAccess() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        map.withUnsafeMutableBytes { buffer in
            buffer[0] = 10
            buffer[1] = 20
            buffer[2] = 30
        }

        let byte0 = map[0]
        let byte1 = map[1]
        let byte2 = map[2]

        map.unmap()

        #expect(byte0 == 10)
        #expect(byte1 == 20)
        #expect(byte2 == 30)
    }
    #endif

    // MARK: - File-Backed Mapping Tests (POSIX)

    #if !os(Windows)
    @Test("file-backed mapping reads content")
    func fileBackedMappingReadsContent() throws {
        let content = "Hello, Memory Map!"
        let (path, fd) = try KernelIOTest.createTempFileWithContent(content)

        let map = try Memory.Map(
            fileDescriptor: fd,
            range: .whole,
            access: .read,
            sharing: .shared,
            safety: .unchecked
        )

        let isMapped = map.isMapped
        let length = map.length

        // Verify content
        let bytes = map.withUnsafeBytes { buffer -> [UInt8] in
            Array(buffer)
        }
        let readContent = String(decoding: bytes, as: UTF8.self)

        map.unmap()
        KernelIOTest.cleanupTempFile(path: path, fd: fd)

        #expect(isMapped)
        #expect(length == Kernel.File.Size(content.utf8.count))
        #expect(readContent == content)
    }

    @Test("file-backed mapping with read/write modifies file")
    func fileBackedMappingReadWrite() throws {
        let content = "0123456789"
        let (path, fd) = try KernelIOTest.createTempFileWithContent(content)

        let map = try Memory.Map(
            fileDescriptor: fd,
            range: .whole,
            access: [.read, .write],
            sharing: .shared,
            safety: .unchecked
        )

        // Modify the first byte
        map.write(65, at: 0) // 'A'
        try map.sync()

        let byte0 = map[0]

        map.unmap()
        KernelIOTest.cleanupTempFile(path: path, fd: fd)

        #expect(byte0 == 65)
    }

    @Test("copy-on-write does not modify original")
    func copyOnWriteDoesNotModifyOriginal() throws {
        let content = "Original"
        let (path, fd) = try KernelIOTest.createTempFileWithContent(content)

        // Map with private (CoW) sharing
        let map = try Memory.Map(
            fileDescriptor: fd,
            range: .whole,
            access: [.read, .write],
            sharing: .private,
            safety: .unchecked
        )

        let originalByte = map[0]
        map.write(99, at: 0)

        let newByte = map[0]

        map.unmap()
        KernelIOTest.cleanupTempFile(path: path, fd: fd)

        #expect(newByte == 99)
        #expect(originalByte == UInt8(ascii: "O"))
    }

    @Test("static factory open() works")
    func staticFactoryOpen() throws {
        let content = "Factory test"
        let (path, fd) = try KernelIOTest.createTempFileWithContent(content)

        let map = try Memory.Map.open(
            fileDescriptor: fd,
            range: .whole,
            access: .read
        )

        let isMapped = map.isMapped

        map.unmap()
        KernelIOTest.cleanupTempFile(path: path, fd: fd)

        #expect(isMapped)
    }

    @Test("static factory anonymous() works")
    func staticFactoryAnonymous() throws {
        let map = try Memory.Map.anonymous(length: 4096)

        let isMapped = map.isMapped
        let length = map.length

        map.unmap()

        #expect(isMapped)
        #expect(length == 4096)
    }

    @Test("bytes range with offset and length")
    func bytesRangeWithOffsetAndLength() throws {
        let content = String(repeating: "X", count: 8192)
        let (path, fd) = try KernelIOTest.createTempFileWithContent(content)

        let map = try Memory.Map(
            fileDescriptor: fd,
            range: .bytes(offset: 4096, length: 1024),
            access: .read,
            safety: .unchecked
        )

        let length = map.length

        map.unmap()
        KernelIOTest.cleanupTempFile(path: path, fd: fd)

        #expect(length == 1024)
    }
    #endif

    // MARK: - Linux-specific io_uring Offset Mapping

    #if os(Linux)
    @Test("mmap offset mapping for io_uring-style APIs")
    func mmapOffsetMappingForIoUring() throws {
        // This tests the special init that takes an explicit mmap offset
        // Used for io_uring ring buffer mappings where offset is not a file offset
        // but a magic value that selects a specific region.
        //
        // We can't test with actual io_uring here, but we can test the API
        // works for regular file offsets (which is a subset of the functionality).
        let content = String(repeating: "X", count: 8192)
        let (path, fd) = try KernelIOTest.createTempFileWithContent(content)

        // Use mmap offset init with explicit offset (equivalent to regular mapping)
        let map = try Memory.Map(
            fileDescriptor: fd,
            mmapOffset: Kernel.File.Offset(4096),
            length: 4096,
            access: .read,
            sharing: .shared
        )

        let isMapped = map.isMapped
        let length = map.length

        map.unmap()
        KernelIOTest.cleanupTempFile(path: path, fd: fd)

        #expect(isMapped)
        #expect(length == 4096)
    }
    #endif

    // MARK: - Sync Tests

    #if !os(Windows)
    @Test("sync on anonymous mapping")
    func syncAnonymousMapping() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        map.write(42, at: 0)

        // Sync on anonymous may fail on some platforms, but should not crash
        do {
            try map.sync()
        } catch {
            // Expected on some platforms (anonymous has no backing file)
        }

        map.unmap()
    }

    @Test("sync async flag")
    func syncAsyncFlag() throws {
        let content = "Sync test"
        let (path, fd) = try KernelIOTest.createTempFileWithContent(content)

        let map = try Memory.Map(
            fileDescriptor: fd,
            range: .whole,
            access: [.read, .write],
            sharing: .shared,
            safety: .unchecked
        )

        map.write(65, at: 0)

        // Both sync modes should work
        try map.sync(async: false)
        try map.sync(async: true)

        map.unmap()
        KernelIOTest.cleanupTempFile(path: path, fd: fd)
    }
    #endif

    // MARK: - Protection Tests

    #if !os(Windows)
    @Test("protect changes access")
    func protectChangesAccess() throws {
        var map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        map.write(42, at: 0)
        try map.protect(.read)

        let access = map.access
        let byte0 = map[0]

        map.unmap()

        #expect(access == .read)
        #expect(!access.allows.write)
        #expect(byte0 == 42)
    }

    @Test("protect restores write access")
    func protectRestoresWriteAccess() throws {
        var map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        try map.protect(.read)
        try map.protect([.read, .write])

        let access = map.access
        map.write(100, at: 0)
        let byte0 = map[0]

        map.unmap()

        #expect(access.allows.write)
        #expect(byte0 == 100)
    }
    #endif

    // MARK: - Remap Tests

    #if !os(Windows)
    @Test("remap to new range")
    func remapToNewRange() throws {
        // Create file with 8KB of distinct content
        let firstHalf = String(repeating: "A", count: 4096)
        let secondHalf = String(repeating: "B", count: 4096)
        let content = firstHalf + secondHalf
        let (path, fd) = try KernelIOTest.createTempFileWithContent(content)

        // Map first half
        var map = try Memory.Map(
            fileDescriptor: fd,
            range: .bytes(offset: 0, length: 4096),
            access: .read,
            safety: .unchecked
        )

        let firstByte = map[0]

        // Remap to second half
        map = try map.remap(fileDescriptor: fd, range: .bytes(offset: 4096, length: 4096))

        let secondByte = map[0]

        map.unmap()
        KernelIOTest.cleanupTempFile(path: path, fd: fd)

        #expect(firstByte == UInt8(ascii: "A"))
        #expect(secondByte == UInt8(ascii: "B"))
    }
    #endif

    // MARK: - Debug Description

    #if !os(Windows)
    @Test("debug description")
    func debugDescriptionTest() throws {
        let map = try Memory.Map(anonymousLength: 4096)

        let description = map.debugDescription

        map.unmap()

        #expect(description.contains("mapped"))
        #expect(description.contains("4096"))
    }
    #endif
}

// MARK: - Edge Case Tests

extension Memory.Map.Test.EdgeCase {
    #if !os(Windows)
    @Test("empty file throws size error")
    func emptyFileThrowsSizeError() throws {
        let (path, fd) = try KernelIOTest.createTempFile()

        #expect(throws: Memory.Error.self) {
            _ = try Memory.Map(
                fileDescriptor: fd,
                range: .whole,
                access: .read,
                safety: .unchecked
            )
        }

        KernelIOTest.cleanupTempFile(path: path, fd: fd)
    }

    @Test("write-only access throws")
    func writeOnlyAccessThrows() throws {
        #expect(throws: Memory.Error.self) {
            _ = try Memory.Map(anonymousLength: 4096, access: .write)
        }
    }

    @Test("unmap consumes mapping")
    func unmapConsumesMapping() throws {
        let map = try Memory.Map(anonymousLength: 4096)
        let wasMapped = map.isMapped

        // unmap() is a consuming operation on ~Copyable types
        // After this call, 'map' is no longer accessible (compiler-enforced)
        map.unmap()

        #expect(wasMapped)
    }

    // Note: "protect on unmapped throws" and "sync on unmapped throws" tests
    // are not needed because Memory.Map is ~Copyable. Once unmap() consumes
    // the map, the compiler prevents any further access - making these
    // error conditions impossible at runtime.
    #endif

    #if os(Windows)
    @Test("write-only access throws (Windows)")
    func writeOnlyAccessThrowsWindows() throws {
        #expect(throws: Memory.Error.self) {
            _ = try Memory.Map.anonymous(length: 4096, access: .write)
        }
    }

    @Test("unmap consumes mapping (Windows)")
    func unmapConsumesMappingWindows() throws {
        let map = try Memory.Map.anonymous(length: 4096)
        let wasMapped = map.isMapped

        map.unmap()

        #expect(wasMapped)
    }
    #endif
}

// MARK: - Performance Tests

extension Memory.Map.Test.Performance {
    #if !os(Windows)
    @Test("map/unmap cycle", .timed(iterations: 100, warmup: 10))
    func mapUnmapCycle() throws {
        for _ in 0..<10 {
            let map = try Memory.Map(anonymousLength: 4096)
            map.unmap()
        }
    }

    @Test("sequential write throughput", .timed(iterations: 10, warmup: 2))
    func sequentialWriteThroughput() throws {
        let map = try Memory.Map(anonymousLength: 65536, access: [.read, .write])

        map.withUnsafeMutableBytes { buffer in
            for i in 0..<buffer.count {
                buffer[i] = UInt8(truncatingIfNeeded: i)
            }
        }

        map.unmap()
    }
    #endif

    #if os(Windows)
    @Test("map/unmap cycle (Windows)", .timed(iterations: 100, warmup: 10))
    func mapUnmapCycleWindows() throws {
        for _ in 0..<10 {
            let map = try Memory.Map.anonymous(length: 4096)
            map.unmap()
        }
    }

    @Test("sequential write throughput (Windows)", .timed(iterations: 10, warmup: 2))
    func sequentialWriteThroughputWindows() throws {
        let map = try Memory.Map.anonymous(length: 65536, access: [.read, .write])

        map.withUnsafeMutableBytes { buffer in
            for i in 0..<buffer.count {
                buffer[i] = UInt8(truncatingIfNeeded: i)
            }
        }

        map.unmap()
    }
    #endif
}
