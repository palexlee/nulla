# Nulla — AI Language Learning App

## What This Is

An iPhone app to learn Chinese, Swiss German, and German through AI-powered conversation and flashcards. Core loop: **Talk** (AI conversation) → **Remember** (flashcards from gaps) → **Repeat** (spaced repetition). Built natively in Swift/SwiftUI.

## Build Requirements

- **Xcode 16+** (uses `PBXFileSystemSynchronizedRootGroup` — new files in `Nulla/` are automatically included, no manual project.pbxproj edits needed)
- **iOS 26.5+ deployment target**
- **Foundation Models** (`AIService`) requires A17 Pro chip or later — gracefully degrades to no AI features on older devices
- Bundle ID: `PierreApple.Nulla`

## Architecture

### Tech Stack
| Concern | Technology |
|---|---|
| UI | SwiftUI |
| Persistence | SwiftData |
| On-device LLM | Apple Foundation Models (`FoundationModels` framework) |
| Translation | Apple Translation framework (`.translationTask` modifier) |
| OCR | VisionKit (`VNRecognizeTextRequest`) |
| Object detection | Vision (`VNClassifyImageRequest`) |
| Photo access | PhotosUI (`PhotosPicker`) |
| SRS algorithm | Custom FSRS-inspired implementation in `SRSService` |

### Key Constraint: Swiss German
Apple's Translation framework and Foundation Models do **not** support Swiss German (`de-CH`). Phase 4 will add Claude API cloud fallback for Swiss German conversation and translation. For now, Swiss German cards are added manually or via camera OCR only.

### Swift 6 Concurrency
The project has `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` — all types are implicitly `@MainActor`. Services use `async/await`. Do not add unnecessary `@MainActor` annotations.

### `PBXFileSystemSynchronizedRootGroup`
Xcode automatically picks up any `.swift` file placed under `Nulla/`. Never manually edit `project.pbxproj` to add source files.

## File Structure

```
Nulla/
├── NullaApp.swift              — @main entry, SwiftData modelContainer
├── ContentView.swift           — Root TabView, seeds default languages on first launch
│
├── Models/
│   ├── Language.swift          — @Model: code, displayName, flag, level, cards relationship
│   ├── FlashCard.swift         — @Model: word, translation, SRS state, source thumbnail
│   └── SRSState.swift          — Codable SRS state + CEFRLevel, CardSource, ReviewRating enums
│
├── Services/
│   ├── SRSService.swift        — Pure FSRS-inspired scheduling (schedule + preview interval)
│   ├── AIService.swift         — Foundation Models: example sentences + word curation from photos
│   └── OCRService.swift        — VisionKit: text recognition + object classification
│
└── Views/
    ├── Home/HomeView.swift     — Dashboard: language chips, due-card widget, stats, recent cards
    ├── Deck/DeckView.swift     — Card browser: search, source filter, delete, add/camera sheets
    ├── Review/ReviewView.swift — SRS session: flip card, Again/Hard/Good/Easy, completion summary
    ├── AddCard/AddCardView.swift — Manual add: auto-translation + AI example sentence generation
    └── Camera/CameraView.swift — Photo picker: OCR → AI-curated word list → select to add
```

## Data Model

```
Language (1) ──cascade──> (many) FlashCard
```

- `Language.code` values: `"zh-Hans"`, `"de"`, `"de-CH"` (extensible)
- `FlashCard.srsState: SRSState` — stored as Codable struct in SwiftData
- `FlashCard.sourceRaw: String` — backing store for `CardSource` enum (`.manual`, `.camera`, `.conversation`)
- `FlashCard.sourceThumbnailData: Data?` — 80×80 JPEG thumbnail from camera capture

## SRS Scheduling (SRSService)

Simplified FSRS. New cards get intervals of 10min / 1d / 3d / 7d for Again/Hard/Good/Easy. Reviewed cards multiply stability by a factor based on difficulty. Always call `SRSService.schedule(state:rating:)` and assign the result back to `card.srsState`.

`SRSService.nextIntervalDescription(for:rating:)` returns a preview string (e.g. "3d") shown on rating buttons before the user taps.

## AI Features (AIService)

`AIService.shared` is a `@MainActor` singleton using `LanguageModelSession`. It checks `SystemLanguageModel.default.availability == .available` before any call and silently returns `nil`/fallback if unavailable.

- `generateExampleSentence(word:languageCode:level:)` — called from `AddCardView` on button tap
- `curateWords(_:languageCode:level:count:)` — called from `CameraView` after OCR to pick the 3–5 most useful words

## Translation (AddCardView)

Uses SwiftUI `.translationTask(config)` modifier. Trigger by calling `config.invalidate()` after setting a new `TranslationSession.Configuration`. Source language = target language code (e.g. `zh-Hans`), target = `en`. The session is created lazily by the modifier.

## Adding a New Language

1. Add a seed entry in `ContentView.swift` `.task` block
2. Use a valid BCP-47 code (e.g. `"fr"`, `"ja"`)
3. If the language needs cloud AI (like Swiss German), wire up the Claude API in `AIService` in Phase 4

## Build Phases Roadmap

| Phase | Status | Description |
|---|---|---|
| 1 — Flashcards + Camera | **Done** | SwiftData, SRS review, manual add, OCR camera |
| 2 — Text Conversation | Planned | `LanguageModelSession` multi-turn chat, tap-to-define, word harvest |
| 3 — Voice | Planned | STT (`SFSpeechRecognizer`), TTS (`AVSpeechSynthesizer`), tone scoring |
| 4 — Swiss German + Onboarding | Planned | Claude API, dialect selector, level assessment, streak |

## Design System Rules

> All UI must go through `Theme.swift`. Never bypass it with inline values.

### Colors
- Use `Theme.*` for every color — no inline `Color(hex:)`, no `.red`, no `.gray`, no `.white` (exception: `Color.white` with explicit opacity on overlays, as in the due-hero button)
- New semantic colors belong in `Theme.swift`, not at the call site

### Typography
- Use `.manrope(size, weight)` (the `View` extension) for every text element
- Never use `.font(.body)`, `.font(.title)`, `.font(.system(...))`, or any system font style
- Refer to existing views for size/weight conventions: hero numbers are `(56, .heavy)`, section headings `(23, .heavy)`, body `(15, .semibold)`, labels `(11–13, .medium/.bold)`

### Corner Radii
- Use `Theme.rHero` (26), `Theme.rCard` (20), `Theme.rTile` (18), `Theme.rPill` (16)
- No magic numbers like `cornerRadius: 12` — pick the nearest token or add a named constant to `Theme`

### Shadows
- Shadows only on hero/primary-action cards, matching the pattern: `.shadow(color: Theme.green.opacity(0.22), radius: 18, y: 12)`
- No shadows on list rows, chips, or secondary tiles

### Spacing & Layout
- Outer scroll padding: `20`
- Section spacing: `16`
- Card inner padding: `22–24`
- Tile inner padding: `16`

### Component Patterns
- Chips/badges: `Capsule()` background, `Theme.mintChip`/`Theme.butter`/`Theme.lavender` fill, bold label
- Stat tiles: `RoundedRectangle(cornerRadius: Theme.rTile)`, tinted bg + fg pair from Theme
- Backgrounds: always `Theme.paper.ignoresSafeArea()` at the root `ZStack`

## Behavioral Guidelines

> These bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

Before implementing: state assumptions explicitly, and ask if uncertain. If multiple interpretations exist, present them — don't pick silently. If a simpler approach exists, say so. If something is unclear, stop and ask.

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked
- No abstractions for single-use code
- No "flexibility" that wasn't requested
- No error handling for impossible scenarios
- If 200 lines could be 50, rewrite it

### 3. Surgical Changes

Touch only what you must.

- Don't "improve" adjacent code, comments, or formatting
- Don't refactor things that aren't broken
- Match existing style, even if you'd do it differently
- If you notice unrelated dead code, mention it — don't delete it
- Remove imports/variables/functions that **your** changes made unused; leave pre-existing dead code alone

Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

Transform tasks into verifiable goals before starting. For multi-step tasks, state a brief plan with explicit verify steps. Clarifying questions come before implementation, not after mistakes.
