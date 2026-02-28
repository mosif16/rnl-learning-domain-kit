import Foundation

public struct FlashCardDeck: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var title: String
    public var createdAt: Date = Date()
    public var cards: [FlashCard]
    public var source: FlashCardDeckSource?
    public var lineage: ContentLineage?
    public var publicRecordID: String?

    public init(
        title: String,
        cards: [FlashCard],
        source: FlashCardDeckSource? = nil,
        lineage: ContentLineage? = nil,
        publicRecordID: String? = nil
    ) {
        self.title = title
        self.cards = cards
        self.source = source
        self.lineage = lineage
        self.publicRecordID = publicRecordID
    }

    public init(title: String, createdAt: Date, cards: [FlashCard], source: FlashCardDeckSource? = nil) {
        self.title = title
        self.createdAt = createdAt
        self.cards = cards
        self.source = source
    }

    public var isForked: Bool {
        lineage?.parentID != nil
    }

    public var isPublished: Bool {
        publicRecordID != nil
    }
}

extension FlashCardDeck: HashableContent {
    public var contentHash: String {
        let sortedCards = cards.sorted {
            if $0.question != $1.question {
                return $0.question < $1.question
            }

            return $0.answer < $1.answer
        }

        var parts = [title]
        for card in sortedCards {
            parts.append(card.question)
            parts.append(card.answer)
        }

        return DeduplicationHasher.hash(parts: parts)
    }

    public var deduplicationID: String {
        id.uuidString
    }
}

extension FlashCardDeck: Timestamped {
    public var modificationDate: Date {
        createdAt
    }
}

public struct FlashCardDeckSource: Codable, Hashable, Sendable {
    public var recordingId: String
    public var transcriptPath: String?
    public var lastRefreshedAt: Date?

    public init(
        recordingId: String,
        transcriptPath: String? = nil,
        lastRefreshedAt: Date? = nil
    ) {
        self.recordingId = recordingId
        self.transcriptPath = transcriptPath
        self.lastRefreshedAt = lastRefreshedAt
    }
}
