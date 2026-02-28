# LearningDomainKit Improvement Plan

Date: 2026-02-28
Owner: Framework Team

## Goals

1. Keep domain models safe and deterministic across modules.
2. Improve merge/chunk/dedupe behavior for real transcript workloads.
3. Make version bumps repeatable for every framework change.
4. Expand regression coverage before adding new feature kits on top.

## Phase 1 (Completed in this pass)

- [x] Fix `Hashable` and `Equatable` contract mismatches.
- [x] Validate quiz answer index during decode.
- [x] Guarantee transcript chunks respect `maxChunkWordCount`.
- [x] Replace placeholder flashcard-per-chunk logic with scaling logic.
- [x] Make flashcard deck hashing deterministic for duplicate questions.
- [x] Add local semantic version automation (`VERSION` + bump script + code constant).

## Phase 2 (Completed in this pass)

- [x] Make hashing robust against concatenation collisions using serialized parts.
- [x] Improve lesson merge behavior:
  - unique objectives preserving order
  - unique quiz questions
  - earliest `createdAt`
  - highest difficulty
  - first non-empty transcript/path/recording ids
  - fallback to metadata word counts if section counts are missing
- [x] Add configurable `LessonProcessor` thresholds with validated inputs.
- [x] Expand test suite for hashing, merge metadata rules, and custom chunk sizing.

## Phase 3 (Next)

- [x] Add model-level explicit validation API (`validate()` + typed errors) for ingestion boundaries.
- [x] Add performance tests for `mergeFlashCards` and `chunkTranscript` on long transcripts.
- [x] Add property-based tests for content hashing and dedupe normalization.
- [ ] Split package into two targets if needed:
  - `LearningDomainModels`
  - `LearningDomainProcessing`

## Release Workflow (Local)

1. Run tests: `swift test -c release`
2. Bump version:
   - patch: `./scripts/bump_version.sh patch`
   - minor: `./scripts/bump_version.sh minor`
   - major: `./scripts/bump_version.sh major`
3. Commit changes including `VERSION` and `LearningDomainKitVersion.swift`.
