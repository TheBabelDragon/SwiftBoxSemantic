import Foundation

/// The serializer is responsible for its own determinism — callers never
/// need to remember to sort keys or pretty-print consistently. Combined
/// with SBSemanticModel normalizing its own diagnostics on init, two
/// compilations of unchanged source produce byte-for-byte identical JSON.
public enum SemanticJSON {
    public static func encode(_ model: SBSemanticModel) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(model)
    }

    public static func encodeString(_ model: SBSemanticModel) throws -> String {
        let data = try encode(model)
        return String(decoding: data, as: UTF8.self)
    }

    public static func decode(_ data: Data) throws -> SBSemanticModel {
        try JSONDecoder().decode(SBSemanticModel.self, from: data)
    }
}
