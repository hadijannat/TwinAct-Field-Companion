# TwinAct Field Companion - Testing Checklist

Run through this checklist to verify the app works correctly before submission.

## Prerequisites
- [ ] Xcode 15+ installed
- [ ] iOS 17+ Simulator available
- [ ] Signing configured (any team, even personal)

---

## 1. First Launch & Onboarding

### Fresh Install Test
1. Delete app from simulator if previously installed
2. Build and run (`Cmd+R`)
3. Verify onboarding appears automatically

### Onboarding Flow
- [ ] Page 1: "Discover Assets" with QR icon appears
- [ ] Page 2: "Digital Passport" appears after tap "Next"
- [ ] Page 3: "Technician Tools" appears
- [ ] Page 4: "AR Overlays" appears
- [ ] Page 5: "Voice & AI Assistant" appears
- [ ] "Get Started" button appears on page 5
- [ ] Tapping "Get Started" shows demo mode prompt
- [ ] "Enable Demo Mode" button works
- [ ] App transitions to main tab view

---

## 2. Demo Mode Verification

### Demo Banner
- [ ] Orange "Demo Mode" banner appears at top of relevant screens
- [ ] Banner shows "Using sample data" message

### Settings Toggle
- [ ] Open Settings tab
- [ ] Demo Mode toggle is ON
- [ ] Toggling OFF shows confirmation alert
- [ ] Toggling back ON works without issues

---

## 3. Tab Navigation

### Discover Tab
- [ ] Tab icon: QR viewfinder
- [ ] Camera permission prompt appears (tap Allow)
- [ ] QR scanner view displays
- [ ] "Manual Entry" button visible

### Passport Tab
- [ ] Tab icon: Tag
- [ ] Shows demo asset if in demo mode
- [ ] Or shows "No Asset Selected" empty state
- [ ] Demo nameplate card displays manufacturer info

### Technician Tab
- [ ] Tab icon: Wrench
- [ ] Service requests list appears (demo data)
- [ ] Tapping a request shows details
- [ ] "Create Request" button visible

### Settings Tab
- [ ] Tab icon: Gear
- [ ] All sections visible:
  - Demo Mode
  - Account
  - AI Assistant
  - Sync
  - Server Connection
  - Features
  - Storage
  - About
  - Advanced

---

## 4. Feature Testing

### QR Scanner (Discover Tab)
- [ ] Camera preview displays (may need physical device)
- [ ] Scanning overlay visible
- [ ] Torch button works (physical device only)
- [ ] Manual entry sheet opens

### Digital Passport (Passport Tab)
With demo asset loaded:
- [ ] Asset header shows name and ID
- [ ] Digital Nameplate card expands/collapses
- [ ] Carbon Footprint section visible
- [ ] Documents list appears
- [ ] "Chat with Asset" button visible

### Technician Console (Technician Tab)
- [ ] Service request list loads
- [ ] Filter/sort options work
- [ ] Request detail view shows:
  - Status badge
  - Priority indicator
  - Description
  - Notes section
- [ ] Create new request:
  - [ ] Form opens
  - [ ] All fields editable
  - [ ] Save creates request (in demo mode, local only)

### Settings
- [ ] AI Assistant toggle switches inference mode
- [ ] Clear Cache shows confirmation
- [ ] Clear Cache updates size display
- [ ] "Show Onboarding Again" resets onboarding flag
- [ ] Licenses view opens
- [ ] Privacy Policy view opens

---

## 5. Voice Commands (if testing on device)

- [ ] Voice button appears in Technician tab
- [ ] Tapping requests microphone permission
- [ ] Speech recognition activates
- [ ] Confirmation sheet appears for actions

---

## 6. AR Mode (if testing on device)

- [ ] AR button in Passport view
- [ ] Camera permission prompt (if not already granted)
- [ ] AR session initializes
- [ ] Plane detection works
- [ ] Overlays appear on detected surfaces

---

## 7. Chat with Asset

- [ ] Chat button in Passport view
- [ ] Chat view opens
- [ ] Text input field works
- [ ] Sending message shows response
- [ ] Demo mode uses sample documentation context

---

## 8. Offline Mode Simulation

1. Enable Airplane Mode on simulator
2. Verify app still functions:
   - [ ] Cached data displays
   - [ ] Creating service request queues locally
   - [ ] Offline banner appears
3. Disable Airplane Mode
4. Verify sync indicator appears briefly

---

## 9. Error States

### No Asset Selected
- [ ] Passport tab shows empty state
- [ ] "Scan an asset QR code" message
- [ ] "Load Demo Passport" button (in demo mode)

### Network Error (disconnect during operation)
- [ ] Error banner appears
- [ ] Retry button functional

---

## 10. UI Tests (Xcode)

Run the UI test suite:
```
Cmd+U (or Product → Test)
```

- [ ] All UI tests pass
- [ ] No crashes during tests

---

## 11. Unit Tests (In-App, DEBUG only)

In Settings → Advanced → Diagnostics:
- [ ] "Run All Tests" button visible
- [ ] Tests execute without crashes
- [ ] Results summary displayed

---

## Final Verification

- [ ] No crashes during any test
- [ ] No console errors (check Xcode debug output)
- [ ] App responds to orientation changes
- [ ] Dark mode appearance works (if supported)
- [ ] Memory usage reasonable (check Xcode Debug Navigator)

---

## Ready for TestFlight

If all tests pass:
1. Product → Archive
2. Distribute App → App Store Connect
3. Upload to TestFlight
4. Test on physical device before App Store submission
