# CLAUDE.md - TwinAct Field Companion

## Project Overview

TwinAct Field Companion is an iOS app for field technicians working with Industrial Digital Twins. It provides:
- **Asset Discovery**: QR code scanning and manual lookup for AAS (Asset Administration Shell) assets
- **Digital Product Passport**: View nameplate, carbon footprint, documentation, and technical data
- **AASX Import**: Import AASX packages from files or URLs to view offline asset data
- **AI Chat Assistant**: Natural language queries about assets with RAG support
- **Voice Commands**: Hands-free operation for field work
- **AR Overlays**: Augmented reality visualization of asset data

## Architecture

```
TwinAct Field Companion/
├── App/                    # Entry point, DI container, configuration
├── Features/               # SwiftUI feature modules
│   ├── Discovery/          # QR scanning, asset lookup
│   ├── Passport/           # Digital Product Passport view
│   ├── Chat/               # AI assistant with RAG
│   ├── Voice/              # Speech recognition
│   ├── AR/                 # ARKit overlays
│   ├── JargonBuster/       # DPP term glossary
│   └── Settings/           # App configuration
├── Domain/                 # Business logic
│   ├── Models/             # Domain entities (Asset, DigitalNameplate, etc.)
│   │   └── AASX/           # AASX parsing models
│   └── Services/           # Domain services
│       └── AASX/           # AASX parser, content store, import manager
├── Core/                   # Cross-cutting infrastructure
│   ├── Networking/         # HTTP client
│   ├── Persistence/        # SwiftData, sync engine
│   ├── Security/           # Authentication
│   ├── UI/                 # Shared UI components
│   └── Utilities/          # Helpers
└── AASClient/              # AAS API client
```

## Key Technologies

- **SwiftUI** + Swift Concurrency (async/await)
- **SwiftData** for persistence
- **ZIPFoundation** for AASX extraction
- **XMLCoder** for OPC relationship parsing
- **ARKit** for augmented reality
- **Speech** framework for voice commands

## Build Commands

```bash
# Open in Xcode
open "TwinAct Field Companion.xcodeproj"

# Build from CLI
xcodebuild build -project "TwinAct Field Companion.xcodeproj" \
  -scheme "TwinAct Field Companion" \
  -destination 'platform=iOS Simulator,name=iPhone 17'

# Run unit tests
xcodebuild test -project "TwinAct Field Companion.xcodeproj" \
  -scheme "TwinAct Field Companion" \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:"TwinAct Field CompanionTests"

# Clean build
xcodebuild clean build -project "TwinAct Field Companion.xcodeproj" \
  -scheme "TwinAct Field Companion"
```

## AASX Parser Module

The AASX parser extracts embedded content from AASX packages (ZIP archives following OPC conventions):

### Files
- `Domain/Models/AASX/AASXModels.swift` - Data structures for parse results
- `Domain/Models/AASX/OPCRelationship.swift` - OPC relationship parser per ISO/IEC 29500-2
- `Domain/Services/AASX/AASXParser.swift` - Core extraction logic using ZIPFoundation
- `Domain/Services/AASX/AASXContentStore.swift` - Local storage for extracted content
- `Domain/Services/AASX/AASXImportManager.swift` - Coordinates file/URL imports
- `Core/UI/Components/AASXImportView.swift` - Import UI components

### Usage
```swift
// Import from file picker
let manager = AASXImportManager()
await manager.importFromFile(url)

// Import from URL
await manager.importFromURL("https://example.com/asset.aasx")

// Access extracted content
let thumbnailURL = AASXContentStore.shared.thumbnailURL(for: assetId)
let documents = AASXContentStore.shared.documents(for: assetId)
```

### Content Types Extracted
- Product images (thumbnails, full images)
- Manufacturer logos
- Certification markings (CE, UL, etc.)
- PDF documentation
- Technical data sheets

## Coding Conventions

- **Indentation**: 4 spaces
- **MARK sections**: Use `// MARK: -` for organization
- **Naming**: PascalCase for types, camelCase for properties/methods
- **Module boundaries**: UI in Features, logic in Domain, infrastructure in Core
- **Commits**: Conventional Commits format (`feat:`, `fix:`, `refactor:`, etc.)

## Key Patterns

### Dependency Injection
```swift
// Access shared services via DependencyContainer
let service = DependencyContainer.shared.glossaryService
```

### Asset URL Resolution
Models provide resolved URLs that prefer local AASX content over remote:
```swift
// Asset.resolvedThumbnailURL - prefers local, falls back to remote
// DigitalNameplate.resolvedProductImage(for:) - same pattern
```

### View Modifiers
```swift
// AASX file import
.aasxFileImporter(isPresented: $show, importManager: manager)
```

## Testing

- **Unit tests**: `TwinAct Field CompanionTests/` (37 tests)
- **UI tests**: `TwinAct Field CompanionUITests/`
- Run tests after any changes to AASX parsing or domain models

## Worktree Configuration

Worktrees are stored at: `~/.config/superpowers/worktrees/TwinAct-Field-Companion/`

## Bundle Identifiers

- **Main app**: `hadi.TwinAct-Field-Companion`
- **Display name**: "TwinAct Field"
