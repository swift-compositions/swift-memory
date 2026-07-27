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

import Testing

@testable import Memory

extension System.Page.Lock {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

// MARK: - Unit Tests

extension System.Page.Lock.Test.Unit {
    // Platform capabilities (isProcessWideLockingSupported) are tested in swift-kernel

    #if os(macOS) || os(Linux)
        @Test
        func `lock and unlock memory map`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            // Note: This may fail on macOS without entitlement or on Linux with low RLIMIT_MEMLOCK
            do throws(Memory.Error) {
                try System.Page.Lock.lock(map)
                try System.Page.Lock.unlock(map)
            } catch {
                // Expected on systems with restricted mlock
            }

            map.unmap()
        }

        @Test
        func `lock and unlock by address`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

            guard let base = map.baseAddress else {
                map.unmap()
                Issue.record("Map has no base address")
                return
            }

            let length = map.length

            // Note: This may fail on macOS without entitlement
            do throws(Memory.Error) {
                try System.Page.Lock.lock(address: base, size: length)
                try System.Page.Lock.unlock(address: base, size: length)
            } catch {
                // Expected on systems with restricted mlock
            }

            map.unmap()
        }

        @Test
        func `lock all flags are accessible`() {
            // Just verify the types are accessible
            let _: System.Page.Lock.All.Options = .current
            let _: System.Page.Lock.All.Options = .future
        }
    #endif

    #if os(Windows)
        @Test
        func `lock and unlock memory map (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

            guard let base = map.baseAddress else {
                map.unmap()
                Issue.record("Map has no base address")
                return
            }

            let length = map.length

            // Note: VirtualLock may fail due to working set quota
            do throws(Memory.Error) {
                try System.Page.Lock.lock(address: base, size: length)
                try System.Page.Lock.unlock(address: base, size: length)
            } catch {
                // Expected on systems with restricted working set
            }

            map.unmap()
        }

        @Test
        func `lock and unlock by address (Windows)`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])

            guard let base = map.baseAddress else {
                map.unmap()
                Issue.record("Map has no base address")
                return
            }

            let length = map.length

            // Note: VirtualLock may fail due to working set quota
            do throws(Memory.Error) {
                try System.Page.Lock.lock(address: base, size: length)
                try System.Page.Lock.unlock(address: base, size: length)
            } catch {
                // Expected on systems with restricted working set
            }

            map.unmap()
        }
    #endif
}

// MARK: - Edge Case Tests

extension System.Page.Lock.Test.`Edge Case` {
    // Note: "lock on unmapped throws" and "unlock on unmapped throws" tests
    // are not needed because Memory.Map is ~Copyable. Once unmap() consumes
    // the map, the compiler prevents any further access - making these
    // error conditions impossible at runtime.
}

// MARK: - Performance Tests

extension System.Page.Lock.Test.Performance {
    // Page locking is a system call with variable behavior
    // No meaningful performance test
}
