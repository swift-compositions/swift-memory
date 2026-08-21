extension Memory.Allocation.Statistics {
    public enum Scope: Sendable, Equatable {
        case process
        case thread
        case none
    }
}
