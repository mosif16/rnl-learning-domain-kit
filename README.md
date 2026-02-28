# LearningDomainKit

Reusable domain contracts for learning apps in the Apple ecosystem.

## Scope (Phase 1)

This first pass intentionally focuses on high-reuse, low-coupling contracts:

- Core lesson models: `Lesson`, `LessonSection`, `LessonMetadata`, `LessonQuiz`, `QuizQuestion`
- Flashcard models: `FlashCard`, `FlashCardDeck`, `FlashCardDeckSource`
- Feed lineage primitive: `ContentLineage`
- Shared model protocols: `HashableContent`, `Timestamped`
- Domain utility: `DeduplicationHasher`
- Core orchestration helper: `LessonProcessor`

## Why This First

These contracts are depended on by most feature modules (stores, AI generation, coaching, feed, sync), so extracting them first reduces migration risk and unlocks parallel framework work.

## Xcode Integration

Add package dependency in Xcode:

- File -> Add Package Dependencies...
- URL: `https://github.com/mosif16/rnl-learning-domain-kit`

## Current Guarantees

- Codable compatibility for core lesson and flashcard payloads.
- Tolerant decoding for model-generated JSON (missing IDs, missing lesson title).
- Stable content hashing for dedupe workflows.
