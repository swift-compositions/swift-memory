import Testing

@testable import Memory

extension Memory.Map.Sharing {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Memory.Map.Sharing.Test.Unit {
    @Test
    func `shared mode`() {
        let sharing = Memory.Map.Sharing.shared
        #expect(sharing == .shared)
    }

    @Test
    func `private mode`() {
        let sharing = Memory.Map.Sharing.private
        #expect(sharing == .private)
    }

    @Test
    func `sharing is equatable`() {
        let a = Memory.Map.Sharing.shared
        let b = Memory.Map.Sharing.shared
        let c = Memory.Map.Sharing.private

        #expect(a == b)
        #expect(a != c)
    }

    #if os(macOS) || os(Linux)
        @Test
        func `anonymous mapping default is private`() throws {
            let map = try Memory.Map(anonymousLength: 4096)
            let sharing = map.sharing
            map.unmap()
            #expect(sharing == .private)
        }

        @Test
        func `anonymous mapping with shared`() throws {
            let map = try Memory.Map(anonymousLength: 4096, sharing: .shared)
            let sharing = map.sharing
            map.unmap()
            #expect(sharing == .shared)
        }

        @Test
        func `anonymous mapping with private`() throws {
            let map = try Memory.Map(anonymousLength: 4096, sharing: .private)
            let sharing = map.sharing
            map.unmap()
            #expect(sharing == .private)
        }
    #endif
}

extension Memory.Map.Sharing.Test.`Edge Case` {

}

extension Memory.Map.Sharing.Test.Performance {

}
