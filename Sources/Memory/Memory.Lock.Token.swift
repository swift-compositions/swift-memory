// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-memory open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-memory project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Kernel

extension Memory {
    /// File locking namespace for memory mapping.
    public enum Lock {}
}

extension Memory.Lock {
    /// A class wrapper that holds a file lock for the Region's lifetime.
    ///
    /// This is a class because `~Copyable` types cannot be stored directly
    /// in optional fields. The class provides the necessary indirection for
    /// `Memory.Map`'s optional lock storage.
    ///
    /// ## Why a class?
    ///
    /// `Kernel.Lock.Token` is `~Copyable` for proper RAII semantics, but
    /// `Memory.Map` needs to optionally hold a lock token. Since Swift
    /// doesn't allow `Optional<~Copyable>`, we use a class wrapper.
    ///
    /// ## Usage
    ///
    /// This type is internal to the Memory module. Users interact with
    /// locking through `Memory.Map.Safety` configuration.
    ///
    /// ## Thread Safety
    ///
    /// `Token` is `@unchecked Sendable` but is designed for single-ownership.
    /// The lock is released when `release()` is called or on deinit.
    /// Concurrent calls to `release()` from multiple threads are safe
    /// (guarded by `isReleased` flag), but this should be avoided—
    /// the token should be owned by a single `Memory.Map` instance.
    final class Token: @unchecked Sendable {
        private let descriptor: Kernel.Descriptor
        private let range: Kernel.Lock.Range
        private var isReleased: Bool = false

        /// Creates a lock token by acquiring a lock.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor.
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        ///   - acquire: The acquisition strategy (default: `.wait`).
        /// - Throws: `Kernel.Lock.Error` if locking fails.
        init(
            descriptor: Kernel.Descriptor,
            range: Kernel.Lock.Range,
            kind: Kernel.Lock.Kind,
            acquire: Kernel.Lock.Acquire = .wait
        ) throws(Kernel.Lock.Error) {
            self.descriptor = descriptor
            self.range = range

            switch acquire {
            case .try:
                let acquired = try Kernel.Lock.tryLock(descriptor, range: range, kind: kind)
                if !acquired {
                    throw .contention
                }

            case .wait:
                try Kernel.Lock.lock(descriptor, range: range, kind: kind)

            case .deadline(let deadline):
                try Self.acquireWithDeadline(
                    descriptor: descriptor,
                    range: range,
                    kind: kind,
                    deadline: deadline
                )
            }
        }

        deinit {
            guard !isReleased else { return }
            try? Kernel.Lock.unlock(descriptor, range: range)
        }
    }
}

// MARK: - Release

extension Memory.Lock.Token {
    /// Releases the lock.
    func release() {
        guard !isReleased else { return }
        isReleased = true
        try? Kernel.Lock.unlock(descriptor, range: range)
    }
}

// MARK: - Deadline-based Acquisition

extension Memory.Lock.Token {
    /// Polls for a lock until the deadline expires.
    ///
    /// Uses exponential backoff starting at 1ms, capped at 100ms.
    private static func acquireWithDeadline(
        descriptor: Kernel.Descriptor,
        range: Kernel.Lock.Range,
        kind: Kernel.Lock.Kind,
        deadline: ContinuousClock.Instant
    ) throws(Kernel.Lock.Error) {
        var backoff: Duration = .milliseconds(1)
        let maxBackoff: Duration = .milliseconds(100)

        while true {
            // Check deadline first
            let now = ContinuousClock.now
            if now >= deadline {
                throw .contention
            }

            // Try to acquire
            let acquired = try Kernel.Lock.tryLock(descriptor, range: range, kind: kind)

            if acquired {
                // Re-check deadline after acquisition for strict invariant:
                // "success means lock was acquired before deadline"
                if ContinuousClock.now >= deadline {
                    try? Kernel.Lock.unlock(descriptor, range: range)
                    throw .contention
                }
                return
            }

            // Calculate sleep time (don't overshoot deadline)
            let remaining = deadline - ContinuousClock.now
            if remaining <= .zero {
                throw .contention
            }

            let sleepDuration = min(backoff, remaining)
            sleep(sleepDuration)

            // Exponential backoff with cap
            backoff = min(backoff * 2, maxBackoff)
        }
    }

    /// Sleep using Kernel.System helper.
    private static func sleep(_ duration: Duration) {
        let (seconds, attoseconds) = duration.components
        let nanoseconds = UInt64(seconds) * 1_000_000_000 + UInt64(attoseconds) / 1_000_000_000
        Kernel.System.sleep(nanoseconds: nanoseconds)
    }
}
