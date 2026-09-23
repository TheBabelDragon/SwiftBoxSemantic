/// A lexical scope. Phase 0 has exactly two kinds in practice: the single
/// top-level `app` scope, and one scope per closure body — but the chain
/// is general so nesting isn't a special case later.
public final class Scope {
    public let parent: Scope?
    private var bindings: [String: SymbolID] = [:]

    public init(parent: Scope? = nil) {
        self.parent = parent
    }

    public func define(_ name: String, as id: SymbolID) {
        bindings[name] = id
    }

    /// Walks outward through parents. Returns the first (innermost) match.
    public func lookup(_ name: String) -> SymbolID? {
        if let id = bindings[name] { return id }
        return parent?.lookup(name)
    }

    /// True only if bound directly in this scope, not an ancestor —
    /// used by the capture analyzer to tell "free variable" from "local".
    public func isLocallyBound(_ name: String) -> Bool {
        bindings[name] != nil
    }
}

/// Central table from SymbolID back to the full SBSymbol record, so any
/// pass can resolve a reference without re-walking the scope chain.
public final class SymbolTable {
    private var symbolsByID: [SymbolID: SBSymbol] = [:]
    public private(set) var orderedSymbols: [SBSymbol] = []

    public init() {}

    public func register(_ symbol: SBSymbol) {
        symbolsByID[symbol.id] = symbol
        orderedSymbols.append(symbol)
    }

    public func symbol(for id: SymbolID) -> SBSymbol? {
        symbolsByID[id]
    }
}
