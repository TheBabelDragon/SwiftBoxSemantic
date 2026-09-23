/// Identifies a resolved variable/state/parameter/function-name binding.
///
/// Deliberately its own type rather than a bare Int, so a symbol reference
/// can never be silently confused with an arbitrary integer or a FunctionID.
public struct SymbolID: RawRepresentable, Hashable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

/// Identifies a closure/function body distinct from any variable symbol.
public struct FunctionID: RawRepresentable, Hashable, Codable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public enum SBSymbolKind: String, Codable {
    case variable
    case state
    case parameter
    case function
    case builtin
}

public struct SBSymbol: Codable, Equatable {
    public let id: SymbolID
    public let name: String
    public let type: SBType
    public let kind: SBSymbolKind
    public let mutable: Bool
    public let declaration: SBSourceLocation
}

/// Monotonic, source-order allocator. One instance per compilation.
///
/// Allocation order is fixed by the hoisting pass (declarations first, in
/// source order), so IDs are stable across runs on unchanged source —
/// a precondition for byte-for-byte-identical golden fixtures.
public final class SymbolIDAllocator {
    private var next = 1
    public init() {}

    public func allocateSymbol() -> SymbolID {
        defer { next += 1 }
        return SymbolID(rawValue: next)
    }
}

public final class FunctionIDAllocator {
    private var next = 1
    public init() {}

    public func allocateFunction() -> FunctionID {
        defer { next += 1 }
        return FunctionID(rawValue: next)
    }
}
