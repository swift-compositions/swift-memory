public import Kernel

extension Memory {

    public typealias Advice = Memory.Map.Advice
}

extension Memory.Advice {

    public static func sequential(_ map: borrowing Memory.Map) {
        map.advise(.sequential)
    }

    public static func random(_ map: borrowing Memory.Map) {
        map.advise(.random)
    }

    public static func prefetch(_ map: borrowing Memory.Map) {
        map.advise(.willNeed)
    }

    public static func forget(_ map: borrowing Memory.Map) {
        map.advise(.dontNeed)
    }

    public static func normal(_ map: borrowing Memory.Map) {
        map.advise(.normal)
    }
}
