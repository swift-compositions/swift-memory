public import Kernel
public import Memory_Allocation_Primitive
import Memory

extension Memory {

    public static var allocation: Allocation.Type { Allocation.self }
}

extension System.Page {

    @inlinable
    public static var alignment: Memory.Alignment {
        System.pageSize.alignment
    }

    public static var align: Align.Type { Align.self }

    public enum Align {}
}

extension System.Page.Align {

    @inlinable
    public static func down(_ size: Kernel.File.Size) -> Kernel.File.Size {
        size.alignedDown(to: System.Page.alignment)
    }

    @inlinable
    public static func up(_ size: Kernel.File.Size) -> Kernel.File.Size {
        size.alignedUp(to: System.Page.alignment)
    }
}

extension Memory.Allocation {

    @inlinable
    public static var granularity: Memory.Allocation.Granularity {
        Self.system
    }

    @inlinable
    public static var alignment: Memory.Alignment {
        granularity.underlying
    }

    public static var align: Align.Type { Align.self }

    public enum Align {}
}

extension Memory.Allocation.Align {

    @inlinable
    public static func down(_ offset: Kernel.File.Offset) -> Kernel.File.Offset {
        let magnitude: Int64 = Memory.Allocation.alignment.magnitude()
        let aligned = offset.underlying & ~(magnitude - 1)
        return Kernel.File.Offset(aligned)
    }

    @inlinable
    public static func up(_ offset: Kernel.File.Offset) -> Kernel.File.Offset {
        let magnitude: Int64 = Memory.Allocation.alignment.magnitude()
        let aligned = (offset.underlying + magnitude - 1) & ~(magnitude - 1)
        return Kernel.File.Offset(aligned)
    }

    @inlinable
    public static func down(_ size: Kernel.File.Size) -> Kernel.File.Size {
        size.alignedDown(to: Memory.Allocation.alignment)
    }

    @inlinable
    public static func up(_ size: Kernel.File.Size) -> Kernel.File.Size {
        size.alignedUp(to: Memory.Allocation.alignment)
    }
}
