# TwinAct Field Companion - Release Checklist

## Pre-Release Verification

### 1. Code Signing Setup
- [ ] Open project in Xcode
- [ ] Select "TwinAct Field Companion" target
- [ ] Go to Signing & Capabilities
- [ ] Select your Development Team
- [ ] Ensure "Automatically manage signing" is enabled
- [ ] Verify Bundle Identifier is unique (e.g., `com.yourcompany.twinact-field-companion`)

### 2. App Icon
- [ ] Add app icon images to `Assets.xcassets/AppIcon.appiconset/`
- [ ] Required sizes: 1024x1024 (App Store), 180x180 (iPhone), 167x167 (iPad Pro)
- [ ] Verify icon appears correctly in Xcode

### 3. Build Settings
- [ ] Set Display Name: "TwinAct Field"
- [ ] Set Version: 1.0.0
- [ ] Set Build: 1
- [ ] Verify iOS Deployment Target: 17.0+

### 4. Demo Mode Verification
This is critical for App Store review - reviewers won't have access to your AAS server.

- [ ] Launch app fresh (delete from simulator first)
- [ ] Complete onboarding flow
- [ ] Select "Enable Demo Mode" when prompted
- [ ] Verify demo banner appears
- [ ] Test all tabs with demo data:
  - [ ] Discover tab shows QR scanner (mock data on scan)
  - [ ] Passport tab shows demo asset nameplate
  - [ ] Technician tab shows demo service requests
  - [ ] Settings tab shows demo mode indicator

### 5. Feature Testing
- [ ] QR scanning works (camera permission prompt appears)
- [ ] AR mode launches (ARKit permission prompt appears)
- [ ] Voice commands work (microphone permission prompt appears)
- [ ] Chat responds with demo context
- [ ] Settings toggles work correctly
- [ ] Onboarding can be reset and replayed

### 6. Privacy & Permissions
Verify Info.plist has all required usage descriptions:
- [ ] `NSCameraUsageDescription` - QR scanning and AR
- [ ] `NSMicrophoneUsageDescription` - Voice commands
- [ ] `NSSpeechRecognitionUsageDescription` - Voice transcription

---

## App Store Connect Setup

### 1. Create App Record
- [ ] Log in to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Go to My Apps → + → New App
- [ ] Platform: iOS
- [ ] Name: TwinAct Field Companion
- [ ] Primary Language: English (U.S.)
- [ ] Bundle ID: Select from dropdown
- [ ] SKU: twinact-field-companion-ios

### 2. App Information
- [ ] Category: Business or Utilities
- [ ] Content Rights: Does not contain third-party content (or declare if it does)
- [ ] Age Rating: Complete questionnaire (likely 4+)

### 3. App Privacy
- [ ] Complete App Privacy questionnaire
- [ ] Data types collected:
  - Contact Info (if using auth)
  - Identifiers (device ID for analytics)
  - Usage Data (app interactions)
- [ ] Link to Privacy Policy URL

### 4. Screenshots
Required screenshots for each device size:
- [ ] 6.7" iPhone (1290 x 2796 px) - iPhone 15 Pro Max
- [ ] 6.5" iPhone (1284 x 2778 px) - iPhone 14 Plus
- [ ] 5.5" iPhone (1242 x 2208 px) - iPhone 8 Plus
- [ ] 12.9" iPad Pro (2048 x 2732 px)

Suggested screenshots:
1. QR Scanner / Discovery screen
2. Digital Passport / Nameplate view
3. Technician Console / Service Requests
4. AR Overlay (if showcasing)
5. Chat with Asset feature

### 5. App Description
```
TwinAct Field Companion - Your Digital Product Passport Reader

Access Asset Administration Shell (AAS) data directly from your iPhone or iPad. Scan QR codes to instantly retrieve digital nameplates, maintenance instructions, and sustainability information.

KEY FEATURES:

📱 QR Code Discovery
Scan IEC 61406 identification links to discover assets and their digital twins.

📋 Digital Product Passport
View standardized product information including manufacturer details, specifications, and carbon footprint data.

🔧 Technician Tools
Create and manage service requests, access maintenance instructions, and monitor time-series sensor data.

🥽 AR Overlays
Visualize sensor data and maintenance procedures in augmented reality.

🎤 Voice Commands
Hands-free operation for field technicians - create service requests and navigate the app by voice.

💬 Chat with Asset
Ask questions about your asset and get answers grounded in its documentation.

📴 Offline Ready
Works without network connectivity - changes sync automatically when back online.

DEMO MODE:
Try all features without connecting to a server. Perfect for evaluation and training.

STANDARDS COMPLIANCE:
- Asset Administration Shell API v3
- IDTA Submodel Templates (Digital Nameplate, Carbon Footprint, Service Request, etc.)
- IEC 61406 Identification Links
```

### 6. Review Notes for Apple
```
DEMO MODE INSTRUCTIONS:

This app connects to industrial Asset Administration Shell (AAS) servers.
Since you won't have access to our production servers, please use Demo Mode:

1. Launch the app
2. Complete the 5-page onboarding
3. When prompted, tap "Enable Demo Mode"
4. All features will work with bundled sample data

Demo Mode can also be enabled/disabled in Settings at any time.

No login credentials are required in Demo Mode.
```

---

## Build & Upload

### 1. Archive Build
```bash
# In Xcode:
# Product → Archive
# Or via command line:
xcodebuild -scheme "TwinAct Field Companion" \
  -configuration Release \
  -archivePath build/TwinAct.xcarchive \
  archive
```

### 2. Upload to App Store Connect
- [ ] In Xcode Organizer, select the archive
- [ ] Click "Distribute App"
- [ ] Select "App Store Connect"
- [ ] Choose "Upload"
- [ ] Follow prompts (signing, entitlements)

### 3. TestFlight (Recommended First)
- [ ] In App Store Connect, go to TestFlight
- [ ] Wait for build processing (10-30 minutes)
- [ ] Add internal testers
- [ ] Test on real devices before App Store submission

---

## Final Submission

- [ ] Select build in App Store Connect
- [ ] Complete all required metadata
- [ ] Submit for Review
- [ ] Monitor for review feedback (typically 24-48 hours)

---

## Post-Release

- [ ] Monitor crash reports in Xcode Organizer
- [ ] Respond to user reviews
- [ ] Plan version 1.1 based on feedback
