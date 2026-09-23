public struct SBSignature: Codable, Equatable {
    public let parameters: [SBType]
    public let result: SBType

    public init(parameters: [SBType], result: SBType) {
        self.parameters = parameters
        self.result = result
    }
}

public struct SBBuiltin: Codable, Equatable {
    public let name: String
    public let signatures: [SBSignature]
}

/// Phase 0's entire built-in vocabulary. Resolution is exact-argument-type
/// match only — no coercion (Int -> Double, anything -> String, etc.).
/// Zero matches or multiple matches are both diagnostics, never a silent
/// pick, so early error behavior stays predictable.
public struct SBBuiltinTable {
    public let builtins: [String: [SBSignature]]

    public init(builtins: [String: [SBSignature]]) {
        self.builtins = builtins
    }

    /// All signatures whose parameter list exactly matches (no coercion).
    public func matches(name: String, argumentTypes: [SBType]) -> [SBSignature] {
        candidates(for: name).filter { $0.parameters == argumentTypes }
    }

    /// Convenience for call sites that only care whether resolution
    /// succeeded uniquely — zero or multiple matches both return nil,
    /// which is why BuiltinResolver calls `matches` directly when it needs
    /// to distinguish "unknown" from "ambiguous" for diagnostics.
    public func resolve(name: String, argumentTypes: [SBType]) -> SBSignature? {
        let found = matches(name: name, argumentTypes: argumentTypes)
        return found.count == 1 ? found.first : nil
    }

    public func candidates(for name: String) -> [SBSignature] {
        builtins[name] ?? []
    }

    public static let phase0: SBBuiltinTable = .init(
        builtins: [
            "Text": [
                SBSignature(parameters: [.string], result: .view(.text)),
                SBSignature(parameters: [.int], result: .view(.text))
            ],
            "Button": [
                SBSignature(
                    parameters: [.string, .function(parameters: [], result: .void)],
                    result: .view(.button)
                )
            ],
            "VStack": [
                SBSignature(
                    parameters: [.function(parameters: [], result: .view(.vStack))],
                    result: .view(.vStack)
                )
            ],
            "HStack": [
                SBSignature(
                    parameters: [.function(parameters: [], result: .view(.hStack))],
                    result: .view(.hStack)
                )
            ]
        ]
    )
}
