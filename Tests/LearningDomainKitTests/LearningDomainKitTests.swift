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

    func testQuizQuestionHashConsistentWithEqualityWhenIDsDiffer() {
        let questionA = QuizQuestion(
            question: "What is Swift?",
            options: ["Language", "Framework"],
            correctAnswerIndex: 0
        )
        var questionB = questionA
        questionB.id = UUID()

        XCTAssertEqual(questionA, questionB)
        XCTAssertEqual(questionA.hashValue, questionB.hashValue)
        XCTAssertEqual(Set([questionA, questionB]).count, 1)
    }

    func testLessonQuizHashConsistentWithEqualityWhenQuestionIDsDiffer() {
        let sharedQuizID = UUID()
        let questionA = QuizQuestion(
            question: "What is polymorphism?",
            options: ["OOP concept", "Database feature"],
            correctAnswerIndex: 0
        )
        var questionB = questionA
        questionB.id = UUID()

        let quizA = LessonQuiz(questions: [questionA], id: sharedQuizID, title: "Quiz")
        let quizB = LessonQuiz(questions: [questionB], id: sharedQuizID, title: "Quiz")

        XCTAssertEqual(quizA, quizB)
        XCTAssertEqual(quizA.hashValue, quizB.hashValue)
        XCTAssertEqual(Set([quizA, quizB]).count, 1)
    }

    func testQuizQuestionDecodeRejectsInvalidCorrectAnswerIndex() {
        let json = """
        {
          "question": "Question",
          "options": ["A", "B"],
          "correctAnswerIndex": 2
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode(QuizQuestion.self, from: json))
    }

    func testChunkTranscriptNeverExceedsMaxChunkWordCount() {
        let processor = LessonProcessor()
        let veryLongParagraph = Array(repeating: "word", count: 2_500).joined(separator: " ")
        let transcript = [veryLongParagraph, "short section"].joined(separator: "\n\n")

        let chunks = processor.chunkTranscript(transcript)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { wordCount(in: $0) <= 1_000 })
    }

    func testCalculateFlashcardsPerChunkScalesWithTranscriptSize() {
        let processor = LessonProcessor()
        let smallTranscript = Array(repeating: "word", count: 500).joined(separator: " ")
        let largeTranscript = Array(repeating: "word", count: 5_500).joined(separator: " ")

        let small = processor.calculateFlashcardsPerChunk(totalChunks: 5, transcript: smallTranscript)
        let large = processor.calculateFlashcardsPerChunk(totalChunks: 5, transcript: largeTranscript)

        XCTAssertGreaterThan(large, small)
        XCTAssertTrue((4...25).contains(small))
        XCTAssertTrue((4...25).contains(large))
    }

    func testCalculateFlashcardsPerChunkReturnsZeroForZeroChunks() {
        let processor = LessonProcessor()
        let result = processor.calculateFlashcardsPerChunk(totalChunks: 0, transcript: "words")
        XCTAssertEqual(result, 0)
    }

    func testDeckContentHashStableWithDuplicateQuestionsAndDifferentOrder() {
        let cardA = FlashCard(question: "Q", answer: "A1")
        let cardB = FlashCard(question: "Q", answer: "A2")
        let cardC = FlashCard(question: "Q", answer: "A1")

        let deckA = FlashCardDeck(title: "Deck", cards: [cardA, cardB, cardC])
        let deckB = FlashCardDeck(title: "Deck", cards: [cardB, cardC, cardA])

        XCTAssertEqual(deckA.contentHash, deckB.contentHash)
    }

    func testDeckContentHashAvoidsConcatenationCollision() {
        let deckA = FlashCardDeck(
            title: "Deck",
            cards: [FlashCard(question: "ab", answer: "c")]
        )
        let deckB = FlashCardDeck(
            title: "Deck",
            cards: [FlashCard(question: "a", answer: "bc")]
        )

        XCTAssertNotEqual(deckA.contentHash, deckB.contentHash)
    }

    func testLessonContentHashAvoidsConcatenationCollision() {
        let metadata = LessonMetadata(createdAt: Date())
        let lessonA = Lesson(
            title: "Lesson",
            objectives: ["obj"],
            sections: [LessonSection(heading: "h", content: "ab"), LessonSection(heading: "hc", content: "")],
            metadata: metadata,
            flashCards: []
        )
        let lessonB = Lesson(
            title: "Lesson",
            objectives: ["obj"],
            sections: [LessonSection(heading: "ha", content: "b"), LessonSection(heading: "hc", content: "")],
            metadata: metadata,
            flashCards: []
        )

        XCTAssertNotEqual(lessonA.contentHash, lessonB.contentHash)
    }

    func testLessonEqualityIncludesSectionsQuizMetadataAndFlashCards() {
        let lessonID = UUID()
        let metadata = LessonMetadata(createdAt: Date())
        let first = Lesson(
            title: "Lesson",
            objectives: ["Objective"],
            sections: [LessonSection(heading: "A", content: "Content A")],
            metadata: metadata,
            flashCards: [FlashCard(question: "Q1", answer: "A1")]
        )

        var second = Lesson(
            title: "Lesson",
            objectives: ["Objective"],
            sections: [LessonSection(heading: "B", content: "Content B")],
            metadata: metadata,
            flashCards: [FlashCard(question: "Q1", answer: "A1")]
        )

        var firstWithSharedID = first
        firstWithSharedID.id = lessonID
        second.id = lessonID

        XCTAssertNotEqual(firstWithSharedID, second)
    }

    func testLearningDomainKitVersionUsesSemVerFormat() {
        let parts = LearningDomainKitVersion.current.split(separator: ".")
        XCTAssertEqual(parts.count, 3)
        XCTAssertTrue(parts.allSatisfy { Int($0) != nil })
    }

    func testDeduplicationHasherNormalizesCaseAndWhitespace() {
        let first = DeduplicationHasher.hash("  Hello   World ")
        let second = DeduplicationHasher.hash("hello world")
        XCTAssertEqual(first, second)
    }

    func testMergeLessonsMergesObjectivesQuizAndMetadataDeterministically() {
        let earlyDate = Date(timeIntervalSince1970: 1_000)
        let lateDate = Date(timeIntervalSince1970: 9_999)
        let question = QuizQuestion(
            question: "Q1",
            options: ["A", "B"],
            correctAnswerIndex: 0
        )

        let lessonA = Lesson(
            title: "  ",
            objectives: ["Obj A", "Shared"],
            sections: [LessonSection(heading: "A", content: "First", wordCount: 20)],
            quiz: LessonQuiz(questions: [question], title: "Master Quiz"),
            metadata: LessonMetadata(
                sourceTranscript: nil,
                sourceAudioDuration: 50,
                totalWordCount: 20,
                createdAt: lateDate,
                difficulty: .beginner,
                sourceRecordingId: nil,
                transcriptPath: nil
            ),
            flashCards: [FlashCard(question: "Q", answer: "A")]
        )

        let lessonB = Lesson(
            title: "Merged Title",
            objectives: ["Shared", "Obj B"],
            sections: [LessonSection(heading: "B", content: "Second", wordCount: 30)],
            quiz: LessonQuiz(questions: [question], title: ""),
            metadata: LessonMetadata(
                sourceTranscript: "Transcript",
                sourceAudioDuration: 120,
                totalWordCount: 30,
                createdAt: earlyDate,
                difficulty: .advanced,
                sourceRecordingId: "rec-1",
                transcriptPath: "/tmp/transcript.txt"
            ),
            flashCards: [FlashCard(question: "Q", answer: "A")]
        )

        let merged = LessonProcessor().mergeLessons([lessonA, lessonB])

        XCTAssertEqual(merged.title, "Merged Title")
        XCTAssertEqual(merged.objectives, ["Obj A", "Shared", "Obj B"])
        XCTAssertEqual(merged.quiz?.title, "Master Quiz")
        XCTAssertEqual(merged.quiz?.questions.count, 1)
        XCTAssertEqual(merged.metadata.createdAt, earlyDate)
        XCTAssertEqual(merged.metadata.difficulty, .advanced)
        XCTAssertEqual(merged.metadata.totalWordCount, 50)
        XCTAssertEqual(merged.metadata.sourceAudioDuration, 120)
        XCTAssertEqual(merged.metadata.sourceTranscript, "Transcript")
        XCTAssertEqual(merged.metadata.sourceRecordingId, "rec-1")
        XCTAssertEqual(merged.metadata.transcriptPath, "/tmp/transcript.txt")
    }

    func testMergeLessonsUsesMetadataWordCountWhenSectionWordCountMissing() {
        let lessonA = Lesson(
            title: "A",
            objectives: [],
            sections: [LessonSection(heading: "A", content: "No count")],
            metadata: LessonMetadata(totalWordCount: 100, createdAt: Date()),
            flashCards: []
        )
        let lessonB = Lesson(
            title: "B",
            objectives: [],
            sections: [LessonSection(heading: "B", content: "No count")],
            metadata: LessonMetadata(totalWordCount: 200, createdAt: Date()),
            flashCards: []
        )

        let merged = LessonProcessor().mergeLessons([lessonA, lessonB])
        XCTAssertEqual(merged.metadata.totalWordCount, 300)
    }

    func testLessonProcessorRespectsCustomChunkSizeConfiguration() {
        let processor = LessonProcessor(maxChunkWordCount: 250)
        let transcript = Array(repeating: "word", count: 1_000).joined(separator: " ")

        let chunks = processor.chunkTranscript(transcript)

        XCTAssertGreaterThan(chunks.count, 1)
        XCTAssertTrue(chunks.allSatisfy { wordCount(in: $0) <= 250 })
    }

    func testFlashCardValidationCollectsExpectedIssues() {
        let card = FlashCard(
            question: "   ",
            answer: "",
            studySuccessCount: -1,
            studyFailCount: -5
        )

        let issues = card.validationIssues()

        XCTAssertEqual(issues.count, 4)
        XCTAssertTrue(issues.contains(where: { $0.path.hasSuffix(".question") }))
        XCTAssertTrue(issues.contains(where: { $0.path.hasSuffix(".answer") }))
        XCTAssertTrue(issues.contains(where: { $0.path.hasSuffix(".studySuccessCount") }))
        XCTAssertTrue(issues.contains(where: { $0.path.hasSuffix(".studyFailCount") }))
    }

    func testLessonValidationIsRecursive() {
        let invalidQuestion = QuizQuestion(
            question: "",
            options: ["Only one option"],
            correctAnswerIndex: 0
        )
        let invalidSection = LessonSection(
            heading: "",
            content: "",
            examples: ["ok", " "],
            startTime: 20,
            endTime: 10,
            wordCount: -1
        )

        let lesson = Lesson(
            title: "",
            objectives: ["ok", " "],
            sections: [invalidSection],
            quiz: LessonQuiz(questions: [invalidQuestion]),
            metadata: LessonMetadata(
                sourceAudioDuration: -3,
                totalWordCount: -10,
                createdAt: Date(),
                sourceRecordingId: " ",
                transcriptPath: " "
            ),
            flashCards: [FlashCard(question: " ", answer: " ")]
        )

        let issues = lesson.validationIssues()

        XCTAssertTrue(issues.count >= 10)
        XCTAssertTrue(issues.contains(where: { $0.path.contains(".sections[0].endTime") }))
        XCTAssertTrue(issues.contains(where: { $0.path.contains(".quiz.questions[0].options") }))
        XCTAssertTrue(issues.contains(where: { $0.path.contains(".metadata.totalWordCount") }))
        XCTAssertTrue(issues.contains(where: { $0.path.contains(".flashCards[0].question") }))
    }

    func testValidateThrowsFirstIssue() {
        let deck = FlashCardDeck(
            title: " ",
            cards: [FlashCard(question: "Q", answer: "A")]
        )

        XCTAssertThrowsError(try deck.validate()) { error in
            guard let issue = error as? LearningDomainValidationIssue else {
                XCTFail("Unexpected error type")
                return
            }
            XCTAssertEqual(issue.path, "FlashCardDeck.title")
        }
    }

    func testDeckContentHashStableAcrossAllCardPermutations() {
        let cards = [
            FlashCard(question: "What is A?", answer: "A"),
            FlashCard(question: "What is B?", answer: "B"),
            FlashCard(question: "What is C?", answer: "C")
        ]

        let baseHash = FlashCardDeck(title: "Deck", cards: cards).contentHash

        for permutation in permutations(of: cards) {
            let hash = FlashCardDeck(title: "Deck", cards: permutation).contentHash
            XCTAssertEqual(hash, baseHash)
        }
    }

    func testLessonContentHashNormalizesCaseAndWhitespace() {
        let metadata = LessonMetadata(createdAt: Date())
        let lessonA = Lesson(
            title: "  Lesson Title ",
            objectives: [" Objective 1 "],
            sections: [LessonSection(heading: "Heading", content: "Some   content")],
            metadata: metadata,
            flashCards: [FlashCard(question: "Question?", answer: "Answer")]
        )
        let lessonB = Lesson(
            title: "lesson title",
            objectives: ["objective 1"],
            sections: [LessonSection(heading: "heading", content: "some content")],
            metadata: metadata,
            flashCards: [FlashCard(question: "question?", answer: "answer")]
        )

        XCTAssertEqual(lessonA.contentHash, lessonB.contentHash)
    }

    func testPerformanceMergeFlashCardsLargeInput() {
        let processor = LessonProcessor()
        let lessons = (0..<20).map { lessonIndex in
            let cards = (0..<200).map { cardIndex in
                FlashCard(
                    question: "What is concept \(cardIndex % 120) in lesson \(lessonIndex % 3)?",
                    answer: "Answer \(cardIndex)"
                )
            }
            return Lesson(
                title: "Lesson \(lessonIndex)",
                objectives: [],
                sections: [],
                metadata: LessonMetadata(createdAt: Date()),
                flashCards: cards
            )
        }

        measure {
            _ = processor.mergeFlashCards(from: lessons)
        }
    }

    func testPerformanceChunkTranscriptLargeInput() {
        let processor = LessonProcessor(maxChunkWordCount: 500)
        let paragraph = Array(repeating: "word", count: 250).joined(separator: " ")
        let transcript = Array(repeating: paragraph, count: 120).joined(separator: "\n\n")

        measure {
            _ = processor.chunkTranscript(transcript)
        }
    }

    private func wordCount(in text: String) -> Int {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private func permutations<T>(of input: [T]) -> [[T]] {
        guard !input.isEmpty else {
            return [[]]
        }

        if input.count == 1 {
            return [input]
        }

        var result: [[T]] = []
        for index in input.indices {
            var remaining = input
            let selected = remaining.remove(at: index)
            for permutation in permutations(of: remaining) {
                result.append([selected] + permutation)
            }
        }

        return result
    }
}
