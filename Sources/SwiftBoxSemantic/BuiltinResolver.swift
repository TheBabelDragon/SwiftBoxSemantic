import SwiftSyntax

/// Pass 2 (continued): turns a top-level view call expression
/// (`Text(...)`, `Button(...) { ... }`, `VStack { ... }`) into an
/// SBSemanticNode. Requires argument types to already be resolved, which
/// is why this runs after SyntaxBridging's expression analysis, never
/// before.
enum BuiltinResolver {
    static func analyzeViewStatement(
        _ item: CodeBlockItemListSyntax.Element,
        scope: Scope,
        context: AnalyzerContext
    ) -> SBSemanticNode? {
        guard case let .expr(exprSyntax) = item.item,
              let call = exprSyntax.as(FunctionCallExprSyntax.self),
              let callee = call.calledExpression.as(DeclReferenceExprSyntax.self)
        else {
            context.report(.error, "Expected a view expression.", at: item)
            return nil
        }
        return analyzeViewCall(call, name: callee.baseName.text, scope: scope, context: context)
    }

    private static func analyzeViewCall(
        _ call: FunctionCallExprSyntax,
        name: String,
        scope: Scope,
        context: AnalyzerContext
    ) -> SBSemanticNode? {
        switch name {
        case "VStack", "HStack":
            guard let trailing = call.trailingClosure else {
                context.report(.error, "\(name) requires a trailing closure of child views.", at: call)
                return nil
            }
            let children = trailing.statements.compactMap {
                analyzeViewStatement($0, scope: scope, context: context)
            }
            return name == "VStack" ? .vStack(children: children) : .hStack(children: children)

        case "Text":
            guard call.arguments.count == 1, let arg = call.arguments.first else {
                context.report(.error, "Text expects exactly one argument.", at: call)
                return nil
            }
            guard let (value, argType) = SyntaxBridging.analyzeExpression(arg.expression, scope: scope, context: context) else {
                return nil
            }
            guard context.builtins.resolve(name: "Text", argumentTypes: [argType]) != nil else {
                reportOverloadFailure(name: "Text", argumentTypes: [argType], call: call, context: context)
                return nil
            }
            return .text(value: value)

        case "Button":
            guard call.arguments.count == 1, let labelArg = call.arguments.first,
                  let trailing = call.trailingClosure else {
                context.report(.error, "Button expects a label argument and a trailing closure.", at: call)
                return nil
            }
            guard let (label, labelType) = SyntaxBridging.analyzeExpression(labelArg.expression, scope: scope, context: context) else {
                return nil
            }
            let buttonArgTypes: [SBType] = [labelType, .function(parameters: [], result: .void)]
            guard context.builtins.resolve(name: "Button", argumentTypes: buttonArgTypes) != nil else {
                reportOverloadFailure(name: "Button", argumentTypes: buttonArgTypes, call: call, context: context)
                return nil
            }
            let functionID = ClosureAnalyzer.analyze(trailing, enclosingScope: scope, context: context)
            return .button(label: label, action: functionID)

        default:
            context.report(.error, "Unknown view '\(name)'.", at: call)
            return nil
        }
    }

    private static func reportOverloadFailure(
        name: String,
        argumentTypes: [SBType],
        call: FunctionCallExprSyntax,
        context: AnalyzerContext
    ) {
        let matches = context.builtins.matches(name: name, argumentTypes: argumentTypes)
        let argDescription = argumentTypes.map(\.description).joined(separator: ", ")
        if matches.count > 1 {
            context.report(.error, "Ambiguous SwiftBox call to \(name)(\(argDescription)).", at: call)
        } else if context.builtins.candidates(for: name).isEmpty {
            context.report(.error, "Unknown view '\(name)'.", at: call)
        } else {
            context.report(.error, "No matching \(name) initializer for (\(argDescription)).", at: call)
        }
    }
}
