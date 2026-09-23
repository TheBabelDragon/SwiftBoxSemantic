import SwiftSyntax

/// Every place SwiftSyntax node shapes get converted into SBType /
/// SBSemanticExpression lives here, so the rest of the analyzer never
/// pattern-matches SwiftSyntax cases directly. If a future Swift front-end
/// change requires updating a case list, this is the only file that moves.
enum SyntaxBridging {
    /// Phase 0 has no inference: every declared type must name one of the
    /// four supported scalars explicitly.
    static func resolveType(_ type: TypeSyntax, context: AnalyzerContext) -> SBType? {
        guard let identifier = type.as(IdentifierTypeSyntax.self) else {
            context.report(.error, "Unsupported type annotation.", at: type)
            return nil
        }
        switch identifier.name.text {
        case "Int": return .int
        case "Double": return .double
        case "Bool": return .bool
        case "String": return .string
        case "Void": return .void
        default:
            context.report(.error, "Unsupported type '\(identifier.name.text)'.", at: type)
            return nil
        }
    }

    /// Literal / identifier / binary-operator expressions only — Phase 0's
    /// entire expression grammar. Returns (expression, type) or nil with a
    /// diagnostic already reported.
    static func analyzeExpression(
        _ expr: ExprSyntax,
        scope: Scope,
        context: AnalyzerContext
    ) -> (SBSemanticExpression, SBType)? {
        if let literal = expr.as(IntegerLiteralExprSyntax.self) {
            guard let value = Int(literal.literal.text) else {
                context.report(.error, "Invalid integer literal.", at: literal)
                return nil
            }
            return (.integer(value), .int)
        }

        if let literal = expr.as(FloatLiteralExprSyntax.self) {
            guard let value = Double(literal.literal.text) else {
                context.report(.error, "Invalid floating-point literal.", at: literal)
                return nil
            }
            return (.double(value), .double)
        }

        if let literal = expr.as(BooleanLiteralExprSyntax.self) {
            return (.boolean(literal.literal.text == "true"), .bool)
        }

        if let literal = expr.as(StringLiteralExprSyntax.self) {
            // Phase 0 supports plain, non-interpolated string literals only.
            guard literal.segments.count == 1,
                  case let .stringSegment(segment)? = literal.segments.first else {
                context.report(.error, "String interpolation is not supported yet.", at: literal)
                return nil
            }
            return (.string(segment.content.text), .string)
        }

        if let ref = expr.as(DeclReferenceExprSyntax.self) {
            let name = ref.baseName.text
            guard let id = scope.lookup(name), let symbol = context.symbolTable.symbol(for: id) else {
                context.report(.error, "Cannot find '\(name)' in scope.", at: ref)
                return nil
            }
            return (.variable(id), symbol.type)
        }

        if let infix = expr.as(InfixOperatorExprSyntax.self) {
            return analyzeBinary(infix, scope: scope, context: context)
        }

        context.report(.error, "Unsupported expression.", at: expr)
        return nil
    }

    private static func analyzeBinary(
        _ infix: InfixOperatorExprSyntax,
        scope: Scope,
        context: AnalyzerContext
    ) -> (SBSemanticExpression, SBType)? {
        guard let opToken = infix.operator.as(BinaryOperatorExprSyntax.self) else {
            context.report(.error, "Unsupported operator.", at: infix)
            return nil
        }
        guard let (lhs, lhsType) = analyzeExpression(infix.leftOperand, scope: scope, context: context),
              let (rhs, rhsType) = analyzeExpression(infix.rightOperand, scope: scope, context: context)
        else { return nil }

        guard lhsType == rhsType, lhsType == .int || lhsType == .double else {
            context.report(
                .error,
                "Operator '\(opToken.operator.text)' is not supported for \(lhsType.description) and \(rhsType.description).",
                at: infix
            )
            return nil
        }

        let op: SBBinaryOperator
        switch opToken.operator.text {
        case "+": op = .add
        case "-": op = .subtract
        case "*": op = .multiply
        case "/": op = .divide
        case "==": op = .equal
        case "!=": op = .notEqual
        default:
            context.report(.error, "Unsupported operator '\(opToken.operator.text)'.", at: infix)
            return nil
        }
        return (.binary(operator: op, lhs: lhs, rhs: rhs), lhsType)
    }
}
