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
- Deterministic content hashing for dedupe workflows.
- Chunked transcripts never exceed configured word limits.
- Lesson merge behavior is deterministic for metadata and objectives.
- Explicit model validation API with structured issue paths.

## Validation API

Use validation before persisting or sending model payloads across boundaries:

- `validationIssues()` returns all issues with precise field paths.
- `validate()` throws the first `LearningDomainValidationIssue`.

Covered types include:

- `FlashCard`, `LessonSection`, `QuizQuestion`, `LessonQuiz`
- `LessonMetadata`, `ContentLineage`, `FlashCardDeckSource`
- `FlashCardDeck`, `Lesson`

## Versioning

This package uses semantic versioning via a local `VERSION` file and a bump script:

- Current version source of truth: `VERSION`
- Public code constant: `LearningDomainKitVersion.current`
- Automation script: `scripts/bump_version.sh`

Usage:

- Patch bump: `./scripts/bump_version.sh` or `./scripts/bump_version.sh patch`
- Minor bump: `./scripts/bump_version.sh minor`
- Major bump: `./scripts/bump_version.sh major`

Each run updates both:

- `VERSION`
- `Sources/LearningDomainKit/LearningDomainKitVersion.swift`

## Improvement Plan

- See `docs/IMPROVEMENT_PLAN.md` for completed hardening work and next steps.
