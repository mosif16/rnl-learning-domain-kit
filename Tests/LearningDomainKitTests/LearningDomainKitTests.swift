import XCTest
@testable import LearningDomainKit

final class LearningDomainKitTests: XCTestCase {
    func testFlashCardDecodesWithoutID() throws {
        let json = """
        {
          "question": "What is Swift?",
          "answer": "A programming language"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(FlashCard.self, from: json)

        XCTAssertFalse(decoded.id.uuidString.isEmpty)
        XCTAssertEqual(decoded.question, "What is Swift?")
        XCTAssertEqual(decoded.answer, "A programming language")
    }

    func testLessonDecoderFallsBackForMissingTitle() throws {
        let json = """
        {
          "objectives": ["Understand basics"],
          "sections": [],
          "metadata": { "createdAt": "2026-02-28T00:00:00Z" }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Lesson.self, from: json)

        XCTAssertEqual(decoded.title, "Untitled Lesson")
        XCTAssertEqual(decoded.objectives, ["Understand basics"])
    }

    func testLessonSectionMixedExamplesDecodesOnlyStrings() throws {
        let json = """
        {
          "heading": "Section 1",
          "content": "Body",
          "examples": ["A", 2, true, "B"]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(LessonSection.self, from: json)

        XCTAssertEqual(decoded.examples ?? [], ["A", "B"])
    }

    func testFlashCardDeckFlagsAndLineage() {
        let rootID = UUID()
        let parentLineage = ContentLineage.original(id: rootID)
        let lineage = ContentLineage.forked(from: parentLineage, parentID: UUID(), originalAuthorName: "Author")

        let deck = FlashCardDeck(
            title: "Deck",
            cards: [FlashCard(question: "Q", answer: "A")],
            lineage: lineage,
            publicRecordID: "public-123"
        )

        XCTAssertTrue(deck.isForked)
        XCTAssertTrue(deck.isPublished)
        XCTAssertEqual(lineage.generation, 1)
        XCTAssertEqual(lineage.originalID, rootID)
    }

    func testContentHashStableAcrossDifferentIDs() {
        let card1 = FlashCard(question: "What is Swift?", answer: "Language")
        let card2 = FlashCard(question: "What is Swift?", answer: "Language")

        let deck1 = FlashCardDeck(title: "Deck", cards: [card1])
        let deck2 = FlashCardDeck(title: "Deck", cards: [card2])

        XCTAssertEqual(deck1.contentHash, deck2.contentHash)
        XCTAssertNotEqual(deck1.id, deck2.id)
    }

    func testLessonProcessorDeduplicatesNearIdenticalQuestions() {
        let processor = LessonProcessor()

        let lessonA = Lesson(
            title: "A",
            objectives: [],
            sections: [],
            metadata: LessonMetadata(createdAt: Date()),
            flashCards: [FlashCard(question: "What is photosynthesis?", answer: "A1")]
        )

        let lessonB = Lesson(
            title: "B",
            objectives: [],
            sections: [],
            metadata: LessonMetadata(createdAt: Date()),
            flashCards: [FlashCard(question: "What is photosynthesis?", answer: "A2")]
        )

        let merged = processor.mergeFlashCards(from: [lessonA, lessonB])
        XCTAssertEqual(merged.count, 1)
    }

    func testLessonProcessorChunksLargeTranscript() {
        let processor = LessonProcessor()
        let paragraph = Array(repeating: "word", count: 600).joined(separator: " ")
        let words = [paragraph, paragraph, paragraph, paragraph].joined(separator: "\n\n")

        let chunks = processor.chunkTranscript(words)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { !$0.isEmpty })
    }
}
