# PillMate

PillMate is a native SwiftUI medication companion for tracking doses, medication supply, and day-to-day health notes. The interface uses a soft, card-based visual style with custom character artwork for medication and health states.

## What is included

- **Today**: view scheduled doses, mark medication as taken, and keep supply counts in sync.
- **Records**: browse medication history by date and switch between Medication History and Health Journal.
- **Health Journal**: save mood, symptoms, blood pressure, and heart-rate entries independently of a medication dose.
- **Medicines**: manage active and past medicines, edit an existing medicine, restore an ended medicine, or permanently remove it.
- **SwiftData persistence**: medicine definitions, medication records, and health journal entries are stored locally.
- **Custom assets**: glass jar, yellow stars, mood and symptom characters, blood-pressure character, and heart artwork are included in the asset catalog.

## Requirements

- Xcode with the iOS 26.5 SDK (the current project deployment target is iOS 26.5).
- macOS with an iOS Simulator or a connected iPhone.

## Run locally

1. Open `PillMate.xcodeproj` in Xcode.
2. Select the **PillMate** scheme and an iOS Simulator (or a connected device).
3. Build and run with **⌘R**.

The app creates its SwiftData `ModelContainer` in `PillMate/App/PillMateApp.swift` and registers these models:

- `MedicineEntity`
- `MedicationRecordEntity`
- `HealthJournalEntryEntity`

## Project structure

```text
PillMate/
├── App/             App entry point and SwiftData container
├── Models/          SwiftData entities and medication value types
├── ViewModels/      Feature-level state and presentation logic
├── Views/           Today, Records, Medicines, Analysis, and Profile screens
├── Components/      Shared cards, buttons, colors, and character views
├── Services/        Persistence, analysis, and notification service abstractions
└── Assets.xcassets/ Character artwork and app icon assets
```

## Data behavior

Ending a medicine marks it inactive and keeps its existing medication history. **Delete forever** removes the medicine definition, while previously saved medication records remain available in Records. Inactive or permanently deleted medicines are not included in active Today medication lists.

## Development notes

- The project currently contains seeded sample data so the main flows can be previewed quickly.
- The notification service is currently an abstraction point; local notification scheduling still needs to be connected to the platform notification APIs.
- Future-date schedule generation is not yet a separate scheduling engine; Records displays saved records for the selected date.

## AI Assistant product requirements

- [Product and safety boundary](docs/assistant-product-safety-boundary.md)
- [Privacy, consent, and deletion draft](docs/privacy-consent-and-deletion-draft.md)
- [Normative question/status examples](docs/assistant-question-examples.json)
