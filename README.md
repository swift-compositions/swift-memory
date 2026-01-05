# swift-memory

Safe, ergonomic memory-mapped file I/O and shared memory for Swift.

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

## Table of Contents

- [Motivation](#motivation)
- [Non-Goals](#non-goals)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Guide](#api-guide)
- [Error Handling](#error-handling)
- [Platform Differences](#platform-differences)
- [Thread Safety](#thread-safety)
- [Advanced Usage](#advanced-usage)
- [Performance](#performance)
- [Related Packages](#related-packages)
- [License](#license)

## Motivation

Memory mapping provides direct access to file contents through virtual memory, bypassing the kernel's buffer cache for reads and writes. This eliminates syscall overhead for data access and enables the operating system to manage paging efficiently.

Use memory mapping when:

- Processing large files that exceed available RAM
- Implementing memory-mapped databases or indices
- Sharing memory between processes (IPC)
- Creating copy-on-write snapshots of file data

swift-memory provides a policy layer over raw syscalls with:

- **Move-only semantics** (`~Copyable`) ensuring mappings cannot be accidentally copied
- **RAII lifetime management** with automatic cleanup on scope exit
- **Safety modes** for coordinated file access (`.coordinated`) or unchecked performance (`.unchecked`)

Safety modes control coordination guarantees, not memory bounds checking or data race prevention. The `.coordinated` mode holds file locks to prevent SIGBUS from concurrent truncation; `.unchecked` accepts this risk for maximum performance.

## Non-Goals

swift-memory is not:

- **A serialization layer** - It provides raw byte access, not structured data encoding
- **A cross-process object model** - Shared memory gives you bytes; synchronization and protocol are your responsibility
- **A replacement for higher-level storage** - For key-value stores or databases, use appropriate abstractions built on these primitives
- **A "safe by default" sandbox** - It exposes OS memory semantics directly; misuse can crash your process

## Features

- **File-backed mappings** with range selection (`.whole` or `.bytes(offset:length:)`)
- **Anonymous mappings** for scratch memory not backed by files
- **Shared memory** for inter-process communication
- **Access modes**: `.read`, `[.read, .write]`
- **Sharing modes**: `.shared` (visible to other mappings), `.private` (copy-on-write)
- **Safety modes**: `.coordinated` (file-locked), `.unchecked` (no locking)
- **Page locking** to prevent swapping (`mlock`, `mlockall`)
- **Access advice** for kernel read-ahead optimization (`madvise`)
- **Typed throws** for precise error handling
- **Move-only (`~Copyable`)** types with RAII cleanup

## Installation

Add swift-memory to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/coenttb/swift-memory", from: "0.1.0")
]
```

Then add the dependency to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Memory", package: "swift-memory")
    ]
)
```

Requires Swift 6.0+.

## Quick Start

```swift
import Memory
import Kernel

// Map a file for reading
let fd = try Kernel.File.open(path: "/path/to/data", mode: .read)
defer { try? Kernel.File.close(fd) }

let map: Memory.Map = try Memory.Map(
    fileDescriptor: fd,
    range: .whole,
    access: .read,
    safety: .unchecked
)
defer { map.unmap() }

// Access bytes directly
let header = map[0]
map.withUnsafeBytes { buffer in
    // Process buffer contents
}
```

## API Guide

### Memory.Map

The core type for memory-mapped regions. Move-only (`~Copyable`) with automatic cleanup.

#### File-Backed Mapping

```swift
// Map entire file
let map: Memory.Map = try Memory.Map(
    fileDescriptor: fd,
    range: .whole,
    access: .read,
    sharing: .shared,
    safety: .unchecked
)

// Map specific range
let map: Memory.Map = try Memory.Map(
    fileDescriptor: fd,
    range: .bytes(offset: 4096, length: 8192),
    access: [.read, .write],
    sharing: .shared,
    safety: .coordinated(.exclusive, scope: .mapped)
)
```

#### Anonymous Mapping

Memory not backed by a file, useful for scratch buffers:

```swift
let scratch: Memory.Map = try Memory.Map(
    anonymousLength: 65536,
    access: [.read, .write],
    sharing: .private
)
defer { scratch.unmap() }

scratch[0] = 42
```

#### Access Modes

| Mode | Description |
|------|-------------|
| `.read` | Read-only access |
| `[.read, .write]` | Read and write access |

Note: Write requires read on POSIX systems.

#### Sharing Modes

| Mode | Description |
|------|-------------|
| `.shared` | Changes visible to other mappings of the same file |
| `.private` | Copy-on-write; changes are private to this mapping |

#### Safety Modes

| Mode | Description |
|------|-------------|
| `.unchecked` | No locking; caller accepts SIGBUS risk from truncation |
| `.coordinated(kind, scope:)` | Holds file lock for mapping lifetime |

Coordinated mode options:
- **kind**: `.shared` (read lock) or `.exclusive` (write lock)
- **scope**: `.file` (entire file) or `.mapped` (mapped range only)

#### Operations

```swift
// Sync changes to disk
try map.sync()              // Synchronous
try map.sync(async: true)   // Asynchronous (POSIX only)

// Change protection
try map.protect(.read)      // Remove write permission
try map.protect([.read, .write])  // Restore write permission

// Remap to different range (consuming)
map = try map.remap(fileDescriptor: fd, range: .bytes(offset: 8192, length: 4096))

// Release mapping explicitly
map.unmap()
```

### Memory.Shared

POSIX shared memory for inter-process communication.

#### Creating Shared Memory (POSIX)

```swift
// Create new shared memory object
let shm = try Memory.Shared.open(name: "/my-buffer", mode: .create.exclusive)
defer { try? Memory.Shared.unlink(name: "/my-buffer") }

// Set size (required after creation)
try Kernel.File.truncate(descriptor: shm, size: 4096)

// Map into address space
let map: Memory.Map = try Memory.Map(
    fileDescriptor: shm,
    range: .whole,
    access: [.read, .write],
    sharing: .shared
)
```

#### Opening Existing Shared Memory

```swift
// Open for reading
let shm = try Memory.Shared.open(name: "/my-buffer", mode: .read)

// Open for read/write
let shm = try Memory.Shared.open(name: "/my-buffer", mode: [.read, .write])
```

## Error Handling

swift-memory uses typed throws with `Memory.Error`:

```swift
do {
    let map = try Memory.Map(fileDescriptor: fd, range: .whole)
} catch {
    switch error {
    case .access:
        // Invalid access combination (e.g., write without read)
    case .size:
        // File is empty or too small
    case .unmapped:
        // Operation on already-unmapped region
    case .map(let kernelError):
        // Underlying mmap syscall failed
    case .shared(let kernelError):
        // Shared memory operation failed
    case .page(let kernelError):
        // Page locking failed
    case .lock(let kernelError):
        // File locking failed (coordinated mode)
    case .stat(let kernelError):
        // Failed to get file metadata
    }
}
```

Kernel errors provide platform-specific details through `swift-kernel` error types.

## Platform Differences

| Feature | macOS / Linux | Windows |
|---------|---------------|---------|
| Initialization | Throwing initializer | Static factory `.open()` |
| Shared memory API | `shm_open` / `shm_unlink` | `CreateFileMapping` |
| Shared memory names | Must start with `/` | `Local\` or `Global\` prefix |
| Size specification | Set after create via `ftruncate` | Required at creation |
| Process-wide page lock | `mlockall` supported | Not available |
| io_uring offset mapping | Linux only | N/A |

### Windows Example

```swift
// File mapping on Windows
let map = try Memory.Map.open(
    fileHandle: handle,
    range: .whole,
    access: [.read, .write]
)

// Anonymous mapping on Windows
let scratch = try Memory.Map.anonymous(length: 4096)

// Shared memory on Windows
let shm = try Memory.Shared.open(
    name: "Local\\my-buffer",
    size: 4096,
    mode: .create.exclusive
)
```

## Thread Safety

`Memory.Map` is `@unchecked Sendable`. The mapping itself can be shared across tasks, but:

- **Read-only mappings** can be safely shared without synchronization
- **Concurrent writes** to the same offset are data races
- **Caller must synchronize** when multiple tasks write to the same mapping

The type does not provide internal synchronization. For concurrent write access, use external locks or ensure non-overlapping write regions.

## Advanced Usage

### Page Locking

Prevent pages from being swapped to disk:

```swift
// Lock a mapping
try Memory.Page.Lock.lock(map)
defer { try? Memory.Page.Lock.unlock(map) }

// Lock all current pages (POSIX only)
if Memory.Page.Lock.all.isSupported {
    try Memory.Page.Lock.all.lock(.current)
    defer { try? Memory.Page.Lock.all.unlock() }
}

// Lock all current and future pages
try Memory.Page.Lock.all.lock(.current | .future)
```

Platform notes:
- **macOS**: Requires `com.apple.developer.kernel.memory-allocation` entitlement
- **Linux**: Subject to `RLIMIT_MEMLOCK` (check with `ulimit -l`)
- **Windows**: Uses `VirtualLock`; no process-wide locking

### Access Advice

Hint to the kernel about expected access patterns:

```swift
// Sequential access - enable aggressive read-ahead
map.advise(.sequential)

// Random access - disable read-ahead
map.advise(.random)

// Prefetch pages into memory
map.advise(.willNeed)

// Pages won't be needed soon
map.advise(.dontNeed)
```

Or use the convenience methods:

```swift
Memory.Advice.sequential(map)
Memory.Advice.prefetch(map)
```

### Coordinated Safety Mode

Protect against SIGBUS from concurrent file truncation:

```swift
// Exclusive lock on mapped range
let map: Memory.Map = try Memory.Map(
    fileDescriptor: fd,
    range: .whole,
    access: [.read, .write],
    safety: .coordinated(.exclusive, scope: .mapped)
)

// Shared lock on entire file
let map: Memory.Map = try Memory.Map(
    fileDescriptor: fd,
    range: .bytes(offset: 0, length: 4096),
    access: .read,
    safety: .coordinated(.shared, scope: .file)
)
```

The lock is held for the mapping's lifetime and released on `unmap()` or `deinit`.

## Performance

Memory mapping performance is explicit and observable:

### Page Faults

Mapped memory is lazily loaded. The first access to each page triggers a page fault that loads data from disk. For latency-sensitive code, use `.willNeed` advice to prefetch:

```swift
map.advise(.willNeed)  // Trigger background page-in
```

### Copy-on-Write

Private mappings (`.private`) use copy-on-write. The first write to each page triggers a copy. For write-heavy workloads on file data, consider whether you need copy-on-write semantics or if `.shared` with explicit copying is more appropriate.

### Synchronization

`sync()` flushes modified pages to disk:

```swift
try map.sync()              // Block until complete
try map.sync(async: true)   // Queue and return immediately (POSIX)
```

Async sync reduces latency but does not guarantee durability until completion.

### Read-Ahead

The kernel performs read-ahead for sequential access patterns. Use `madvise` to optimize:

```swift
map.advise(.sequential)  // Aggressive read-ahead
map.advise(.random)      // Disable read-ahead for random access
```

### Alignment

Offsets are automatically aligned to allocation granularity:
- **POSIX**: Page size (4KB or 16KB on Apple Silicon)
- **Windows**: 64KB

Non-aligned offsets work correctly; the library handles internal adjustment.

## Related Packages

swift-memory is part of a layered systems programming stack:

| Package | Role |
|---------|------|
| [swift-kernel](https://github.com/coenttb/swift-kernel) | Syscall substrate: raw wrappers for `mmap`, `shm_open`, `CreateFileMapping`, etc. |
| **swift-memory** | Memory primitives: RAII mappings, shared memory, page locking |
| swift-io | Async I/O built on mapped memory where appropriate |

The separation ensures each layer has a single responsibility:
- swift-kernel provides platform abstraction without policy
- swift-memory adds safety and ergonomics without async complexity
- Higher layers build on these foundations for specific use cases

## License

Apache License 2.0. See [LICENSE](LICENSE) for details.
