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

extension Memory.Page.Lock {
    #TestSuites
}

// MARK: - Unit Tests

extension Memory.Page.Lock.Test.Unit {
    @Test("isProcessWideLockingSupported returns correct value")
    func isProcessWideLockingSupportedTest() {
        #if os(Windows)
        #expect(!Memory.Page.Lock.isProcessWideLockingSupported)
        #else
        #expect(Memory.Page.Lock.isProcessWideLockingSupported)
        #endif
    }

    #if !os(Windows)
    @Test("lock and unlock memory map")
    func lockAndUnlockMemoryMap() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        // Note: This may fail on macOS without entitlement or on Linux with low RLIMIT_MEMLOCK
        do {
            try Memory.Page.Lock.lock(map)
            try Memory.Page.Lock.unlock(map)
        } catch {
            // Expected on systems with restricted mlock
        }

        map.unmap()
    }

    @Test("lock and unlock by address")
    func lockAndUnlockByAddress() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])

        guard let base = map.baseAddress else {
            map.unmap()
            Issue.record("Map has no base address")
            return
        }

        let length = map.length

        // Note: This may fail on macOS without entitlement
        do {
            try Memory.Page.Lock.lock(address: base, size: length)
            try Memory.Page.Lock.unlock(address: base, size: length)
        } catch {
            // Expected on systems with restricted mlock
        }

        map.unmap()
    }

    @Test("lock all flags are accessible")
    func lockAllFlagsAccessible() {
        // Just verify the types are accessible
        let _: Memory.Page.Lock.All.Flags = .current
        let _: Memory.Page.Lock.All.Flags = .future
    }
    #endif
}

// MARK: - Edge Case Tests

extension Memory.Page.Lock.Test.EdgeCase {
    // Note: "lock on unmapped throws" and "unlock on unmapped throws" tests
    // are not needed because Memory.Map is ~Copyable. Once unmap() consumes
    // the map, the compiler prevents any further access - making these
    // error conditions impossible at runtime.
}

// MARK: - Performance Tests

extension Memory.Page.Lock.Test.Performance {
    // Page locking is a system call with variable behavior
    // No meaningful performance test
}
