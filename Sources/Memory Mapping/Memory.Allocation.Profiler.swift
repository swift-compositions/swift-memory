import Synchronization

extension Memory.Allocation {

    public final class Profiler: Sendable {
        internal let measurements: Mutex<[Memory.Allocation.Statistics]>

        public init() {
            self.measurements = Mutex([])
        }
    }
}

extension Memory.Allocation.Profiler {

    @discardableResult
    public func profile<T, E: Swift.Error>(
        _ operation: () throws(E) -> T
    ) throws(E) -> T {
        let (result, stats) = try Memory.Allocation.Tracker.measure(operation)

        measurements.withLock { m in
            m.append(stats)
        }

        return result
    }

    @discardableResult
    nonisolated(nonsending)
        public func profile<T, E: Swift.Error>(
            _ operation: nonisolated(nonsending) () async throws(E) -> T
        ) async throws(E) -> T
    {
        let (result, stats) = try await Memory.Allocation.Tracker.measure(operation)

        measurements.withLock { m in
            m.append(stats)
        }

        return result
    }
}

extension Memory.Allocation.Profiler {

    public var count: Int {
        measurements.withLock { $0.count }
    }

    public var all: [Memory.Allocation.Statistics] {
        measurements.withLock { $0 }
    }

    public func reset() {
        measurements.withLock { m in
            m.removeAll()
        }
    }
}

extension Memory.Allocation.Profiler {

    public var bytes: Bytes { Bytes(self) }

    public var allocations: Allocations { Allocations(self) }
}

extension Memory.Allocation.Profiler {

    public struct Bytes: Sendable {
        private let profiler: Memory.Allocation.Profiler

        internal init(_ profiler: Memory.Allocation.Profiler) {
            self.profiler = profiler
        }
    }
}

extension Memory.Allocation.Profiler.Bytes {

    public var mean: Double {
        profiler.measurements.withLock { m in
            guard !m.isEmpty else { return 0 }
            let total = m.reduce(0) { $0 + $1.bytes.allocated }
            return Double(total) / Double(m.count)
        }
    }

    public var median: Int {
        percentile(50)
    }

    public func percentile(_ p: Int) -> Int {
        profiler.measurements.withLock { m in
            guard !m.isEmpty else { return 0 }

            let sorted = m.map(\.bytes.allocated).sorted()
            let index = Int(Double(sorted.count) * Double(p) / 100.0)
            return sorted[min(index, sorted.count - 1)]
        }
    }
}

extension Memory.Allocation.Profiler {

    public struct Allocations: Sendable {
        private let profiler: Memory.Allocation.Profiler

        internal init(_ profiler: Memory.Allocation.Profiler) {
            self.profiler = profiler
        }
    }
}

extension Memory.Allocation.Profiler.Allocations {

    public var mean: Double {
        profiler.measurements.withLock { m in
            guard !m.isEmpty else { return 0 }
            let total = m.reduce(0) { $0 + $1.allocations }
            return Double(total) / Double(m.count)
        }
    }

    public var median: Int {
        percentile(50)
    }

    public func percentile(_ p: Int) -> Int {
        profiler.measurements.withLock { m in
            guard !m.isEmpty else { return 0 }

            let sorted = m.map(\.allocations).sorted()
            let index = Int(Double(sorted.count) * Double(p) / 100.0)
            return sorted[min(index, sorted.count - 1)]
        }
    }
}

extension Memory.Allocation.Profiler {

    public func histogram(buckets: Int = 10) -> Memory.Allocation.Histogram {
        measurements.withLock { m in
            let bytes = m.map(\.bytes.allocated)
            return Memory.Allocation.Histogram(values: bytes, buckets: buckets)
        }
    }
}
