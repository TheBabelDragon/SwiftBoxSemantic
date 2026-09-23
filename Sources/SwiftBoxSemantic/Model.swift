public indirect enum SBSemanticExpression: Codable, Equatable {
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case string(String)
    case variable(SymbolID)
    case binary(operator: SBBinaryOperator, lhs: SBSemanticExpression, rhs: SBSemanticExpression)
}

public enum SBBinaryOperator: String, Codable {
    case add
    case subtract
    case multiply
    case divide
    case equal
    case notEqual
}

public indirect enum SBSemanticNode: Codable, Equatable {
    case app(body: [SBSemanticNode])
    case state(symbol: SymbolID, initialValue: SBSemanticExpression)
    case text(value: SBSemanticExpression)
    case button(label: SBSemanticExpression, action: FunctionID)
    case vStack(children: [SBSemanticNode])
    case hStack(children: [SBSemanticNode])
    case expression(SBSemanticExpression)
}

/// The frozen boundary between the SwiftBox front end and everything
/// downstream (IR, VM, on-device tooling). Contains no SwiftSyntax types —
/// that is the property this whole file exists to guarantee.
public struct SBSemanticModel: Codable, Equatable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let sourceFile: String
    public let symbols: [SBSymbol]
    public let closures: [SBClosureInfo]
    public let root: SBSemanticNode
    public let diagnostics: [SBDiagnostic]

    public init(
        sourceFile: String,
        symbols: [SBSymbol],
        closures: [SBClosureInfo],
        root: SBSemanticNode,
        diagnostics: [SBDiagnostic]
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.sourceFile = sourceFile
        self.symbols = symbols
        self.closures = closures
        self.root = root
        self.diagnostics = normalizedDiagnostics(diagnostics)
    }
}
