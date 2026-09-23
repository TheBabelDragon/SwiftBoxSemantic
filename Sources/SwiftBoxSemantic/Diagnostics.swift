public struct SBSourceLocation: Codable, Equatable, Comparable {
    public let file: String
    public let line: Int
    public let column: Int

    public init(file: String, line: Int, column: Int) {
        self.file = file
        self.line = line
        self.column = column
    }

    public static func < (lhs: SBSourceLocation, rhs: SBSourceLocation) -> Bool {
        if lhs.file != rhs.file { return lhs.file < rhs.file }
        if lhs.line != rhs.line { return lhs.line < rhs.line }
        return lhs.column < rhs.column
    }
}

public enum SBDiagnosticSeverity: String, Codable {
    case error
    case warning
    case note
}

/// The one diagnostic schema, shared by compiler tests, the on-device error
/// panel, and (eventually) editor source highlighting. Never a second shape.
public struct SBDiagnostic: Codable, Equatable {
    public let severity: SBDiagnosticSeverity
    public let message: String
    public let location: SBSourceLocation
    public let symbolID: SymbolID?

    public init(
        severity: SBDiagnosticSeverity,
        message: String,
        location: SBSourceLocation,
        symbolID: SymbolID? = nil
    ) {
        self.severity = severity
        self.message = message
        self.location = location
        self.symbolID = symbolID
    }
}

/// Deterministic ordering: file, then line, then column, then message —
/// so diagnostics from independently-ordered analyzer passes never produce
/// a golden-fixture diff that isn't a real regression.
public func normalizedDiagnostics(_ diagnostics: [SBDiagnostic]) -> [SBDiagnostic] {
    diagnostics.sorted { lhs, rhs in
        if lhs.location != rhs.location { return lhs.location < rhs.location }
        return lhs.message < rhs.message
    }
}
