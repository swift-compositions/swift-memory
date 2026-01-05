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
import StandardsTestSupport
import Testing

@testable import Memory

extension Memory.Shared {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Shared.Test.Unit {
    // MARK: - Mode Tests

    @Test("mode read")
    func modeRead() {
        let mode = Memory.Shared.Mode.read
        let access = mode.access
        #expect(access == .read)
    }

    @Test("mode from array literal")
    func modeFromArrayLiteral() {
        let mode: Memory.Shared.Mode = [.read, .write]
        let access = mode.access
        #expect(access == [.read, .write])
    }

    @Test("mode with create option")
    func modeCreate() {
        let mode = Memory.Shared.Mode(access: [.read, .write], options: .create)
        let access = mode.access
        let options = mode.options
        #expect(access == [.read, .write])
        #expect(options.contains(.create))
    }

    @Test("mode create exclusive")
    func modeCreateExclusive() {
        let mode = Memory.Shared.Mode.create.exclusive
        let access = mode.access
        let options = mode.options
        #expect(access == [.read, .write])
        #expect(options.contains(.create))
        #expect(options.contains(.exclusive))
    }

    @Test("mode create truncate")
    func modeCreateTruncate() {
        let mode = Memory.Shared.Mode.create.truncate
        let access = mode.access
        let options = mode.options
        #expect(access == [.read, .write])
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
    }

    @Test("mode is equatable")
    func modeIsEquatable() {
        let a = Memory.Shared.Mode.read
        let b = Memory.Shared.Mode.read
        let c: Memory.Shared.Mode = [.read, .write]

        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - POSIX Shared Memory Tests

    #if os(macOS) || os(Linux)
    @Test("open and unlink shared memory")
    func openAndUnlinkSharedMemory() throws {
        let name = "/swift-memory-test-\(UInt32.random(in: 0..<UInt32.max))"
        defer { try? Memory.Shared.unlink(name: name) }

        let fd = try Memory.Shared.open(name: name, mode: .create.exclusive)
        #expect(fd.isValid)
    }

    @Test("exclusive create fails if exists")
    func exclusiveCreateFailsIfExists() throws {
        let name = "/swift-memory-test-excl-\(UInt32.random(in: 0..<UInt32.max))"
        defer { try? Memory.Shared.unlink(name: name) }

        // Create first time - may fail on some systems due to sandbox restrictions
        let fd1: Kernel.File.Descriptor
        do {
            fd1 = try Memory.Shared.open(name: name, mode: .create.exclusive)
        } catch {
            // Shared memory may not be available on this system
            return
        }

        #expect(fd1.isValid)

        // Second create should fail
        #expect(throws: Memory.Error.self) {
            _ = try Memory.Shared.open(name: name, mode: .create.exclusive)
        }
    }

    @Test("open existing shared memory")
    func openExistingSharedMemory() throws {
        let name = "/swift-memory-test-open-\(UInt32.random(in: 0..<UInt32.max))"
        defer { try? Memory.Shared.unlink(name: name) }

        // Create - may fail on some systems due to sandbox restrictions
        do {
            _ = try Memory.Shared.open(name: name, mode: .create.exclusive)
        } catch {
            return
        }

        // Open existing (read-write without create)
        let fd2 = try Memory.Shared.open(name: name, mode: [.read, .write])
        #expect(fd2.isValid)
    }

    @Test("unlink removes shared memory")
    func unlinkRemovesSharedMemory() throws {
        let name = "/swift-memory-test-unlink-\(UInt32.random(in: 0..<UInt32.max))"

        // Create - may fail on some systems due to sandbox restrictions
        let fd: Kernel.File.Descriptor
        do {
            fd = try Memory.Shared.open(name: name, mode: .create.exclusive)
        } catch {
            return
        }

        #expect(fd.isValid)

        try Memory.Shared.unlink(name: name)

        // Opening after unlink should fail
        #expect(throws: Memory.Error.self) {
            _ = try Memory.Shared.open(name: name, mode: .read)
        }
    }
    #endif

    // MARK: - Windows Shared Memory Tests

    #if os(Windows)
    @Test("open shared memory with size")
    func openSharedMemoryWithSize() throws {
        let name = "Local\\swift-memory-test-\(UInt32.random(in: 0..<UInt32.max))"

        let shm = try Memory.Shared.open(
            name: name,
            size: 4096,
            mode: .create.exclusive
        )
        defer { try? Memory.Shared.close(shm) }

        #expect(shm.isValid)
    }

    @Test("close shared memory")
    func closeSharedMemory() throws {
        let name = "Local\\swift-memory-test-close-\(UInt32.random(in: 0..<UInt32.max))"

        let shm = try Memory.Shared.open(
            name: name,
            size: 4096,
            mode: .create.exclusive
        )

        try Memory.Shared.close(shm)
        // Should not throw
    }

    @Test("open existing shared memory (Windows)")
    func openExistingSharedMemoryWindows() throws {
        let name = "Local\\swift-memory-test-open-\(UInt32.random(in: 0..<UInt32.max))"

        // Create with size
        let shm1 = try Memory.Shared.open(
            name: name,
            size: 4096,
            mode: .create.exclusive
        )

        // Open existing (without size, uses open(name:mode:))
        let shm2 = try Memory.Shared.open(name: name, mode: [.read, .write])

        // Both should be valid
        #expect(shm1.isValid)
        #expect(shm2.isValid)

        try Memory.Shared.close(shm2)
        try Memory.Shared.close(shm1)
    }
    #endif
}

// MARK: - Edge Case Tests

extension Memory.Shared.Test.EdgeCase {
    #if os(macOS) || os(Linux)
    @Test("unlink non-existent fails")
    func unlinkNonExistentFails() {
        let name = "/swift-memory-test-nonexistent-\(UInt32.random(in: 0..<UInt32.max))"

        #expect(throws: Memory.Error.self) {
            try Memory.Shared.unlink(name: name)
        }
    }

    @Test("open non-existent read-only fails")
    func openNonExistentReadOnlyFails() {
        let name = "/swift-memory-test-nonexistent-\(UInt32.random(in: 0..<UInt32.max))"

        #expect(throws: Memory.Error.self) {
            _ = try Memory.Shared.open(name: name, mode: .read)
        }
    }
    #endif

    #if os(Windows)
    @Test("open non-existent fails (Windows)")
    func openNonExistentFailsWindows() {
        let name = "Local\\swift-memory-test-nonexistent-\(UInt32.random(in: 0..<UInt32.max))"

        #expect(throws: Memory.Error.self) {
            _ = try Memory.Shared.open(name: name, mode: .read)
        }
    }
    #endif
}

// MARK: - Performance Tests

extension Memory.Shared.Test.Performance {
    // Shared memory operations are system calls, no meaningful perf test
}
