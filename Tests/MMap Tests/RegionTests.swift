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
    @Test
    func anonymousMapping() throws {
        let region = try MMap.Region(anonymousLength: 4096)
        // Extract values before consuming
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
}
