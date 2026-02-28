import Foundation

public final class LessonProcessor: Sendable {
    private let duplicateSimilarityThreshold: Double
    private let maxChunkWordCount: Int

    public init(
        duplicateSimilarityThreshold: Double = 0.85,
        maxChunkWordCount: Int = 1_000
    ) {
        precondition(
            (0...1).contains(duplicateSimilarityThreshold),
            "duplicateSimilarityThreshold must be between 0 and 1"
        )
        precondition(maxChunkWordCount > 0, "maxChunkWordCount must be greater than 0")

        self.duplicateSimilarityThreshold = duplicateSimilarityThreshold
        self.maxChunkWordCount = maxChunkWordCount
    }

    public func mergeFlashCards(from lessons: [Lesson]) -> [FlashCard] {
        let allFlashCards = lessons.flatMap(\ .flashCards)

        var uniqueFlashCards: [FlashCard] = []
        var seenExactNormalizedQuestions = Set<String>()
        var seenQuestionBuckets: [String: [String]] = [:]

        for card in allFlashCards {
            let normalizedQuestion = normalizeForComparison(card.question)
            if normalizedQuestion.isEmpty {
                continue
            }

            if seenExactNormalizedQuestions.contains(normalizedQuestion) {
                continue
            }

            let bucketKey = duplicateBucketKey(for: normalizedQuestion)
            let candidates = seenQuestionBuckets[bucketKey] ?? []

            let isDuplicate = candidates.contains {
                jaccardSimilarity(normalizedQuestion, $0) >= duplicateSimilarityThreshold
            }

            if !isDuplicate {
                seenExactNormalizedQuestions.insert(normalizedQuestion)
                seenQuestionBuckets[bucketKey, default: []].append(normalizedQuestion)
                uniqueFlashCards.append(card)
            }
        }

        return uniqueFlashCards
    }

    public func estimateDurationInMinutes(from transcript: String) -> Int {
        let estimatedMinutes = max(1, wordCount(in: transcript) / 150)
        return max(5, estimatedMinutes)
    }

    public func calculateFlashcardsPerChunk(totalChunks: Int, transcript: String? = nil) -> Int {
        guard totalChunks > 0 else {
            return 0
        }

        let minPerChunk = 4
        let maxPerChunk = 25
        let defaultPerChunk = 12

        guard let transcript, !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return defaultPerChunk
        }

        let transcriptWordCount = wordCount(in: transcript)
        guard transcriptWordCount > 0 else {
            return defaultPerChunk
        }

        let estimatedTotalCards = min(120, max(12, transcriptWordCount / 110))
        let perChunk = Int(ceil(Double(estimatedTotalCards) / Double(totalChunks)))
        return min(maxPerChunk, max(minPerChunk, perChunk))
    }

    public func chunkTranscript(_ transcript: String) -> [String] {
        if wordCount(in: transcript) <= maxChunkWordCount {
            return [transcript]
        }

        var chunks = chunkByParagraphs(transcript)

        if chunks.count < 2 || hasOversizedChunk(chunks) {
            chunks = chunkBySentences(transcript)
        }

        if chunks.isEmpty || hasOversizedChunk(chunks) {
            chunks = chunkByWords(transcript)
        }

        return chunks.filter { !$0.isEmpty }
    }

    public func mergeLessons(_ lessons: [Lesson]) -> Lesson {
        guard !lessons.isEmpty else {
            return Lesson(
                title: "Empty Lesson",
                objectives: [],
                sections: [],
                quiz: nil,
                metadata: LessonMetadata(
                    sourceTranscript: nil,
                    sourceAudioDuration: nil,
                    totalWordCount: 0,
                    createdAt: Date(),
                    difficulty: .beginner
                )
            )
        }

        let title = lessons.compactMap { nonEmptyTrimmed($0.title) }.first ?? lessons[0].title
        let objectives = uniquePreservingOrder(
            lessons.flatMap(\ .objectives).compactMap(nonEmptyTrimmed)
        )
        let allSections = lessons.flatMap(\ .sections)
        let allFlashCards = mergeFlashCards(from: lessons)
        let allQuestions = uniquePreservingOrder(
            lessons
                .compactMap(\ .quiz)
                .flatMap(\ .questions)
        )
        let quizTitle = lessons
            .compactMap(\ .quiz)
            .compactMap { nonEmptyTrimmed($0.title) }
            .first
            ?? ""
        let quiz = allQuestions.isEmpty ? nil : LessonQuiz(questions: allQuestions, title: quizTitle)

        let sectionWordCount = allSections.compactMap(\ .wordCount).reduce(0, +)
        let metadataWordCount = lessons.compactMap(\ .metadata.totalWordCount).reduce(0, +)
        let mergedWordCount: Int? = {
            if sectionWordCount > 0 {
                return sectionWordCount
            }

            if metadataWordCount > 0 {
                return metadataWordCount
            }

            return 0
        }()
        let metadata = LessonMetadata(
            sourceTranscript: firstNonEmpty(
                lessons.compactMap(\ .metadata.sourceTranscript)
            ),
            sourceAudioDuration: lessons.compactMap(\ .metadata.sourceAudioDuration).max(),
            totalWordCount: mergedWordCount,
            createdAt: lessons.map(\ .metadata.createdAt).min() ?? Date(),
            difficulty: mergedDifficulty(from: lessons.compactMap(\ .metadata.difficulty)),
            sourceRecordingId: firstNonEmpty(
                lessons.compactMap(\ .metadata.sourceRecordingId)
            ),
            transcriptPath: firstNonEmpty(
                lessons.compactMap(\ .metadata.transcriptPath)
            )
        )

        return Lesson(
            title: title,
            objectives: objectives,
            sections: allSections,
            quiz: quiz,
            metadata: metadata,
            flashCards: allFlashCards
        )
    }

    private func normalizeForComparison(_ text: String) -> String {
        let stopWords: Set<String> = [
            "the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could",
            "should", "may", "might", "must", "can", "this", "that", "these",
            "those", "what", "which", "who", "whom", "how", "when", "where", "why",
            "of", "at", "by", "for", "with", "about", "to", "from", "in", "on"
        ]

        let words = text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }

        return words.joined(separator: " ")
    }

    private func jaccardSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.components(separatedBy: " ").filter { !$0.isEmpty })
        let words2 = Set(text2.components(separatedBy: " ").filter { !$0.isEmpty })

        guard !words1.isEmpty || !words2.isEmpty else {
            return 0
        }

        let intersection = words1.intersection(words2).count
        let union = words1.union(words2).count
        return Double(intersection) / Double(union)
    }

    private func duplicateBucketKey(for normalizedText: String) -> String {
        let tokens = normalizedText
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .sorted()

        guard !tokens.isEmpty else {
            return "__empty__"
        }

        return tokens.prefix(2).joined(separator: "|")
    }

    private func chunkByParagraphs(_ transcript: String) -> [String] {
        let paragraphs = transcript.components(separatedBy: "\n\n")

        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentWordCount = 0

        for paragraph in paragraphs {
            let paragraphWordCount = wordCount(in: paragraph)
            guard paragraphWordCount > 0 else {
                continue
            }

            if paragraphWordCount > maxChunkWordCount {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.joined(separator: "\n\n"))
                    currentChunk = []
                    currentWordCount = 0
                }

                chunks.append(contentsOf: chunkByWords(paragraph))
                continue
            }

            if !currentChunk.isEmpty && currentWordCount + paragraphWordCount > maxChunkWordCount {
                chunks.append(currentChunk.joined(separator: "\n\n"))
                currentChunk = [paragraph]
                currentWordCount = paragraphWordCount
            } else {
                currentChunk.append(paragraph)
                currentWordCount += paragraphWordCount
            }

            if currentWordCount >= maxChunkWordCount {
                chunks.append(currentChunk.joined(separator: "\n\n"))
                currentChunk = []
                currentWordCount = 0
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: "\n\n"))
        }

        return chunks
    }

    private func chunkBySentences(_ transcript: String) -> [String] {
        let delimiters: Set<Character> = [".", "!", "?", ":", ";", "\n"]
        var sentences: [String] = []
        var currentSentence = ""

        var index = transcript.startIndex
        while index < transcript.endIndex {
            let character = transcript[index]
            currentSentence.append(character)

            if delimiters.contains(character) {
                let next = transcript.index(after: index)
                let shouldBreak = next == transcript.endIndex || transcript[next].isWhitespace
                if shouldBreak {
                    sentences.append(currentSentence)
                    currentSentence = ""
                }
            }

            index = transcript.index(after: index)
        }

        if !currentSentence.isEmpty {
            sentences.append(currentSentence)
        }

        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentWordCount = 0

        for sentence in sentences {
            let sentenceWordCount = wordCount(in: sentence)
            guard sentenceWordCount > 0 else {
                continue
            }

            if sentenceWordCount > maxChunkWordCount {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.joined(separator: " "))
                    currentChunk = []
                    currentWordCount = 0
                }

                chunks.append(contentsOf: chunkByWords(sentence))
                continue
            }

            if !currentChunk.isEmpty && currentWordCount + sentenceWordCount > maxChunkWordCount {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = [sentence]
                currentWordCount = sentenceWordCount
            } else {
                currentChunk.append(sentence)
                currentWordCount += sentenceWordCount
            }

            if currentWordCount >= maxChunkWordCount {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = []
                currentWordCount = 0
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }

        return chunks
    }

    private func chunkByWords(_ transcript: String) -> [String] {
        let words = transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var chunks: [String] = []
        var currentChunk: [String] = []

        for word in words {
            currentChunk.append(word)
            if currentChunk.count >= maxChunkWordCount {
                chunks.append(currentChunk.joined(separator: " "))
                currentChunk = []
            }
        }

        if !currentChunk.isEmpty {
            chunks.append(currentChunk.joined(separator: " "))
        }

        return chunks
    }

    private func wordCount(in text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    private func hasOversizedChunk(_ chunks: [String]) -> Bool {
        chunks.contains { wordCount(in: $0) > maxChunkWordCount }
    }

    private func firstNonEmpty(_ values: [String]) -> String? {
        values.compactMap(nonEmptyTrimmed).first
    }

    private func nonEmptyTrimmed(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func uniquePreservingOrder<T: Hashable>(_ values: [T]) -> [T] {
        var seen = Set<T>()
        var result: [T] = []

        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }

        return result
    }

    private func mergedDifficulty(from difficulties: [LessonMetadata.LessonDifficulty]) -> LessonMetadata.LessonDifficulty? {
        guard !difficulties.isEmpty else {
            return nil
        }

        return difficulties.max(by: { difficultyScore(for: $0) < difficultyScore(for: $1) })
    }

    private func difficultyScore(for difficulty: LessonMetadata.LessonDifficulty) -> Int {
        switch difficulty {
        case .beginner:
            return 1
        case .intermediate:
            return 2
        case .advanced:
            return 3
        }
    }
}
