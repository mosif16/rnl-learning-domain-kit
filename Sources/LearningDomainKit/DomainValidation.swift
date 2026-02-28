import Foundation

public struct LearningDomainValidationIssue: Error, Equatable, Sendable, CustomStringConvertible {
    public let path: String
    public let message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }

    public var description: String {
        "\(path): \(message)"
    }
}

public protocol LearningDomainValidatable {
    func validationIssues(at path: String) -> [LearningDomainValidationIssue]
}

public extension LearningDomainValidatable {
    func validationIssues() -> [LearningDomainValidationIssue] {
        validationIssues(at: String(describing: Self.self))
    }

    func validate() throws {
        if let firstIssue = validationIssues().first {
            throw firstIssue
        }
    }
}

extension FlashCard: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).question", message: "must not be empty"))
        }

        if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).answer", message: "must not be empty"))
        }

        if studySuccessCount < 0 {
            issues.append(.init(path: "\(path).studySuccessCount", message: "must be greater than or equal to 0"))
        }

        if studyFailCount < 0 {
            issues.append(.init(path: "\(path).studyFailCount", message: "must be greater than or equal to 0"))
        }

        return issues
    }
}

extension LessonSection: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if heading.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).heading", message: "must not be empty"))
        }

        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).content", message: "must not be empty"))
        }

        if let startTime, startTime < 0 {
            issues.append(.init(path: "\(path).startTime", message: "must be greater than or equal to 0"))
        }

        if let endTime, endTime < 0 {
            issues.append(.init(path: "\(path).endTime", message: "must be greater than or equal to 0"))
        }

        if let startTime, let endTime, endTime < startTime {
            issues.append(.init(path: "\(path).endTime", message: "must be greater than or equal to startTime"))
        }

        if let wordCount, wordCount < 0 {
            issues.append(.init(path: "\(path).wordCount", message: "must be greater than or equal to 0"))
        }

        if let examples {
            for (index, example) in examples.enumerated() where example.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.init(path: "\(path).examples[\(index)]", message: "must not be empty"))
            }
        }

        return issues
    }
}

extension QuizQuestion: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).question", message: "must not be empty"))
        }

        if options.count < 2 {
            issues.append(.init(path: "\(path).options", message: "must contain at least 2 options"))
        }

        for (index, option) in options.enumerated() where option.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).options[\(index)]", message: "must not be empty"))
        }

        if !options.indices.contains(correctAnswerIndex) {
            issues.append(.init(
                path: "\(path).correctAnswerIndex",
                message: "must be within options index range 0..<\(options.count)"
            ))
        }

        return issues
    }
}

extension LessonQuiz: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if questions.isEmpty {
            issues.append(.init(path: "\(path).questions", message: "must not be empty"))
        }

        for (index, question) in questions.enumerated() {
            issues.append(contentsOf: question.validationIssues(at: "\(path).questions[\(index)]"))
        }

        return issues
    }
}

extension LessonMetadata: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if let sourceAudioDuration, sourceAudioDuration < 0 {
            issues.append(.init(path: "\(path).sourceAudioDuration", message: "must be greater than or equal to 0"))
        }

        if let totalWordCount, totalWordCount < 0 {
            issues.append(.init(path: "\(path).totalWordCount", message: "must be greater than or equal to 0"))
        }

        if let sourceRecordingId, sourceRecordingId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).sourceRecordingId", message: "must not be empty when provided"))
        }

        if let transcriptPath, transcriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).transcriptPath", message: "must not be empty when provided"))
        }

        return issues
    }
}

extension ContentLineage: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if generation < 0 {
            issues.append(.init(path: "\(path).generation", message: "must be greater than or equal to 0"))
        }

        return issues
    }
}

extension FlashCardDeckSource: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if recordingId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).recordingId", message: "must not be empty"))
        }

        if let transcriptPath, transcriptPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).transcriptPath", message: "must not be empty when provided"))
        }

        return issues
    }
}

extension FlashCardDeck: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).title", message: "must not be empty"))
        }

        if let source {
            issues.append(contentsOf: source.validationIssues(at: "\(path).source"))
        }

        if let lineage {
            issues.append(contentsOf: lineage.validationIssues(at: "\(path).lineage"))
        }

        for (index, card) in cards.enumerated() {
            issues.append(contentsOf: card.validationIssues(at: "\(path).cards[\(index)]"))
        }

        return issues
    }
}

extension Lesson: LearningDomainValidatable {
    public func validationIssues(at path: String) -> [LearningDomainValidationIssue] {
        var issues: [LearningDomainValidationIssue] = []

        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).title", message: "must not be empty"))
        }

        for (index, objective) in objectives.enumerated() where objective.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(path: "\(path).objectives[\(index)]", message: "must not be empty"))
        }

        for (index, section) in sections.enumerated() {
            issues.append(contentsOf: section.validationIssues(at: "\(path).sections[\(index)]"))
        }

        if let quiz {
            issues.append(contentsOf: quiz.validationIssues(at: "\(path).quiz"))
        }

        issues.append(contentsOf: metadata.validationIssues(at: "\(path).metadata"))

        for (index, card) in flashCards.enumerated() {
            issues.append(contentsOf: card.validationIssues(at: "\(path).flashCards[\(index)]"))
        }

        return issues
    }
}
