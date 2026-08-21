// This source file is part of the swift-memory open source project
// Copyright (c) 2026 Coen ten Thije Boonkkamp and project authors
// Licensed under Apache License v2.0

extension Memory.Allocation.Statistics {
    public enum Availability: Sendable, Equatable {
        case available
        case unavailable
    }
}
