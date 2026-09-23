import SwiftSyntax
import SwiftParser

/// Public entry point. Owns the pass ordering described in the design
/// contract:
///
///   parse -> hoist -> analyze/type-check -> (captures, fused in pass 2)
///   -> normalize diagnostics -> SBSemanticModel
public enum SemanticAnalyzer {
    public static func analyze(source: String, fileName: String) -> SBSemanticModel {
        let tree = Parser.parse(source: source)
        let context = AnalyzerContext(sourceFile: fileName, tree: tree)
        let rootScope = Scope()

        guard let appCall = findAppCall(in: tree.statements, context: context),
              let appBody = appCall.trailingClosure else {
            context.report(.error, "Expected a single top-level 'app { ... }' declaration.", at: tree)
            return SBSemanticModel(
                sourceFile: fileName,
                symbols: [],
                closures: [],
                root: .app(body: []),
                diagnostics: context.diagnostics
            )
        }

        // Pass 1: hoist every @State declaration in source order before
        // analyzing any initializer or body expression.
        let hoisted = DeclarationHoister.hoist(
            statements: appBody.statements,
            into: rootScope,
            context: context
        )
        // hoist() walks the same statement list, in the same order, filtering
        // the same way (@State VariableDecl bindings) — so pass 2 can just
        // consume `hoisted` as a queue instead of re-matching nodes by
        // identity (SwiftSyntax node types aren't guaranteed Hashable).
        var hoistedQueue = hoisted[...]

        // Pass 2: walk the body in source order. State initializers get
        // analyzed now that every name in the scope is visible; everything
        // else is a view expression resolved through BuiltinResolver
        // (which fuses in closure/capture analysis for Button actions).
        var bodyNodes: [SBSemanticNode] = []
        for item in appBody.statements {
            if case let .decl(declSyntax) = item.item,
               let varDecl = declSyntax.as(VariableDeclSyntax.self) {
                // Queue-consumption assumes one binding per @State decl and
                // that hoist() didn't skip it (e.g. missing type annotation
                // already reported a diagnostic there) — true for every
                // Phase 0 fixture. A multi-binding `@State var a, b: Int`
                // decl would need binding-identity matching instead; not a
                // case Phase 0's builtin grammar produces.
                for binding in varDecl.bindings {
                    guard let next = hoistedQueue.first else { continue }
                    hoistedQueue = hoistedQueue.dropFirst()
                    let id = next.id
                    guard let initializer = binding.initializer else {
                        context.report(.error, "@State declarations require an initial value in Phase 0.", at: binding)
                        continue
                    }
                    guard let symbol = context.symbolTable.symbol(for: id) else { continue }
                    guard let (value, valueType) = SyntaxBridging.analyzeExpression(
                        initializer.value, scope: rootScope, context: context
                    ) else { continue }
                    guard valueType == symbol.type else {
                        context.report(
                            .error,
                            "Cannot initialize '\(symbol.name)' of type \(symbol.type.description) with \(valueType.description).",
                            at: initializer
                        )
                        continue
                    }
                    bodyNodes.append(.state(symbol: id, initialValue: value))
                }
                continue
            }

            if let node = BuiltinResolver.analyzeViewStatement(item, scope: rootScope, context: context) {
                bodyNodes.append(node)
            }
        }

        return SBSemanticModel(
            sourceFile: fileName,
            symbols: context.symbolTable.orderedSymbols,
            closures: context.closures,
            root: .app(body: bodyNodes),
            diagnostics: context.diagnostics
        )
    }

    /// Phase 0 requires exactly one top-level `app { ... }` call expression.
    private static func findAppCall(
        in statements: CodeBlockItemListSyntax,
        context: AnalyzerContext
    ) -> FunctionCallExprSyntax? {
        let calls: [FunctionCallExprSyntax] = statements.compactMap { item in
            guard case let .expr(expr) = item.item,
                  let call = expr.as(FunctionCallExprSyntax.self),
                  let callee = call.calledExpression.as(DeclReferenceExprSyntax.self),
                  callee.baseName.text == "app"
            else { return nil }
            return call
        }
        if calls.count > 1 {
            context.report(.error, "Only one top-level 'app { ... }' is supported.", at: statements)
        }
        return calls.first
    }
}
