public import Kernel

extension Memory {

    public enum Error: Swift.Error, Sendable {

        case access

        case size

        case unmapped

        case map(Memory.Map.Error)

        case shared(Memory.Shared.Error)

        case lock(Memory.Lock.Error)

        case fileLock(Kernel.Lock.Error)

        case stat(Kernel.File.Stats.Error)
    }
}

extension Memory.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .access:
            return "Invalid access combination (write requires read)"

        case .size:
            return "File too small for requested mapping"

        case .unmapped:
            return "Mapping already unmapped"

        case .map(let error):
            return "Memory map: \(error)"

        case .shared(let error):
            return "Shared memory: \(error)"

        case .lock(let error):
            return "Memory lock: \(error)"

        case .fileLock(let error):
            return "File lock: \(error)"

        case .stat(let error):
            return "Stat: \(error)"
        }
    }
}

extension Memory.Error {

    @inlinable
    public init(from error: Memory.Map.Error) {
        self = .map(error)
    }

    @inlinable
    public init(from error: Memory.Shared.Error) {
        self = .shared(error)
    }

    @inlinable
    public init(from error: Memory.Lock.Error) {
        self = .lock(error)
    }
}
