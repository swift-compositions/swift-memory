extension Memory.Allocation.Statistics {
    public enum Instrumentation: Sendable, Equatable {
        case snapshot
        case interposed
        case none
    }
}
