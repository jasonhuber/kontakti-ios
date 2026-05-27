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

### 3. Google Sign-In

1. Create an OAuth 2.0 client ID in [Google Cloud Console](https://console.cloud.google.com/) (iOS app type).
2. Set these build settings in `project.yml`:
   - `GOOGLE_IOS_CLIENT_ID`: the iOS OAuth client ID, for example `123456789-abc.apps.googleusercontent.com`
   - `GOOGLE_IOS_REVERSED_CLIENT_ID`: the reversed URL scheme, for example `com.googleusercontent.apps.123456789-abc`
3. Set `GOOGLE_IOS_CLIENT_ID` to the same client ID in the Laravel API `.env`, then run the backend migration.

The GoogleSignIn Swift package is already declared in `project.yml`. The app uses Google Sign-In both for primary login and for Gmail/Google Contacts import.

### 4. Contact import

The People tab import menu supports two sources:

- **Import from phone** requests iOS Contacts permission through `CNContactStore`, reads names/emails/phones/organizations, dedupes against the local SwiftData cache, and posts selected contacts to `POST /api/v1/contacts/import`.
- **Import from Gmail** signs in with Google, requests People API and Gmail readonly scopes, pulls Google Contacts plus recent Gmail `From:` senders, dedupes by email, and posts selected candidates to the same import endpoint.

---

## Build

The Xcode project is generated from `project.yml` with XcodeGen:

```bash
xcodegen generate
xcodebuild -project KontaktiApp.xcodeproj -scheme KontaktiApp -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Open `KontaktiApp.xcodeproj` in Xcode and run on a simulator or device.

---

## License

MIT
