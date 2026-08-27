import Testing

@testable import Memory_Mapping

extension Memory.Map.Access {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Memory.Map.Access.Test.Unit {
    @Test
    func `read permission`() {
        let access: Memory.Map.Access = .read
        #expect(access.allows.read)
        #expect(!access.allows.write)
    }

    @Test
    func `write permission`() {
        let access: Memory.Map.Access = .write
        #expect(!access.allows.read)
        #expect(access.allows.write)
    }

    @Test
    func `read-write permission`() {
        let access: Memory.Map.Access = [.read, .write]
        #expect(access.allows.read)
        #expect(access.allows.write)
    }

    @Test
    func `read-only validates`() throws {
        let access: Memory.Map.Access = .read
        try access.validate()

    }

    @Test
    func `read-write validates`() throws {
        let access: Memory.Map.Access = [.read, .write]
        try access.validate()

    }

    @Test
    func `empty access`() {
        let access: Memory.Map.Access = []
        #expect(!access.allows.read)
        #expect(!access.allows.write)
    }

    @Test
    func `access is equatable`() {
        let a: Memory.Map.Access = .read
        let b: Memory.Map.Access = .read
        let c: Memory.Map.Access = [.read, .write]

        #expect(a == b)
        #expect(a != c)
    }

    @Test
    func `access is hashable`() {
        let access: Memory.Map.Access = .read
        let set: Set<Memory.Map.Access> = [access]
        #expect(set.contains(.read))
    }
}

extension Memory.Map.Access.Test.`Edge Case` {
    @Test
    func `write-only validation fails`() {
        let access: Memory.Map.Access = .write

        #expect(throws: Memory.Error.self) {
            try access.validate()
        }
    }

    @Test
    func `empty access validation succeeds`() throws {
        let access: Memory.Map.Access = []

        try access.validate()
    }
}

extension Memory.Map.Access.Test.Performance {

}
