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
- `Domain/Services/AASX/AASXPassportExtractor.swift` - Extracts passport data from AAS JSON
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
- 3D CAD models (USDZ, OBJ, STL, STEP, IGES)
- AAS JSON structure

### Passport Data Extraction
```swift
// Extract passport data from AASX
let extractor = AASXPassportExtractor.shared
if let data = extractor.extractPassportData(for: assetId) {
    // data.nameplate - DigitalNameplate from AASX
    // data.carbonFootprint - CarbonFootprint from AASX
    // data.technicalData - TechnicalDataSummary from AASX
    // data.documents - [Document] from AASX
}
```

## Passport Module

The Passport view displays Digital Product Passport information with three tabs for different content views.

### Architecture

```
Features/Passport/
├── PassportView.swift              # Main view with tab navigation
├── PassportViewModel.swift         # State management, API/demo data
├── PassportTab.swift               # Tab enum (overview, content, structure)
├── AssetHeaderView.swift           # Product image, name, manufacturer
└── Components/
    ├── NameplateCardView.swift     # Digital nameplate display
    ├── CarbonFootprintView.swift   # Sustainability data
    ├── DocumentListView.swift      # Document list with previews
    ├── TechnicalDataSummaryView.swift  # Technical properties
    ├── AASXImageGalleryView.swift  # Image grid with categories
    ├── CADModelSection.swift       # 3D model viewer (QuickLook/SceneKit)
    ├── ExtractedDocumentListView.swift # PDF thumbnails, page count
    ├── AASXFileBrowserView.swift   # Package file tree explorer
    └── AASJSONExplorerView.swift   # Collapsible JSON tree viewer
```

### Tabs

| Tab | Description |
|-----|-------------|
| **Overview** | Nameplate, Carbon Footprint, Documents, Technical Data cards |
| **Content** | Image gallery, document list with thumbnails, 3D CAD models |
| **Structure** | AASX file browser, AAS JSON tree explorer |

### Data Precedence

When AASX data is available, it takes precedence over API/demo data:
```swift
// AssetHeaderView prefers AASX nameplate
AssetHeaderView(
    asset: viewModel.asset,
    nameplate: aasxPassportData?.nameplate,
    assetIdForImages: effectiveAASXAssetId
)

// Cards prefer AASX data, fall back to ViewModel
if let nameplate = aasxPassportData?.nameplate ?? viewModel.digitalNameplate {
    NameplateCardView(nameplate: nameplate)
}
```

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
│   ├── CloudInference.swift    # Legacy cloud API client
│   └── Providers/              # Multi-provider system
│       ├── AIProviderModels.swift      # Provider types and config
│       ├── AIProviderManager.swift     # Provider lifecycle
│       ├── AnthropicProvider.swift     # Claude API
│       ├── OpenAIProvider.swift        # OpenAI API
│       ├── OpenRouterProvider.swift    # OpenRouter API
│       ├── OllamaProvider.swift        # Local Ollama
│       └── CustomEndpointProvider.swift # Custom endpoints
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

**Environment Variables (Legacy):**
- `TWINACT_GENAI_URL` - Override GenAI endpoint
- `GENAI_API_KEY` - API key for cloud inference

**Multi-Provider Configuration:**
Users can configure cloud providers via Settings > AI Assistant > Cloud Provider Settings:
- **Anthropic (Claude)** - Claude Opus 4, Sonnet 4, Haiku 3.5
- **OpenAI** - GPT-4o, GPT-4o Mini, O1
- **OpenRouter** - Access to 100+ models
- **Ollama** - Local models (no API key required)
- **Custom** - User-defined endpoints (OpenAI-compatible or Anthropic format)

API keys are stored securely in the iOS Keychain via `AIProviderKeyStorage`.

**Generation Options:**
```swift
GenerationOptions(
    maxTokens: 512,        // Max response length
    temperature: 0.7,      // 0.3 for factual, 0.7 for explanatory
    systemPrompt: "..."    // Custom system prompt
)
```

**Provider Access:**
```swift
// Access provider manager via DependencyContainer
let manager = DependencyContainer.shared.aiProviderManager

// Get active provider
let provider = manager.activeProvider()

// Test connection
let success = await manager.testConnection(for: .anthropic)

// Store API key securely
manager.storeAPIKey("sk-...", for: .anthropic)
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
