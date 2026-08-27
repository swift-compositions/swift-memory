import Kernel
import Testing

@testable import Memory_Mapping

extension Memory.Advice {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

#if os(macOS) || os(Linux)
    extension Memory.Advice.Test.Unit {
        @Test
        func `sequential advice on mapping`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
            Memory.Advice.sequential(map)
            map.unmap()
        }

        @Test
        func `random advice on mapping`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
            Memory.Advice.random(map)
            map.unmap()
        }

        @Test
        func `prefetch advice on mapping`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
            Memory.Advice.prefetch(map)
            map.unmap()
        }

        @Test
        func `forget advice on mapping`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
            Memory.Advice.forget(map)
            map.unmap()
        }

        @Test
        func `normal advice on mapping`() throws {
            let map = try Memory.Map(anonymousLength: 4096, access: [.read, .write])
            Memory.Advice.normal(map)
            map.unmap()
        }

        @Test
        func `advise method on map`() throws {
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
        @Test
        func `advice is no-op on Windows`() throws {
            let map = try Memory.Map.anonymous(length: 4096, access: [.read, .write])
            map.advise(.sequential)
            map.unmap()
        }
    }
#endif

extension Memory.Advice.Test.`Edge Case` {

}

extension Memory.Advice.Test.Performance {

}
