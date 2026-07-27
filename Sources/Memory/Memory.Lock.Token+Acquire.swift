// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-memory open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-memory project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Kernel

#if !os(Windows)

    extension Memory.Lock.Token {
        /// Acquires a file lock and returns a witness-pattern token that releases on deinit.
        ///
        /// Dups the caller's descriptor — the token's release closure owns the dup'd
        /// `Kernel.Descriptor` and closes it on token release.
        ///
        /// - Parameters:
        ///   - descriptor: The file descriptor (borrowed — the call dups it).
        ///   - range: The byte range to lock.
        ///   - kind: The lock kind (shared or exclusive).
        /// - Returns: A token whose release closure unlocks and closes the dup'd descriptor.
        /// - Throws: `Kernel.Lock.Error` if locking or dup fails.
        public static func acquire(
            descriptor: borrowing Kernel.Descriptor,
            range: Kernel.Lock.Range,
            kind: Memory.Lock.Kind
        ) throws(Kernel.Lock.Error) -> Memory.Lock.Token {
            // Item 1.5 Path δ (2026-05-02): typed Descriptor throughout — no
            // `_rawValue` extraction at any layer boundary. Phase A experiment
            // (swift-institute/Experiments/memory-lock-token-noncopyable-closure-capture/)
            // CONFIRMED that `var Optional<~Copyable>` captures correctly in a
            // non-@Sendable closure with `.take()` semantics.

            // Dup via typed L2 form — returns owning Kernel.Descriptor.
            let duped: Kernel.Descriptor
            do throws(Kernel.Descriptor.Duplicate.Error) {
                duped = try Kernel.Descriptor.Duplicate.duplicate(descriptor)
            } catch {
                throw .unavailable
            }

            let kernelKind: Kernel.Lock.Kind
            switch kind {
            case .shared: kernelKind = .shared
            case .exclusive: kernelKind = .exclusive
            }

            // Acquire the lock on the duped descriptor (typed L2 form).
            do throws(Kernel.Lock.Error) {
                try Kernel.Lock.lock(duped, range: range, kind: kernelKind)
            } catch {
                // Lock acquisition failed — close the duped descriptor before throwing.
                do throws(Kernel.Close.Error) {
                    try Kernel.Close.close(consume duped)
                } catch {}
                throw error
            }

            // Re-store for closure capture: var Optional<~Copyable> + .take() pattern
            // per feedback_no_raw_descriptor_reconstruction. The closure is non-@Sendable
            // (Token dropped Sendable in Phase 2 to enable this capture).
            var ownedFd: Kernel.Descriptor? = consume duped
            return Memory.Lock.Token(release: {
                guard let fd = ownedFd.take() else { return }
                do throws(Kernel.Lock.Error) {
                    try Kernel.Lock.unlock(fd, range: range)
                } catch {}
                do throws(Kernel.Close.Error) {
                    try Kernel.Close.close(consume fd)
                } catch {}
            })
        }
    }

#endif
