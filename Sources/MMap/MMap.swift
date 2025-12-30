// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-mmap open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-mmap project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

/// Memory mapping namespace.
///
/// Provides high-level memory mapping with:
/// - `Region`: RAII wrapper for mapped memory
/// - `Access`: read, readWrite, copyOnWrite
/// - `Sharing`: shared, private
/// - `Safety`: coordinated (with file locking), unchecked
///
/// Built on `Kernel.Mmap` syscalls from swift-kernel.
public enum MMap {}
