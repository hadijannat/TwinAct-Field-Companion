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
- **CoreML** for on-device LLM inference
- **NaturalLanguage** framework for embeddings (RAG)
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

## AI Chat Module

The AI Chat feature provides natural language queries about assets with a hybrid inference approach and RAG support.

### Architecture

```
Features/Chat/
├── ChatView.swift              # SwiftUI interface
├── ChatViewModel.swift         # State management
├── Inference/
│   ├── InferenceRouter.swift   # Routing strategy selection
│   ├── OnDeviceInference.swift # Core ML model inference
│   └── CloudInference.swift    # Cloud API client
├── RAG/
│   ├── DocumentIndexer.swift   # PDF text extraction & chunking
│   ├── EmbeddingModel.swift    # Apple NLEmbedding wrapper
│   ├── VectorStore.swift       # In-memory cosine similarity
│   └── ContextRetriever.swift  # Semantic search
└── Safety/
    └── SafetyPolicy.swift      # PII filtering, validation
```

### Inference Modes

| Mode | Description |
|------|-------------|
| `preferOnDevice` | Default. Core ML first, cloud fallback |
| `preferCloud` | Cloud first, on-device fallback |
| `onDeviceOnly` | Offline mode (no network) |
| `cloudOnly` | Cloud-only (requires API) |
| `adaptive` | Auto-selects based on query complexity |

### Configuration

**Environment Variables:**
- `TWINACT_GENAI_URL` - Override GenAI endpoint
- `GENAI_API_KEY` - API key for cloud inference

**Generation Options:**
```swift
GenerationOptions(
    maxTokens: 512,        // Max response length
    temperature: 0.7,      // 0.3 for factual, 0.7 for explanatory
    systemPrompt: "..."    // Custom system prompt
)
```

### RAG Pipeline

1. **Indexing**: PDFs extracted via `DocumentIndexer`, chunked into ~512 token segments
2. **Embedding**: Sentences vectorized via `NLEmbedding.sentenceEmbedding()`
3. **Retrieval**: Top-K chunks retrieved by cosine similarity (default K=5, threshold=0.3)
4. **Generation**: Context injected into prompt with source citations

### Safety Features

- **PII Filtering**: Redacts emails, phones, SSN, credit cards, API keys before cloud requests
- **Prompt Validation**: Detects injection attempts, dangerous instructions
- **Response Validation**: Blocks dangerous commands, industrial safety violations
- **Audit Trail**: `SafetyAudit` logs all safety events

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
