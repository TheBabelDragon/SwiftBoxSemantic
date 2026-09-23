import XCTest
@testable import SwiftBoxSemantic

final class AuroraSemanticTests: XCTestCase {
    static let auroraSource = """
    app {
        @State var count: Int = 0
        VStack {
            Text("Hello, scientist")
            Button("Poke") {
                count += 1
            }
            Text(count)
        }
    }
    """

    // Forward reference: the Button (which captures `count`) appears
    // before the @State declaration in source order. Hoisting must make
    // this resolve anyway.
    static let auroraForwardReferenceSource = """
    app {
        VStack {
            Text("Hello, scientist")
            Button("Poke") {
                count += 1
            }
            Text(count)
        }
        @State var count: Int = 0
    }
    """

    func testCountReceivesAStableSymbolID() {
        let model = SemanticAnalyzer.analyze(source: Self.auroraSource, fileName: "Aurora.swift")
        XCTAssertEqual(model.diagnostics, [])
        XCTAssertEqual(model.symbols.count, 1)
        XCTAssertEqual(model.symbols[0].name, "count")
        XCTAssertEqual(model.symbols[0].id, SymbolID(rawValue: 1))
        XCTAssertEqual(model.symbols[0].type, .int)
        XCTAssertEqual(model.symbols[0].kind, .state)
        XCTAssertTrue(model.symbols[0].mutable)
    }

    func testForwardReferencedCountResolves() {
        let model = SemanticAnalyzer.analyze(source: Self.auroraForwardReferenceSource, fileName: "Aurora.swift")
        XCTAssertEqual(model.diagnostics, [], "forward reference to @State declared later in source should resolve cleanly")
        XCTAssertEqual(model.closures.first?.captures.first?.kind, .state)
    }

    func testTextStringResolves() {
        let model = SemanticAnalyzer.analyze(source: Self.auroraSource, fileName: "Aurora.swift")
        guard case let .app(body) = model.root, case let .vStack(children) = body[1] else {
            return XCTFail("expected app { state, vStack }")
        }
        guard case let .text(value) = children[0] else { return XCTFail("expected Text node") }
        XCTAssertEqual(value, .string("Hello, scientist"))
    }

    func testTextIntResolves() {
        let model = SemanticAnalyzer.analyze(source: Self.auroraSource, fileName: "Aurora.swift")
        guard case let .app(body) = model.root, case let .vStack(children) = body[1] else {
            return XCTFail("expected app { state, vStack }")
        }
        guard case let .text(value) = children[2] else { return XCTFail("expected Text node") }
        XCTAssertEqual(value, .variable(SymbolID(rawValue: 1)))
    }

    func testTextDoubleProducesDiagnostic() {
        let source = """
        app {
            VStack {
                Text(3.14)
            }
        }
        """
        let model = SemanticAnalyzer.analyze(source: source, fileName: "Aurora.swift")
        XCTAssertTrue(
            model.diagnostics.contains { $0.message.contains("No matching Text initializer for (Double)") },
            "got: \(model.diagnostics)"
        )
    }

    func testButtonReceivesTypedFunctionIDAndCapturesStateCount() {
        let model = SemanticAnalyzer.analyze(source: Self.auroraSource, fileName: "Aurora.swift")
        guard case let .app(body) = model.root, case let .vStack(children) = body[1] else {
            return XCTFail("expected app { state, vStack }")
        }
        guard case let .button(_, action) = children[1] else { return XCTFail("expected Button node") }
        XCTAssertEqual(action, FunctionID(rawValue: 1))

        guard let closure = model.closures.first(where: { $0.functionID == action }) else {
            return XCTFail("no SBClosureInfo recorded for the Button's FunctionID")
        }
        XCTAssertEqual(closure.captures.count, 1)
        XCTAssertEqual(closure.captures[0].name, "count")
        XCTAssertEqual(closure.captures[0].kind, .state)
        XCTAssertEqual(closure.body, [
            .assign(
                target: SymbolID(rawValue: 1),
                value: .binary(operator: .add, lhs: .variable(SymbolID(rawValue: 1)), rhs: .integer(1))
            )
        ])
    }

    func testSchemaVersion() {
        let model = SemanticAnalyzer.analyze(source: Self.auroraSource, fileName: "Aurora.swift")
        XCTAssertEqual(model.schemaVersion, 1)
    }

    func testRepeatedCompilationIsByteForByteIdentical() throws {
        let first = try SemanticJSON.encode(SemanticAnalyzer.analyze(source: Self.auroraSource, fileName: "Aurora.swift"))
        let second = try SemanticJSON.encode(SemanticAnalyzer.analyze(source: Self.auroraSource, fileName: "Aurora.swift"))
        XCTAssertEqual(first, second)
    }

    func testAuroraMatchesGoldenFixture() throws {
        let model = SemanticAnalyzer.analyze(source: Self.auroraSource, fileName: "Aurora.swift")
        let produced = try SemanticJSON.encode(model)

        let fixtureURL = Bundle.module.url(forResource: "Aurora.semantic", withExtension: "json", subdirectory: "Fixtures")!
        let golden = try Data(contentsOf: fixtureURL)

        let producedModel = try SemanticJSON.decode(produced)
        let goldenModel = try SemanticJSON.decode(golden)
        XCTAssertEqual(producedModel, goldenModel)
    }
}
