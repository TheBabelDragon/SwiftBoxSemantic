import SwiftSyntax

/// State shared across the hoisting, type-checking, and capture-analysis
/// passes. One instance per compilation — this is what makes SymbolID and
/// FunctionID allocation deterministic and source-order-stable.
public final class AnalyzerContext {
    public let sourceFile: String
    public let converter: SourceLocationConverter
    public let builtins: SBBuiltinTable

    public let symbolAllocator = SymbolIDAllocator()
    public let functionAllocator = FunctionIDAllocator()
    public let symbolTable = SymbolTable()

    public private(set) var diagnostics: [SBDiagnostic] = []
    public private(set) var closures: [SBClosureInfo] = []

    public init(sourceFile: String, tree: SourceFileSyntax, builtins: SBBuiltinTable = .phase0) {
        self.sourceFile = sourceFile
        self.converter = SourceLocationConverter(fileName: sourceFile, tree: tree)
        self.builtins = builtins
    }

    public func location(of node: some SyntaxProtocol) -> SBSourceLocation {
        let loc = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        return SBSourceLocation(file: sourceFile, line: loc.line, column: loc.column)
    }

    public func report(
        _ severity: SBDiagnosticSeverity,
        _ message: String,
        at node: some SyntaxProtocol,
        symbolID: SymbolID? = nil
    ) {
        diagnostics.append(
            SBDiagnostic(
                severity: severity,
                message: message,
                location: location(of: node),
                symbolID: symbolID
            )
        )
    }

    public func recordClosure(_ info: SBClosureInfo) {
        closures.append(info)
    }

    public var hasErrors: Bool {
        diagnostics.contains { $0.severity == .error }
    }
}
