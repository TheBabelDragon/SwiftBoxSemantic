/// The complete Phase 0 type universe.
///
/// Deliberately closed. No Optional, Array, struct, protocol, or generic
/// cases yet — adding those later must not require reshaping the cases
/// that already exist here, only adding new ones.
public enum SBType: Equatable, Codable {
    case void
    case bool
    case int
    case double
    case string
    indirect case function(parameters: [SBType], result: SBType)
    case view(SBViewType)
}

/// The fixed set of built-in view kinds recognized in Phase 0.
public enum SBViewType: String, Equatable, Codable {
    case text
    case button
    case vStack
    case hStack
    case app
}

extension SBType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .void: return "Void"
        case .bool: return "Bool"
        case .int: return "Int"
        case .double: return "Double"
        case .string: return "String"
        case let .function(parameters, result):
            let params = parameters.map(\.description).joined(separator: ", ")
            return "(\(params)) -> \(result.description)"
        case let .view(kind):
            return "View<\(kind.rawValue)>"
        }
    }
}
