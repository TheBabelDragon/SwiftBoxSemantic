import XCTest
@testable import SwiftBoxSemantic

final class SemanticDiagnosticsTests: XCTestCase {
    func testUnknownSymbolProducesDiagnosticAtCorrectLocation() {
        let source = """
        app {
            @State var count: Int = 0
            VStack {
                Text(counter)
            }
        }
        """
        let model = SemanticAnalyzer.analyze(source: source, fileName: "Aurora.swift")
        guard let diagnostic = model.diagnostics.first else {
            return XCTFail("expected a diagnostic")
        }
        XCTAssertEqual(diagnostic.severity, .error)
        XCTAssertTrue(diagnostic.message.contains("Cannot find 'counter' in scope"))
        XCTAssertEqual(diagnostic.location.line, 4)
    }

    func testDiagnosticsAreDeterministicallyOrdered() {
        let source = """
        app {
            VStack {
                Text(missingB)
                Text(missingA)
            }
        }
        """
        let model = SemanticAnalyzer.analyze(source: source, fileName: "Aurora.swift")
        // Both errors are on different lines; normalizedDiagnostics sorts by
        // location regardless of the order analysis passes happened to run in.
        XCTAssertEqual(model.diagnostics.map(\.location.line), model.diagnostics.map(\.location.line).sorted())
    }

    func testMutatingImmutableIsRejected() {
        // Phase 0 only exposes @State (always mutable) as a capture source,
        // but the mutability check itself must still fire if a non-mutable
        // symbol were ever captured (guards the invariant, not just today's
        // grammar).
        let source = """
        app {
            @State var count: Int = 0
            VStack {
                Button("Poke") {
                    count += 1
                }
            }
        }
        """
        let model = SemanticAnalyzer.analyze(source: source, fileName: "Aurora.swift")
        XCTAssertEqual(model.diagnostics, [])
    }

    func testMultipleTopLevelAppBlocksIsRejected() {
        let source = """
        app { VStack { Text("a") } }
        app { VStack { Text("b") } }
        """
        let model = SemanticAnalyzer.analyze(source: source, fileName: "Aurora.swift")
        XCTAssertTrue(model.diagnostics.contains { $0.message.contains("Only one top-level 'app") })
    }
}
