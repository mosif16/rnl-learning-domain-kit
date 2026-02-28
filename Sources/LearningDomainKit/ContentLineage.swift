import Foundation

public struct ContentLineage: Codable, Sendable, Hashable {
    public let originalID: UUID
    public let parentID: UUID?
    public let generation: Int
    public let forkedAt: Date?
    public let originalAuthorName: String?

    public init(
        originalID: UUID,
        parentID: UUID? = nil,
        generation: Int = 0,
        forkedAt: Date? = nil,
        originalAuthorName: String? = nil
    ) {
        self.originalID = originalID
        self.parentID = parentID
        self.generation = generation
        self.forkedAt = forkedAt
        self.originalAuthorName = originalAuthorName
    }

    public static func original(id: UUID) -> ContentLineage {
        ContentLineage(originalID: id, parentID: nil, generation: 0, forkedAt: nil)
    }

    public static func forked(
        from parent: ContentLineage,
        parentID: UUID,
        originalAuthorName: String?
    ) -> ContentLineage {
        ContentLineage(
            originalID: parent.originalID,
            parentID: parentID,
            generation: parent.generation + 1,
            forkedAt: Date(),
            originalAuthorName: originalAuthorName ?? parent.originalAuthorName
        )
    }
}
