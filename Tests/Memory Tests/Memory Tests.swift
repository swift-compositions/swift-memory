import Testing

@testable import Memory

extension Memory {
    enum Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite(.serialized) struct Performance {}
    }
}

extension Memory.Test.Unit {

}

extension Memory.Test.`Edge Case` {

}

extension Memory.Test.Performance {

}
