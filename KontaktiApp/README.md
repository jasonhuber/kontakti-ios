# Kontakti — iOS

Native SwiftUI app for [Kontakti](https://kontakti.app) — personal relationship intelligence.

---

## Requirements

- iOS 17+
- Xcode 15+
- A running Kontakti backend (kontakti.app or self-hosted)

---

## Stack

| Layer | Tech |
|-------|------|
| UI | SwiftUI |
| Local persistence | SwiftData |
| Networking | URLSession (async/await) |
| Auth token | Keychain via `KeychainService` |
| Offline sync | `SyncQueue` actor + `NetworkMonitor` (NWPathMonitor) |
| Contacts import | CNContactStore |
| Gmail discovery | Google Sign-In + People API + Gmail API |

---

## Architecture

**Offline-first.** The app serves cached data from SwiftData immediately and refreshes from the API when online. Mutations made while offline are queued in `SyncQueue` and flushed on reconnect.

```
Services/
  APIClient.swift          — async/await API calls, Keychain token
  PersistenceController.swift — ModelContainer setup
  OfflineStore.swift       — @MainActor SwiftData read/write
  NetworkMonitor.swift     — NWPathMonitor → @Published isConnected
  SyncQueue.swift          — actor serialising offline mutations to disk
  ContactsImporter.swift   — CNContactStore with email dedup
  GoogleAuthService.swift  — GoogleSignIn SDK wrapper
  GmailContactsService.swift — People API + Gmail From: header discovery

Models/
  Models.swift             — Codable structs matching the API
  SwiftDataModels.swift    — @Model classes for local cache
  ImportCandidate.swift    — struct for device/Gmail import flow

Views/
  Main/MainTabView.swift   — People / Companies / Discussions / Feed tabs
  People/PeopleListView.swift
  People/ImportContactsView.swift
  Components/OfflineBanner.swift
```

---

## Setup

### 1. Backend URL

`Services/APIClient.swift` line 25:

```swift
private let baseURL = URL(string: "https://kontakti.app/api/v1")!
```

Change this if you're running a self-hosted backend.

### 2. Contacts permission

Add to `Info.plist`:

```xml
<key>NSContactsUsageDescription</key>
<string>Kontakti imports your contacts to help you track relationships.</string>
```

### 3. Google Sign-In (optional — for Gmail import)

1. Create an OAuth 2.0 client ID in [Google Cloud Console](https://console.cloud.google.com/) (iOS app type).
2. Add to `Info.plist`:
   ```xml
   <key>GIDClientID</key>
   <string>YOUR_CLIENT_ID.apps.googleusercontent.com</string>

   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```
3. Add the GoogleSignIn package in Xcode → File → Add Package Dependencies:
   `https://github.com/google/GoogleSignIn-iOS`
4. Uncomment the two blocks marked `// MARK: - Uncomment after adding SPM package` in `GoogleAuthService.swift`.

---

## Build

Open `KontaktiApp.xcodeproj` in Xcode and run on a simulator or device. No additional setup required for the core CRM features — Gmail import requires steps 2–4 above.

---

## License

MIT
