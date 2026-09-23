import SwiftSyntax

/// Pass 1 of 3. Registers every `@State var` in the app scope, in source
/// order, before anything's initializer or the body is analyzed — so a
/// closure that references state declared *later* in the source still
/// resolves. Initializer expressions are deliberately not analyzed here;
/// that happens in pass 2, once every name in the scope is already visible.
///
/// NOTE ON SYNTAX: `state var count: Int = 0` (as first sketched) is not
/// valid Swift syntax — "state" isn't a declaration modifier and SwiftSyntax
/// would treat the file as containing a leading identifier expression
/// followed by an unrelated `var` decl, or report a parse error, depending
/// on recovery. This hoister instead requires the real Swift attribute
/// form `@State var count: Int = 0` (matching SwiftUI's own convention),
/// which SwiftSyntax parses cleanly as a VariableDeclSyntax with an
/// AttributeListSyntax. Front-end syntax should be real, parseable Swift;
/// "state" was never going to survive contact with SwiftSyntax's grammar.
enum DeclarationHoister {
    struct Hoisted {
        let id: SymbolID
        let decl: VariableDeclSyntax
        let binding: PatternBindingSyntax
    }

    static func hoist(
        statements: CodeBlockItemListSyntax,
        into scope: Scope,
        context: AnalyzerContext
    ) -> [Hoisted] {
        var hoisted: [Hoisted] = []

        for item in statements {
            guard case let .decl(declSyntax) = item.item,
                  let varDecl = declSyntax.as(VariableDeclSyntax.self) else {
                continue
            }

            guard hasStateAttribute(varDecl) else {
                context.report(.error, "Only @State declarations are supported in Phase 0.", at: varDecl)
                continue
            }

            guard varDecl.bindingSpecifier.tokenKind == .keyword(.var) else {
                context.report(.error, "@State must be declared with 'var', not 'let'.", at: varDecl)
                continue
            }

            for binding in varDecl.bindings {
                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    context.report(.error, "Unsupported declaration pattern.", at: binding)
                    continue
                }
                guard let typeAnnotation = binding.typeAnnotation else {
                    context.report(
                        .error,
                        "Type inference is not enabled in SwiftBox v0.1. Add an explicit type annotation.",
                        at: binding
                    )
                    continue
                }
                guard let type = SyntaxBridging.resolveType(typeAnnotation.type, context: context) else {
                    continue
                }

                let name = pattern.identifier.text
                let id = context.symbolAllocator.allocateSymbol()
                let symbol = SBSymbol(
                    id: id,
                    name: name,
                    type: type,
                    kind: .state,
                    mutable: true,
                    declaration: context.location(of: pattern)
                )
                context.symbolTable.register(symbol)
                scope.define(name, as: id)
                hoisted.append(Hoisted(id: id, decl: varDecl, binding: binding))
            }
        }

        return hoisted
    }

    private static func hasStateAttribute(_ decl: VariableDeclSyntax) -> Bool {
        decl.attributes.contains { element in
            guard case let .attribute(attribute) = element,
                  let name = attribute.attributeName.as(IdentifierTypeSyntax.self) else {
                return false
            }
            return name.name.text == "State"
        }
    }
}
