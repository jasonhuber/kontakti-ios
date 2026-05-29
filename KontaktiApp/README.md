# Kontakti — iOS

Native SwiftUI app for [Kontakti](https://kontakti.app) — personal relationship intelligence.

---

## Requirements

- iOS 18+ (deployment target)
- Xcode 26+ (iOS 18 SDK)
- A running Kontakti backend (kontakti.app or self-hosted)

---

## Stack

| Layer | Tech |
|---|---|
| UI | SwiftUI 5 |
| Local persistence | SwiftData (`@Model` cache + a local-only Apple-Contacts-link table) |
| Networking | URLSession with async/await |
| Auth token | Keychain via `KeychainService` |
| Offline sync | `SyncQueue` actor + `NetworkMonitor` (NWPathMonitor) |
| Phone contacts | CNContactStore (read + writeback with diff-confirm) |
| Gmail / Google Contacts | GoogleSignIn SDK + People API + Gmail API |
| LinkedIn enrichment | WKWebView → page HTML → POST to `enrich.kontakti.app` (Ollama / phi4) |

---

## Architecture

**Offline-first.** Cached data from SwiftData renders immediately. The network layer refreshes asynchronously when online. Mutations made offline are serialized into `SyncQueue` on disk and flushed when `NetworkMonitor` reports a transition to online.

```
KontaktiApp/
├── Services/
│   ├── APIClient.swift              ← async URLSession wrapper, Keychain token
│   ├── PersistenceController.swift  ← ModelContainer setup
│   ├── OfflineStore.swift           ← @MainActor SwiftData read/write
│   ├── NetworkMonitor.swift         ← NWPathMonitor → @Published isConnected
│   ├── SyncQueue.swift              ← actor serializing offline mutations to disk
│   ├── KeychainService.swift
│   ├── ContactsImporter.swift       ← read iPhone contacts with email dedup
│   ├── AppleContactsWriter.swift    ← writeback to CN with diff-then-confirm
│   ├── GoogleAuthService.swift      ← GoogleSignIn SDK wrapper
│   ├── GmailContactsService.swift   ← People API + Gmail From: headers
│   ├── EnrichmentService.swift      ← POST HTML → enrich.kontakti.app
│   ├── VoiceRecorder.swift
│   └── DeepLinkRouter.swift         ← share-extension deep links
├── Models/
│   ├── Models.swift                 ← Codable structs matching the API
│   ├── SwiftDataModels.swift        ← @Model classes for local cache + AppleContactLinkEntity
│   └── ImportCandidate.swift        ← struct for device/Gmail import flow
├── ViewModels/
│   ├── AuthViewModel.swift          ← auth gate (needsOnboarding + isAuthenticated)
│   ├── PeopleViewModel.swift
│   ├── PersonDetailViewModel.swift
│   ├── CompaniesViewModel.swift
│   ├── DiscussionsViewModel.swift
│   ├── FeedViewModel.swift
│   ├── SearchViewModel.swift
│   └── TodayViewModel.swift
├── Views/
│   ├── Auth/                         LoginView, RegisterView
│   ├── Onboarding/OnboardingView.swift   ← 4-step post-auth wizard
│   ├── Main/MainTabView.swift            ← 6 tabs: Today / People / Companies / Discussions / Feed / Settings
│   ├── People/
│   │   ├── PeopleListView.swift
│   │   ├── PersonDetailView.swift        ← + AppleContactsWritebackSection
│   │   ├── PersonCardView.swift
│   │   ├── EditPersonView.swift
│   │   ├── PhotoGalleryView.swift
│   │   ├── ImportContactsView.swift
│   │   ├── LinkedInImportView.swift      ← WKWebView-driven
│   │   ├── LinkSocialPickerView.swift
│   │   ├── ReviewContactsView.swift      ← /people/health buckets
│   │   └── AppleContactsWritebackView.swift
│   ├── Companies/                    list + detail
│   ├── Discussions/                  list + detail + log
│   ├── Feed/FeedView.swift
│   ├── Today/                        today + draft + job changes
│   ├── Voice/                        recording + result review
│   ├── Quiz/                         carousel + session
│   ├── Search/SearchView.swift       ← ⌘K palette
│   ├── Settings/                     SettingsView + duplicate review + social groups + QR pairing + sync direction
│   └── Components/                   Avatar / EmptyState / OfflineBanner / StrengthBadge / DNCBadge
├── Intents/                          KontaktiShortcutsProvider + LogVoiceMemoIntent (Siri)
└── Info.plist
```

The Xcode project file is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen). Don't hand-edit `KontaktiApp.xcodeproj/project.pbxproj` — re-run `xcodegen generate` after adding a new file.

---

## Setup

### 1. Backend URL

`Services/APIClient.swift`:

```swift
private let baseURL = URL(string: "https://kontakti.app/api/v1")!
```

Change this if you're running a self-hosted backend.

### 2. Contacts permission

Already declared in `Info.plist`:

```xml
<key>NSContactsUsageDescription</key>
<string>Kontakti imports your contacts to help you track relationships.</string>
```

Also requested at runtime by `ContactsImporter` (read) and `AppleContactsWriter` (read + write).

### 3. Google Sign-In

1. Create an OAuth 2.0 iOS client ID in [Google Cloud Console](https://console.cloud.google.com/).
2. In `project.yml`, set:
   - `GOOGLE_IOS_CLIENT_ID` — e.g. `123456789-abc.apps.googleusercontent.com`
   - `GOOGLE_IOS_REVERSED_CLIENT_ID` — e.g. `com.googleusercontent.apps.123456789-abc`
3. The backend `.env` needs `GOOGLE_IOS_CLIENT_ID` set to the same value so id_token verification matches.
4. `xcodegen generate`, then build.

GoogleSignIn (Swift Package) is already declared in `project.yml`. The app uses it for both primary login (`/auth/google`) and Gmail/People API discovery.

### 4. Contact import (already wired)

- **Import from phone** — `CNContactStore` read, dedup against the SwiftData cache, POST to `/contacts/import`.
- **Import from Gmail** — Google Sign-In with contacts.readonly + gmail.readonly scopes, fetches Google Contacts + recent Gmail `From:` senders, dedup by email, POST to the same endpoint.
- **Import from LinkedIn** — WKWebView opens the LinkedIn profile (user logs in once, persisted cookies), grabs `outerHTML`, POSTs `{url, html}` to `enrich.kontakti.app/api/enrich` which strips scripts and runs phi4 (Ollama, local) for structured extraction.

### 5. Apple Contacts writeback

In `PersonDetailView`, an "Apple Contacts" section appears when contacts permission is granted and the person isn't `do_not_contact`:

- **Link to existing Apple Contact** — opens `CNContactPickerViewController`, stores the mapping locally.
- **Create Apple Contact** — creates a new CN entry, stores the mapping.
- **Update Apple Contact** — opens a diff sheet ("Phone: empty → +1…", "Company: empty → Acme") and saves on confirmation.

Mapping is `kontakti_person_id ↔ CNContact.identifier`, stored in a local `AppleContactLinkEntity` SwiftData table that never leaves the device.

---

## Build

```bash
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project KontaktiApp.xcodeproj \
             -scheme KontaktiApp \
             -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
             -configuration Debug build
```

If `xcodebuild` errors with "requires Xcode but the active developer directory is Command Line Tools", the `DEVELOPER_DIR=…` override above fixes it without needing `sudo xcode-select --switch`.

Open `KontaktiApp.xcodeproj` in Xcode to run on a simulator or device.

---

## Project-level docs

- Architecture overview + cross-platform context: [`HANDOFF.md`](../HANDOFF.md) (at the iOS repo root)
- What's next: [`NEXT_STEPS.md`](../NEXT_STEPS.md)
- Per-commit history: [`CHANGELOG.md`](../CHANGELOG.md)

These are mirrors of the canonical project-level docs. The cross-repo source of truth lives in the workspace Dropbox folder; copies live in each repo so anyone cloning a single repo has the full context.

---

## License

MIT.
