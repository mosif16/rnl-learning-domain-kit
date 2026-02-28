import Foundation

public struct FlashCard: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID = UUID()
    public var question: String
    public var answer: String
    public let tags: [String]?
    public let difficulty: LessonMetadata.LessonDifficulty?
    public let sectionReference: String?
    public var imageData: Data?
    public var aiExplanation: String?
    public var studySuccessCount: Int = 0
    public var studyFailCount: Int = 0

    public init(
        question: String,
        answer: String,
        tags: [String]? = nil,
        difficulty: LessonMetadata.LessonDifficulty? = nil,
        sectionReference: String? = nil,
        imageData: Data? = nil,
        aiExplanation: String? = nil,
        studySuccessCount: Int = 0,
        studyFailCount: Int = 0
    ) {
        self.question = question
        self.answer = answer
        self.tags = tags
        self.difficulty = difficulty
        self.sectionReference = sectionReference
        self.imageData = imageData
        self.aiExplanation = aiExplanation
        self.studySuccessCount = studySuccessCount
        self.studyFailCount = studyFailCount
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let id = Self.decodeUUIDIfPresent(container: container, forKey: .id) {
            self.id = id
        } else {
            self.id = UUID()
        }

        self.question = try container.decode(String.self, forKey: .question)
        self.answer = try container.decode(String.self, forKey: .answer)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.difficulty = try container.decodeIfPresent(LessonMetadata.LessonDifficulty.self, forKey: .difficulty)
        self.sectionReference = try container.decodeIfPresent(String.self, forKey: .sectionReference)
        self.imageData = try container.decodeIfPresent(Data.self, forKey: .imageData)
        self.aiExplanation = try container.decodeIfPresent(String.self, forKey: .aiExplanation)
        self.studySuccessCount = try container.decodeIfPresent(Int.self, forKey: .studySuccessCount) ?? 0
        self.studyFailCount = try container.decodeIfPresent(Int.self, forKey: .studyFailCount) ?? 0
    }

    private static func decodeUUIDIfPresent(container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> UUID? {
        if let uuidString = try? container.decode(String.self, forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        if let uuid = try? container.decode(UUID.self, forKey: key) {
            return uuid
        }

        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case question
        case answer
        case tags
        case difficulty
        case sectionReference
        case imageData
        case aiExplanation
        case studySuccessCount
        case studyFailCount
    }
}

public struct Lesson: Codable, Identifiable, Sendable {
    public var flashCards: [FlashCard]
    public var id: UUID = UUID()
    public var title: String
    public var objectives: [String]
    public var sections: [LessonSection]
    public var quiz: LessonQuiz?
    public var metadata: LessonMetadata

    public init(
        title: String,
        objectives: [String],
        sections: [LessonSection],
        quiz: LessonQuiz? = nil,
        metadata: LessonMetadata,
        flashCards: [FlashCard] = []
    ) {
        self.title = title
        self.objectives = objectives
        self.sections = sections
        self.quiz = quiz
        self.metadata = metadata
        self.flashCards = flashCards
    }

    public func sectionsInRange(_ range: Range<Int>) -> [LessonSection] {
        guard range.lowerBound >= 0, range.upperBound <= sections.count else {
            return []
        }

        return Array(sections[range])
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let id = Self.decodeUUIDIfPresent(container: container, forKey: .id) {
            self.id = id
        }

        self.title = (try? container.decode(String.self, forKey: .title)) ?? "Untitled Lesson"
        self.objectives = (try? container.decode([String].self, forKey: .objectives)) ?? []
        self.sections = (try? container.decode([LessonSection].self, forKey: .sections)) ?? []

        if let metadata = try? container.decode(LessonMetadata.self, forKey: .metadata) {
            self.metadata = metadata
        } else {
            self.metadata = LessonMetadata(
                sourceTranscript: nil,
                sourceAudioDuration: nil,
                totalWordCount: nil,
                createdAt: Date(),
                difficulty: nil
            )
        }

        self.quiz = try container.decodeIfPresent(LessonQuiz.self, forKey: .quiz)
        self.flashCards = (try? container.decode([FlashCard].self, forKey: .flashCards)) ?? []
    }

    private static func decodeUUIDIfPresent(container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> UUID? {
        if let uuidString = try? container.decode(String.self, forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        if let uuid = try? container.decode(UUID.self, forKey: key) {
            return uuid
        }

        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case objectives
        case sections
        case quiz
        case metadata
        case flashCards
    }
}

public struct LessonMetadata: Codable, Sendable, Hashable {
    public let sourceTranscript: String?
    public let sourceAudioDuration: TimeInterval?
    public let totalWordCount: Int?
    public let createdAt: Date
    public let difficulty: LessonDifficulty?
    public let sourceRecordingId: String?
    public let transcriptPath: String?

    public enum LessonDifficulty: String, Codable, Sendable {
        case beginner
        case intermediate
        case advanced
    }

    public init(
        sourceTranscript: String? = nil,
        sourceAudioDuration: TimeInterval? = nil,
        totalWordCount: Int? = nil,
        createdAt: Date,
        difficulty: LessonDifficulty? = nil,
        sourceRecordingId: String? = nil,
        transcriptPath: String? = nil
    ) {
        self.sourceTranscript = sourceTranscript
        self.sourceAudioDuration = sourceAudioDuration
        self.totalWordCount = totalWordCount
        self.createdAt = createdAt
        self.difficulty = difficulty
        self.sourceRecordingId = sourceRecordingId
        self.transcriptPath = transcriptPath
    }
}

public struct LessonSection: Codable, Identifiable, Sendable, Hashable {
    public var id: UUID = UUID()
    public let heading: String
    public let content: String
    public let examples: [String]?
    public let startTime: TimeInterval?
    public let endTime: TimeInterval?
    public let wordCount: Int?
    public let summary: String?
    public let transcriptSegment: String?

    public init(
        heading: String,
        content: String,
        examples: [String]? = nil,
        startTime: TimeInterval? = nil,
        endTime: TimeInterval? = nil,
        wordCount: Int? = nil,
        summary: String? = nil,
        transcriptSegment: String? = nil
    ) {
        self.heading = heading
        self.content = content
        self.examples = examples
        self.startTime = startTime
        self.endTime = endTime
        self.wordCount = wordCount
        self.summary = summary
        self.transcriptSegment = transcriptSegment
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let id = Self.decodeUUIDIfPresent(container: container, forKey: .id) {
            self.id = id
        } else {
            self.id = UUID()
        }

        self.heading = try container.decode(String.self, forKey: .heading)
        self.content = try container.decode(String.self, forKey: .content)

        if let rawExamples = try? container.decodeIfPresent([AnyDecodable].self, forKey: .examples) {
            let stringExamples = rawExamples.compactMap { $0.value as? String }
            self.examples = stringExamples.isEmpty ? nil : stringExamples
        } else {
            self.examples = try container.decodeIfPresent([String].self, forKey: .examples)
        }

        self.startTime = try container.decodeIfPresent(TimeInterval.self, forKey: .startTime)
        self.endTime = try container.decodeIfPresent(TimeInterval.self, forKey: .endTime)
        self.wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary)
        self.transcriptSegment = try container.decodeIfPresent(String.self, forKey: .transcriptSegment)
    }

    private static func decodeUUIDIfPresent(container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> UUID? {
        if let uuidString = try? container.decode(String.self, forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        if let uuid = try? container.decode(UUID.self, forKey: key) {
            return uuid
        }

        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case heading
        case content
        case examples
        case startTime
        case endTime
        case wordCount
        case summary
        case transcriptSegment
    }
}

private struct AnyDecodable: Decodable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            self.value = string
            return
        }

        if let int = try? container.decode(Int.self) {
            self.value = int
            return
        }

        if let double = try? container.decode(Double.self) {
            self.value = double
            return
        }

        if let bool = try? container.decode(Bool.self) {
            self.value = bool
            return
        }

        if let dictionary = try? container.decode([String: AnyDecodable].self) {
            self.value = dictionary
            return
        }

        if let array = try? container.decode([AnyDecodable].self) {
            self.value = array
            return
        }

        self.value = ()
    }
}

public struct LessonQuiz: Codable, Identifiable, Equatable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var title: String = ""
    public let questions: [QuizQuestion]

    public init(questions: [QuizQuestion], id: UUID = UUID(), title: String = "") {
        self.id = id
        self.title = title
        self.questions = questions
    }

    public static func == (lhs: LessonQuiz, rhs: LessonQuiz) -> Bool {
        lhs.questions == rhs.questions && lhs.id == rhs.id
    }
}

public struct QuizQuestion: Codable, Identifiable, Equatable, Sendable, Hashable {
    public var id: UUID = UUID()
    public var question: String
    public var options: [String]
    public var correctAnswerIndex: Int
    public var explanation: String?

    public init(
        question: String,
        options: [String],
        correctAnswerIndex: Int,
        explanation: String? = nil
    ) {
        self.question = question
        self.options = options
        self.correctAnswerIndex = correctAnswerIndex
        self.explanation = explanation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let id = Self.decodeUUIDIfPresent(container: container, forKey: .id) {
            self.id = id
        } else {
            self.id = UUID()
        }

        self.question = try container.decode(String.self, forKey: .question)
        self.options = try container.decode([String].self, forKey: .options)
        self.correctAnswerIndex = try container.decode(Int.self, forKey: .correctAnswerIndex)
        self.explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
    }

    public static func == (lhs: QuizQuestion, rhs: QuizQuestion) -> Bool {
        lhs.question == rhs.question &&
        lhs.options == rhs.options &&
        lhs.correctAnswerIndex == rhs.correctAnswerIndex &&
        lhs.explanation == rhs.explanation
    }

    private static func decodeUUIDIfPresent(container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> UUID? {
        if let uuidString = try? container.decode(String.self, forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }

        if let uuid = try? container.decode(UUID.self, forKey: key) {
            return uuid
        }

        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case question
        case options
        case correctAnswerIndex
        case explanation
    }
}

public enum Difficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
    case superHard = "Super Hard"

    public var id: String { rawValue }
    public var label: String { rawValue }
}

extension Lesson: HashableContent {
    public var contentHash: String {
        var contentString = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        contentString += objectives.sorted().joined()

        for section in sections {
            contentString += section.heading.lowercased()
            contentString += section.content.lowercased()
        }

        for card in flashCards.sorted(by: { $0.question < $1.question }) {
            contentString += card.question.lowercased()
        }

        return DeduplicationHasher.hash(contentString)
    }

    public var deduplicationID: String {
        id.uuidString
    }
}

extension Lesson: Timestamped {
    public var modificationDate: Date {
        metadata.createdAt
    }
}

extension Lesson: Equatable {
    public static func == (lhs: Lesson, rhs: Lesson) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.objectives == rhs.objectives
    }
}
