import Foundation

public protocol HashableContent {
    var contentHash: String { get }
    var deduplicationID: String { get }
}

public protocol Timestamped {
    var modificationDate: Date { get }
}

public enum DeduplicationHasher {
    public static func hash(_ content: String) -> String {
        let offsetBasis: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3

        var hash = offsetBasis
        for byte in content.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        return String(format: "%016llx", hash)
    }
}
