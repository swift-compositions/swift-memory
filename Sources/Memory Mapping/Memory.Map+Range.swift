public import Kernel

extension Memory.Map {

    public enum Range: Sendable, Equatable {

        case bytes(offset: Kernel.File.Offset, length: Kernel.File.Size)

        case whole
    }
}

extension Memory.Map.Range {

    public var offset: Kernel.File.Offset {
        switch self {
        case .bytes(let offset, _): return offset
        case .whole: return .zero
        }
    }

    public var length: Kernel.File.Size? {
        switch self {
        case .bytes(_, let length): return length
        case .whole: return nil
        }
    }
}
