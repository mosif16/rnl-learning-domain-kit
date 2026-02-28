import Foundation

public final class LessonProcessor: Sendable {
    private let duplicateSimilarityThreshold: Double = 0.85
    private let maxChunkWordCount = 1000

    public init() {}

    public func mergeFlashCards(from lessons: [Lesson]) -> [FlashCard] {
        let allFlashCards = lessons.flatMap(\ .flashCards)

        var uniqueFlashCards: [FlashCard] = []
        var seenNormalizedQuestions: [String] = []

        for card in allFlashCards {
            let normalizedQuestion = normalizeForComparison(card.question)

            let isDuplicate = seenNormalizedQuestions.contains {
                jaccardSimilarity(normalizedQuestion, $0) >= duplicateSimilarityThreshold
            }

            if !isDuplicate {
                seenNormalizedQuestions.append(normalizedQuestion)
                uniqueFlashCards.append(card)
            }
        }

        return uniqueFlashCards
    }

    public func estimateDurationInMinutes(from transcript: String) -> Int {
        let wordCount = transcript
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
        let estimatedMinutes = max(1, wordCount / 150)
        return max(5, estimatedMinutes)
    }

    public func calculateFlashcardsPerChunk(totalChunks: Int, transcript: String? = nil) -> Int {
        _ = totalChunks
        _ = transcript
        return 15
    }

    public func chunkTranscript(_ transcript: String) -> [String] {
        if transcript.count < 1000 {
            return [transcript]
        }

        var chunks = chunkByParagraphs(transcript)

        if chunks.count < 2 || (chunks.first?.count ?? 0) > 100_000 {
            chunks = chunkBySentences(transcript)
        }

        if chunks.isEmpty || (chunks.first?.count ?? 0) > 100_000 {
            chunks = chunkByWords(transcript)
        }

        return chunks
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

        let title = lessons[0].title
        let objectives = lessons[0].objectives
        let allSections = lessons.flatMap(\ .sections)
        let allFlashCards = mergeFlashCards(from: lessons)
        let allQuestions = lessons.compactMap(\ .quiz).flatMap(\ .questions)
        let quiz = allQuestions.isEmpty ? nil : LessonQuiz(questions: allQuestions)

        let totalWordCount = allSections.compactMap(\ .wordCount).reduce(0, +)
        let metadata = LessonMetadata(
            sourceTranscript: lessons[0].metadata.sourceTranscript,
            sourceAudioDuration: lessons[0].metadata.sourceAudioDuration,
            totalWordCount: totalWordCount,
            createdAt: Date(),
            difficulty: lessons[0].metadata.difficulty,
            sourceRecordingId: lessons[0].metadata.sourceRecordingId,
            transcriptPath: lessons[0].metadata.transcriptPath
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

    private func chunkByParagraphs(_ transcript: String) -> [String] {
        let paragraphs = transcript.components(separatedBy: "\n\n")

        var chunks: [String] = []
        var currentChunk: [String] = []
        var currentWordCount = 0

        for paragraph in paragraphs {
            let paragraphWordCount = paragraph
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .count

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
            let sentenceWordCount = sentence
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .count

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
}
