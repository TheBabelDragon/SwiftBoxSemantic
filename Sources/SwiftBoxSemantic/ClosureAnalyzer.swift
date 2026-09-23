import SwiftSyntax

/// Analyzes a `() -> Void` action closure body (currently: Button actions).
///
/// Implementation note: the spec sketch treats "type-check the body" and
/// "derive captures" as two separate passes (ExpressionTypeChecker, then
/// CaptureAnalyzer). In practice they're one walk here — Phase 0 closures
/// declare no parameters and no local bindings, so *every* identifier a
/// closure body resolves is by definition a capture from the enclosing
/// scope. Splitting them into two traversals would mean re-walking the
/// same statements to re-derive information the first walk already had.
/// The two-pass *contract* (captures are keyed by SymbolID, not by name)
/// is preserved even though the two passes are fused.
enum ClosureAnalyzer {
    static func analyze(
        _ closure: ClosureExprSyntax,
        enclosingScope: Scope,
        context: AnalyzerContext
    ) -> FunctionID {
        let functionID = context.functionAllocator.allocateFunction()
        var referencedSymbols: [SymbolID: SBCapture] = [:]
        var statements: [SBStatement] = []

        for item in closure.statements {
            guard case let .expr(exprSyntax) = item.item else {
                context.report(.error, "Unsupported statement in closure body.", at: item)
                continue
            }

            if let statement = analyzeStatement(
                exprSyntax,
                scope: enclosingScope,
                context: context,
                captures: &referencedSymbols
            ) {
                statements.append(statement)
            }
        }

        context.recordClosure(
            SBClosureInfo(
                functionID: functionID,
                captures: Array(referencedSymbols.values).sorted { $0.symbolID.rawValue < $1.symbolID.rawValue },
                body: statements
            )
        )
        return functionID
    }

    private static func analyzeStatement(
        _ expr: ExprSyntax,
        scope: Scope,
        context: AnalyzerContext,
        captures: inout [SymbolID: SBCapture]
    ) -> SBStatement? {
        // Compound assignment ("count += 1") is syntactically just an infix
        // operator whose operator token is "+=" etc. — Swift has no
        // separate compound-assignment node. We special-case it here,
        // before falling into SyntaxBridging's pure-value binary handling.
        if let infix = expr.as(InfixOperatorExprSyntax.self),
           let opToken = infix.operator.as(BinaryOperatorExprSyntax.self),
           let op = compoundOperator(opToken.operator.text) {
            guard let target = infix.leftOperand.as(DeclReferenceExprSyntax.self) else {
                context.report(.error, "Left side of assignment must be a variable.", at: infix.leftOperand)
                return nil
            }
            guard let symbolID = resolveCapture(name: target.baseName.text, node: target, scope: scope, context: context, captures: &captures) else {
                return nil
            }
            guard let symbol = context.symbolTable.symbol(for: symbolID) else { return nil }
            guard symbol.mutable else {
                context.report(.error, "Cannot mutate immutable value '\(symbol.name)'.", at: target, symbolID: symbolID)
                return nil
            }
            guard let (rhsExpr, rhsType) = SyntaxBridging.analyzeExpression(infix.rightOperand, scope: scope, context: context) else {
                return nil
            }
            guard rhsType == symbol.type else {
                context.report(.error, "Cannot assign \(rhsType.description) to '\(symbol.name)' of type \(symbol.type.description).", at: infix)
                return nil
            }
            let value = SBSemanticExpression.binary(operator: op, lhs: .variable(symbolID), rhs: rhsExpr)
            return .assign(target: symbolID, value: value)
        }

        if let assignment = expr.as(AssignmentExprSyntax.self) {
            // Plain "=" appears as its own node in SwiftSyntax.
            _ = assignment
            context.report(.error, "Plain assignment is not supported in Phase 0 — use a compound operator.", at: expr)
            return nil
        }

        guard let (value, _) = analyzeExpressionRecordingCaptures(expr, scope: scope, context: context, captures: &captures) else {
            return nil
        }
        return .expression(value)
    }

    /// Wraps SyntaxBridging.analyzeExpression, additionally recording every
    /// `.variable` it resolves as a capture. This is the "fusion" referenced
    /// in the type-level comment above.
    private static func analyzeExpressionRecordingCaptures(
        _ expr: ExprSyntax,
        scope: Scope,
        context: AnalyzerContext,
        captures: inout [SymbolID: SBCapture]
    ) -> (SBSemanticExpression, SBType)? {
        if let ref = expr.as(DeclReferenceExprSyntax.self) {
            guard let id = resolveCapture(name: ref.baseName.text, node: ref, scope: scope, context: context, captures: &captures),
                  let symbol = context.symbolTable.symbol(for: id) else {
                return nil
            }
            return (.variable(id), symbol.type)
        }
        if let infix = expr.as(InfixOperatorExprSyntax.self) {
            guard let (lhs, lhsType) = analyzeExpressionRecordingCaptures(infix.leftOperand, scope: scope, context: context, captures: &captures),
                  let (rhs, _) = analyzeExpressionRecordingCaptures(infix.rightOperand, scope: scope, context: context, captures: &captures)
            else { return nil }
            // Delegate operator validation to SyntaxBridging by re-running
            // it on the already-capture-scanned operands' source form.
            guard let result = SyntaxBridging.analyzeExpression(expr, scope: scope, context: context) else { return nil }
            _ = (lhs, lhsType, rhs)
            return result
        }
        return SyntaxBridging.analyzeExpression(expr, scope: scope, context: context)
    }

    private static func resolveCapture(
        name: String,
        node: some SyntaxProtocol,
        scope: Scope,
        context: AnalyzerContext,
        captures: inout [SymbolID: SBCapture]
    ) -> SymbolID? {
        guard let id = scope.lookup(name) else {
            context.report(.error, "Cannot find '\(name)' in scope.", at: node)
            return nil
        }
        guard let symbol = context.symbolTable.symbol(for: id) else { return nil }
        let kind: SBCaptureKind = symbol.kind == .state ? .state : (symbol.mutable ? .mutable : .immutable)
        captures[id] = SBCapture(symbolID: id, name: symbol.name, type: symbol.type, kind: kind)
        return id
    }

    private static func compoundOperator(_ text: String) -> SBBinaryOperator? {
        switch text {
        case "+=": return .add
        case "-=": return .subtract
        case "*=": return .multiply
        case "/=": return .divide
        default: return nil
        }
    }
}
