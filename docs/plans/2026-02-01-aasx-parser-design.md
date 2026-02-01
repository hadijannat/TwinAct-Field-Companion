# AASX Parser Design

**Date:** 2026-02-01
**Status:** Approved
**Author:** Claude + Aero

## Overview

Implement AASX file parser to extract embedded images (product images, manufacturer logos, certification markings) and documents from AASX packages. AASX files are ZIP archives following OPC conventions.

## Requirements

| Requirement | Decision |
|-------------|----------|
| Import methods | File picker (Files app, AirDrop) AND URL download |
| Storage location | App's Documents directory (persistent, user-accessible) |
| Content extraction | All extractable content (images, PDFs, other files) |
| Error handling | Interactive - prompt user when issues found |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      AASXImportManager                       │
│  (Coordinates import from file picker or URL download)       │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                       AASXParser                             │
│  1. Unzip AASX package to temp directory                     │
│  2. Parse .rels files to discover relationships              │
│  3. Parse XML manifests for asset metadata                   │
│  4. Extract content files based on relationships             │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                   AASXContentStore                           │
│  • Stores extracted content in Documents/<assetId>/          │
│  • Provides local file URLs for images, PDFs, etc.           │
│  • Manages cleanup of orphaned content                       │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Asset/DigitalNameplate Models                   │
│  • Updated to reference local file:// URLs                   │
│  • Fallback to remote URLs if local not available            │
└─────────────────────────────────────────────────────────────┘
```

## Standards & Libraries

**AASX/OPC Standards:**
- OPC (Open Packaging Conventions) - ISO/IEC 29500-2
- Asset Administration Shell spec from IDTA (Industrial Digital Twin Association)

**Validated Libraries:**

| Component | Library | Purpose |
|-----------|---------|---------|
| ZIP Handling | **ZIPFoundation** | Industry-standard Swift ZIP library |
| XML Parsing | **XMLCoder** | Codable-compliant XML parsing |
| JSON Parsing | Foundation's **JSONDecoder** | For AAS JSON payloads |
| File Management | **FileManager** | Apple's native file system APIs |

**SPM Dependencies:**
```swift
.package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
.package(url: "https://github.com/CoreOffice/XMLCoder.git", from: "0.17.0")
```

## Parsing Flow

```
User selects file/URL
        │
        ▼
┌───────────────────┐
│ Download/Copy to  │
│ temp directory    │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐     ┌─────────────────────────┐
│ Unzip with        │────▶│ Parse [Content_Types].xml│
│ ZIPFoundation     │     │ (discover part types)    │
└─────────┬─────────┘     └─────────────────────────┘
          │
          ▼
┌───────────────────┐     ┌─────────────────────────┐
│ Parse _rels/.rels │────▶│ Build relationship map   │
│ (root relations)  │     │ (source → target parts)  │
└─────────┬─────────┘     └─────────────────────────┘
          │
          ▼
┌───────────────────┐
│ Parse AAS XML/JSON│──┐
│ manifests         │  │  Issues found?
└───────────────────┘  │       │
                       │       ▼
                       │  ┌─────────────┐
                       │  │ Prompt user │
                       │  │ Continue?   │
                       │  └─────────────┘
          │
          ▼
┌───────────────────┐
│ Copy content to   │
│ Documents/<id>/   │
└─────────┬─────────┘
          │
          ▼
┌───────────────────┐
│ Return AASXResult │
│ with local URLs   │
└───────────────────┘
```

## Data Structures

```swift
/// Result of parsing an AASX package
struct AASXParseResult {
    let assetId: String
    let metadata: AASXMetadata
    let extractedContent: ExtractedContent
    let warnings: [AASXWarning]
}

/// Extracted content with local file URLs
struct ExtractedContent {
    let thumbnail: URL?
    let productImages: [URL]
    let manufacturerLogo: URL?
    let certificationMarkings: [URL]
    let documents: [ExtractedDocument]
}

struct ExtractedDocument {
    let title: String
    let localURL: URL
    let mimeType: String
    let category: DocumentCategory
}

enum DocumentCategory {
    case manual
    case certificate
    case datasheet
    case other
}
```

## Storage Structure

```
Documents/
└── AASXContent/
    └── <assetId>/
        ├── manifest.json          # Cached metadata
        ├── thumbnail.jpg          # Primary asset thumbnail
        ├── images/
        │   ├── product_001.png    # Product renderings
        │   ├── product_002.png
        │   └── logo.png           # Manufacturer logo
        ├── markings/
        │   ├── ce_marking.png     # Certification marks
        │   └── ul_marking.png
        └── documents/
            ├── manual_en.pdf
            ├── datasheet.pdf
            └── certificate.pdf
```

## Content Store API

```swift
final class AASXContentStore {
    static let shared = AASXContentStore()

    func store(_ result: AASXParseResult) throws -> URL
    func thumbnailURL(for assetId: String) -> URL?
    func productImageURL(for assetId: String) -> URL?
    func logoURL(for assetId: String) -> URL?
    func documents(for assetId: String) -> [ExtractedDocument]
    func deleteContent(for assetId: String) throws
    func totalStorageUsed() -> Int64
}
```

## Model Extensions

```swift
extension Asset {
    var resolvedThumbnailURL: URL? {
        if let localURL = AASXContentStore.shared.thumbnailURL(for: id) {
            return localURL
        }
        return thumbnailURL
    }
}

extension DigitalNameplate {
    var resolvedProductImage: URL? {
        if let assetId = assetId,
           let localURL = AASXContentStore.shared.productImageURL(for: assetId) {
            return localURL
        }
        return productImage
    }

    var resolvedManufacturerLogo: URL? {
        if let assetId = assetId,
           let localURL = AASXContentStore.shared.logoURL(for: assetId) {
            return localURL
        }
        return manufacturerLogo
    }
}
```

## UI Components

### Import Entry Points

1. **File Picker** - Using SwiftUI `.fileImporter()` with custom UTType for .aasx
2. **URL Download** - Text field + download button with progress indicator

### Integration

Add import menu to PassportView toolbar:
```swift
Menu {
    Button { showFileImporter = true } label: {
        Label("Import from Files", systemImage: "folder")
    }
    Button { showURLImporter = true } label: {
        Label("Import from URL", systemImage: "link")
    }
} label: {
    Image(systemName: "square.and.arrow.down")
}
```

### Interactive Error Handling

When issues found during import:
- Show alert with list of issues
- "Abort" button - cancel import
- "Continue Anyway" button - proceed with partial data

## Files to Create

| File | Purpose |
|------|---------|
| `Domain/Services/AASX/AASXParser.swift` | Core parsing logic using ZIPFoundation + XMLCoder |
| `Domain/Services/AASX/AASXContentStore.swift` | Local storage management |
| `Domain/Services/AASX/AASXImportManager.swift` | Import coordination |
| `Domain/Models/AASX/AASXModels.swift` | Data structures |
| `Domain/Models/AASX/OPCRelationship.swift` | OPC relationship parsing |
| `Core/UI/Components/AASXImportView.swift` | Import UI components |
| `Resources/aasx.uttype` | UTType declaration for .aasx files |

## Files to Modify

| File | Changes |
|------|---------|
| `Package.swift` | Add ZIPFoundation and XMLCoder dependencies |
| `Asset.swift` | Add `resolvedThumbnailURL` computed property |
| `DigitalNameplate.swift` | Add resolved image URL properties |
| `PassportView.swift` | Add import menu to toolbar |
| `AssetHeaderView.swift` | Use resolved URLs instead of direct URLs |
| `Info.plist` | Register .aasx UTType and document types |

## Testing Strategy

1. **Unit Tests** - Parse sample AASX files from user's Downloads folder
2. **Integration Tests** - Full import flow with mock file picker
3. **Edge Cases** - Corrupted ZIPs, missing relationships, unsupported formats
