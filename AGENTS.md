# Repository Guidelines

## Project Structure
- `TwinAct Field Companion/` contains the Swift source. Key modules:
  - `App/`: app entry point (`TwinAct_Field_CompanionApp.swift`), configuration, DI container.
  - `Features/`: SwiftUI feature screens (e.g., `Features/Discovery/DiscoveryView.swift`).
  - `Domain/`: domain models, parsers, writers, repositories, and services.
  - `Core/`: cross-cutting infrastructure (networking, persistence, security, utilities).
  - `AASClient/`: API models and client services for AAS endpoints.
  - `Assets.xcassets/` and `Resources/` for images, demo data, and localization stubs.
- `TwinAct Field Companion.xcodeproj/` is the Xcode project.

## Build, Run, and Development Commands
- Open in Xcode: `open "TwinAct Field Companion.xcodeproj"` and run the `TwinAct Field Companion` scheme.
- Build from CLI:
  - `xcodebuild -project "TwinAct Field Companion.xcodeproj" -scheme "TwinAct Field Companion" -configuration Debug build`
- Clean build:
  - `xcodebuild -project "TwinAct Field Companion.xcodeproj" -scheme "TwinAct Field Companion" clean build`

## Coding Style & Naming Conventions
- SwiftUI + Swift Concurrency (async/await) style; prefer clear, small types over monolithic views.
- Indentation: 4 spaces; keep `// MARK:` sections consistent with existing files.
- Naming: PascalCase for types/files (`AssetService.swift`), camelCase for methods/properties.
- Keep module boundaries: UI in `Features`, domain logic in `Domain`, infrastructure in `Core`.

## Testing Guidelines
- No XCTest target is configured; `xcodebuild -list` shows only the app target.
- Lightweight in-app tests exist in `Core/Utilities/AASIdentifierEncodingTests.swift`.
  - Example: call `AASIdentifierEncodingTests.runAllTests()` from a debug-only path.
- If you add XCTest coverage, create a dedicated test target and mirror the folder structure.

## Commit & Pull Request Guidelines
- Commit history follows Conventional Commits (e.g., `feat: Add HTTP client...`).
- Keep commits scoped to one change and write imperative, descriptive subjects.
- No PR template is present; include a concise summary, testing notes, and screenshots for UI changes.

## Configuration & Assets
- App metadata lives in `TwinAct Field Companion/Info.plist`.
- Asset catalogs and demo content live in `Assets.xcassets/` and `Resources/DemoAssets/`.
