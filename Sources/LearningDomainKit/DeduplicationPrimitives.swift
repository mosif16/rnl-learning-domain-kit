import Foundation

public protocol HashableContent {
    var contentHash: String { get }
    var deduplicationID: String { get }
}

public protocol Timestamped {
    var modificationDate: Date { get }
}

public enum DeduplicationHasher {
    public static func normalize(_ content: String) -> String {
        content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func hash(_ content: String) -> String {
        let offsetBasis: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3

        var hash = offsetBasis
        for byte in normalize(content).utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        return String(format: "%016llx", hash)
    }

    public static func hash(parts: [String]) -> String {
        let serialized = parts
            .map { normalize($0) }
            .map { normalizedPart in
                "\(normalizedPart.utf8.count):\(normalizedPart)"
            }
            .joined(separator: "|")

        return hash(serialized)
    }
}
