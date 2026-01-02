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

public import Kernel

#if os(Windows)
    internal import WinSDK
#endif

extension MMap {
    /// Errors that can occur during memory mapping operations.
    ///
    /// These are semantic errors translated from platform-specific error codes.
    /// The translation provides a stable, portable API.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The requested operation is not supported on this platform or configuration.
        case unsupported

        /// The requested range is invalid (e.g., extends beyond file size).
        case invalidRange

        /// The offset or length is not properly aligned.
        case invalidAlignment

        /// Invalid access combination (e.g., `.write` without `.read`).
        case invalidAccess

        /// Permission denied for the requested access mode.
        case permissionDenied

        /// Insufficient memory to create the mapping.
        case outOfMemory

        /// The file is too small for the requested mapping.
        case fileTooSmall

        /// The requested mapping size exceeds system limits.
        case mappingSizeLimit

        /// The access/sharing/safety combination is not supported.
        case unsupportedConfiguration

        /// The file handle is invalid or closed.
        case invalidHandle

        /// The mapping operation is not supported on this file type.
        case unsupportedFileType

        /// The mapping was previously unmapped and cannot be used.
        case alreadyUnmapped

        /// Lock acquisition failed during coordinated mapping.
        ///
        /// This occurs when `.coordinated` safety is requested but the file
        /// lock cannot be acquired (e.g., another process holds an exclusive lock).
        case lockFailed(Kernel.Lock.Error)

        /// Failed to get file metadata (stat).
        case statFailed(Kernel.Stat.Error)

        /// Platform-specific error with error code.
        case platform(code: Int32, message: String)
    }
}

// MARK: - CustomStringConvertible

extension MMap.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .unsupported:
            return "Memory mapping not supported"
        case .invalidRange:
            return "Invalid mapping range"
        case .invalidAlignment:
            return "Invalid alignment"
        case .invalidAccess:
            return "Invalid access combination (write requires read)"
        case .permissionDenied:
            return "Permission denied"
        case .outOfMemory:
            return "Out of memory"
        case .fileTooSmall:
            return "File too small for requested mapping"
        case .mappingSizeLimit:
            return "Mapping size exceeds system limit"
        case .unsupportedConfiguration:
            return "Unsupported access/sharing/safety configuration"
        case .invalidHandle:
            return "Invalid file handle"
        case .unsupportedFileType:
            return "Unsupported file type for mapping"
        case .alreadyUnmapped:
            return "Mapping already unmapped"
        case .lockFailed(let lockError):
            return "Lock acquisition failed: \(lockError.description)"
        case .statFailed(let error):
            return "Failed to get file metadata: \(error)"
        case .platform(let code, let message):
            return "Platform error \(code): \(message)"
        }
    }
}

// MARK: - Translation from Kernel.Mmap.Error

extension MMap.Error {
    /// Creates a semantic error from a Kernel.Mmap.Error.
    ///
    /// This is the single, auditable translation table from kernel
    /// errors to portable semantic errors.
    init(from kernelError: Kernel.Mmap.Error) {
        switch kernelError {
        case .mapFailed(let errno):
            #if os(Windows)
            self = .platform(code: errno, message: "mmap failed")
            #else
            self = Self.fromErrno(errno, operation: "mmap")
            #endif
        case .unmapFailed(let errno):
            #if os(Windows)
            self = .platform(code: errno, message: "munmap failed")
            #else
            self = Self.fromErrno(errno, operation: "munmap")
            #endif
        case .syncFailed(let errno):
            #if os(Windows)
            self = .platform(code: errno, message: "msync failed")
            #else
            self = Self.fromErrno(errno, operation: "msync")
            #endif
        case .protectFailed(let errno):
            #if os(Windows)
            self = .platform(code: errno, message: "mprotect failed")
            #else
            self = Self.fromErrno(errno, operation: "mprotect")
            #endif
        case .invalidArgument(let msg):
            if msg.contains("length") {
                self = .invalidRange
            } else {
                self = .invalidAlignment
            }
        #if os(Windows)
        case .windows(let code, let operation):
            self = Self.fromWindowsError(DWORD(code), operation: operation)
        #endif
        }
    }
}

// MARK: - POSIX Error Translation

#if !os(Windows)
    extension MMap.Error {
        /// Maps POSIX errno to semantic error.
        static func fromErrno(_ errno: Int32, operation: String) -> Self {
            // Note: errno constants are provided by Kernel's public imports
            switch errno {
            case 13, 1:  // EACCES, EPERM
                return .permissionDenied
            case 22:  // EINVAL
                return .invalidAlignment
            case 12:  // ENOMEM
                return .outOfMemory
            case 19:  // ENODEV
                return .unsupportedFileType
            case 9:  // EBADF
                return .invalidHandle
            case 6:  // ENXIO
                return .invalidRange
            case 27:  // EFBIG
                return .mappingSizeLimit
            case 45, 95:  // ENOTSUP (Darwin: 45, Linux: 95)
                return .unsupported
            default:
                return .platform(code: errno, message: operation)
            }
        }
    }
#endif

// MARK: - Windows Error Translation

#if os(Windows)
    extension MMap.Error {
        /// Maps Windows error code to semantic error.
        static func fromWindowsError(_ error: DWORD, operation: String) -> Self {
            switch error {
            case DWORD(ERROR_ACCESS_DENIED):
                return .permissionDenied
            case DWORD(ERROR_INVALID_PARAMETER):
                return .invalidAlignment
            case DWORD(ERROR_NOT_ENOUGH_MEMORY), DWORD(ERROR_OUTOFMEMORY):
                return .outOfMemory
            case DWORD(ERROR_INVALID_HANDLE):
                return .invalidHandle
            case DWORD(ERROR_FILE_INVALID):
                return .unsupportedFileType
            default:
                return .platform(code: Int32(error), message: "\(operation): Windows error")
            }
        }
    }
#endif
