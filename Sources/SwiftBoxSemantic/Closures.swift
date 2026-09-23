public enum SBCaptureKind: String, Codable {
    case state
    case immutable
    case mutable
}

public struct SBCapture: Codable, Equatable {
    public let symbolID: SymbolID
    public let name: String
    public let type: SBType
    public let kind: SBCaptureKind
}

/// A statement inside a closure body. Phase 0 closures are action handlers
/// (`Button` actions) with no control flow yet: an optional compound
/// assignment plus captures is enough to make `count += 1` real.
///
/// NOTE: the original golden-fixture sketch for SBClosureInfo carried only
/// `captures`, with no home for the closure's actual statements. That's a
/// gap, not a simplification — without `body`, IR lowering has captures to
/// wire up but no computation to lower. Added here so the model is
/// self-contained: an IR builder can lower a closure from SBClosureInfo
/// alone, without re-visiting SwiftSyntax.
public indirect enum SBStatement: Codable, Equatable {
    case assign(target: SymbolID, value: SBSemanticExpression)
    case expression(SBSemanticExpression)
}

public struct SBClosureInfo: Codable, Equatable {
    public let functionID: FunctionID
    public let captures: [SBCapture]
    public let body: [SBStatement]
}
