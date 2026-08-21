extension Memory.Allocation {

    public enum Tracker {}
}

extension Memory.Allocation.Tracker {
    public static func measure<T, E: Swift.Error>(
        _ operation: () throws(E) -> T
    ) throws(E) -> (T, Memory.Allocation.Statistics) {
        let before = Memory.Allocation.Statistics.capture()
        let result = try operation()
        let after = Memory.Allocation.Statistics.capture()
        return (result, Memory.Allocation.Statistics.delta(from: before, to: after))
    }

    nonisolated(nonsending)
        public static func measure<T, E: Swift.Error>(
            _ operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> (T, Memory.Allocation.Statistics)
    {
        let before = Memory.Allocation.Statistics.capture()
        let result = try await operation()
        let after = Memory.Allocation.Statistics.capture()
        return (result, Memory.Allocation.Statistics.delta(from: before, to: after))
    }
}
