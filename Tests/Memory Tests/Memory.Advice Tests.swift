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

extension Memory.Advice {
    #TestSuites
}

// MARK: - Unit Tests

#if !os(Windows)
extension Memory.Advice.Test.Unit {
    @Test("sequential advice on mapping")
    func sequentialAdvice() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
        Memory.Advice.sequential(map)
        map.unmap()
    }

    @Test("random advice on mapping")
    func randomAdvice() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
        Memory.Advice.random(map)
        map.unmap()
    }

    @Test("prefetch advice on mapping")
    func prefetchAdvice() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
        Memory.Advice.prefetch(map)
        map.unmap()
    }

    @Test("forget advice on mapping")
    func forgetAdvice() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
        Memory.Advice.forget(map)
        map.unmap()
    }

    @Test("normal advice on mapping")
    func normalAdvice() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
        Memory.Advice.normal(map)
        map.unmap()
    }

    @Test("advise method on map")
    func adviseMethodOnMap() throws {
        let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
        map.advise(.sequential)
        map.advise(.random)
        map.advise(.normal)
        map.unmap()
    }
}
#endif

#if os(Windows)
extension Memory.Advice.Test.Unit {
    @Test("advice is no-op on Windows")
    func adviceNoOpOnWindows() throws {
        let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])
        map.advise(.sequential)
        map.unmap()
    }
}
#endif

// MARK: - Edge Case Tests

extension Memory.Advice.Test.EdgeCase {
    // Advice on unmapped region is a no-op (guard pattern in advise)
    // No error thrown, just returns early
}

// MARK: - Performance Tests

extension Memory.Advice.Test.Performance {
    // Advice operations are system calls, no meaningful perf test
}
