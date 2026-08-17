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
import Testing

@testable import Memory

extension Memory.Shared {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension Memory.Shared.Test.Unit {
    // MARK: - Mode Tests

    @Test
    func `mode read`() {
        let mode = Memory.Shared.Mode.read
        let access = mode.access
        #expect(access == .read)
    }

    @Test
    func `mode from array literal`() {
        let mode: Memory.Shared.Mode = [.read, .write]
        let access = mode.access
        #expect(access == .readWrite)
    }

    @Test
    func `mode with create option`() {
        let mode = Memory.Shared.Mode(access: .readWrite, options: .create)
        let access = mode.access
        let options = mode.options
        #expect(access == .readWrite)
        #expect(options.contains(.create))
    }

    @Test
    func `mode create exclusive`() {
        let mode = Memory.Shared.Mode.create.exclusive
        let access = mode.access
        let options = mode.options
        #expect(access == .readWrite)
        #expect(options.contains(.create))
        #expect(options.contains(.exclusive))
    }

    @Test
    func `mode create truncate`() {
        let mode = Memory.Shared.Mode.create.truncate
        let access = mode.access
        let options = mode.options
        #expect(access == .readWrite)
        #expect(options.contains(.create))
        #expect(options.contains(.truncate))
    }

    @Test
    func `mode is equatable`() {
        let a = Memory.Shared.Mode.read
        let b = Memory.Shared.Mode.read
        let c: Memory.Shared.Mode = [.read, .write]

        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - POSIX Shared Memory Tests

    #if os(macOS) || os(Linux)
        @Test
        func `open and unlink shared memory`() throws {
            let name = "/swift-memory-test-\(UInt32.random(in: 0..<UInt32.max))"
            defer { try? Memory.Shared.unlink(name: name) }

            let fd = try Memory.Shared.open(name: name, mode: .create.exclusive)
            let isValid = fd.isValid
            #expect(isValid)
        }

        @Test
        func `exclusive create fails if exists`() throws {
            let name = "/swift-memory-test-excl-\(UInt32.random(in: 0..<UInt32.max))"
            defer { try? Memory.Shared.unlink(name: name) }

            // Create first time - may fail on some systems due to sandbox restrictions
            let fd1: Kernel.File.Descriptor
            do throws(Memory.Error) {
                fd1 = try Memory.Shared.open(name: name, mode: .create.exclusive)
            } catch {
                // Shared memory may not be available on this system
                return
            }

            let fd1IsValid = fd1.isValid
            #expect(fd1IsValid)

            // Second create should fail
            #expect(throws: Memory.Error.self) {
                _ = try Memory.Shared.open(name: name, mode: .create.exclusive)
            }
        }

        @Test
        func `open existing shared memory`() throws {
            let name = "/swift-memory-test-open-\(UInt32.random(in: 0..<UInt32.max))"
            defer { try? Memory.Shared.unlink(name: name) }

            // Create - may fail on some systems due to sandbox restrictions
            do throws(Memory.Error) {
                _ = try Memory.Shared.open(name: name, mode: .create.exclusive)
            } catch {
                return
            }

            // Open existing (read-write without create)
            let fd2 = try Memory.Shared.open(name: name, mode: [.read, .write])
            let fd2IsValid = fd2.isValid
            #expect(fd2IsValid)
        }

        @Test
        func `unlink removes shared memory`() throws {
            let name = "/swift-memory-test-unlink-\(UInt32.random(in: 0..<UInt32.max))"

            // Create - may fail on some systems due to sandbox restrictions
            let fd: Kernel.File.Descriptor
            do throws(Memory.Error) {
                fd = try Memory.Shared.open(name: name, mode: .create.exclusive)
            } catch {
                return
            }

            let fdIsValid = fd.isValid
            #expect(fdIsValid)

            try Memory.Shared.unlink(name: name)

            // Opening after unlink should fail
            #expect(throws: Memory.Error.self) {
                _ = try Memory.Shared.open(name: name, mode: .read)
            }
        }
    #endif

    // MARK: - Windows Shared Memory Tests

    #if os(Windows)
        @Test
        func `open shared memory with size`() throws {
            let name = "Local\\swift-memory-test-\(UInt32.random(in: 0..<UInt32.max))"

            let shm = try Memory.Shared.open(
                name: name,
                size: 4096,
                mode: .create.exclusive
            )
            // No `defer`: closing consumes the descriptor, and a noncopyable
            // value cannot be consumed from an escaping closure. Nothing
            // between here and the close can throw, and the descriptor's own
            // deinit closes the handle on any path that skips it.

            // Hoisted: `#expect` expands a property access through a generic
            // that requires Copyable, and Kernel.Descriptor is ~Copyable.
            let shmIsValid = shm.isValid
            #expect(shmIsValid)

            try Memory.Shared.close(shm)
        }

        @Test
        func `close shared memory`() throws {
            let name = "Local\\swift-memory-test-close-\(UInt32.random(in: 0..<UInt32.max))"

            let shm = try Memory.Shared.open(
                name: name,
                size: 4096,
                mode: .create.exclusive
            )

            try Memory.Shared.close(shm)
            // Should not throw
        }

        @Test
        func `open existing shared memory (Windows)`() throws {
            let name = "Local\\swift-memory-test-open-\(UInt32.random(in: 0..<UInt32.max))"

            // Create with size
            let shm1 = try Memory.Shared.open(
                name: name,
                size: 4096,
                mode: .create.exclusive
            )

            // Open existing (without size, uses open(name:mode:))
            let shm2 = try Memory.Shared.open(name: name, mode: [.read, .write])

            // Both should be valid. Hoisted: `#expect` expands a property
            // access through a generic that requires Copyable, and
            // Kernel.Descriptor is ~Copyable.
            let shm1IsValid = shm1.isValid
            let shm2IsValid = shm2.isValid
            #expect(shm1IsValid)
            #expect(shm2IsValid)

            try Memory.Shared.close(shm2)
            try Memory.Shared.close(shm1)
        }
    #endif
}

// MARK: - Edge Case Tests

extension Memory.Shared.Test.`Edge Case` {
    #if os(macOS) || os(Linux)
        @Test
        func `unlink non-existent fails`() {
            let name = "/swift-memory-test-nonexistent-\(UInt32.random(in: 0..<UInt32.max))"

            #expect(throws: Memory.Error.self) {
                try Memory.Shared.unlink(name: name)
            }
        }

        @Test
        func `open non-existent read-only fails`() {
            let name = "/swift-memory-test-nonexistent-\(UInt32.random(in: 0..<UInt32.max))"

            #expect(throws: Memory.Error.self) {
                _ = try Memory.Shared.open(name: name, mode: .read)
            }
        }
    #endif

    #if os(Windows)
        @Test
        func `open non-existent fails (Windows)`() {
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
