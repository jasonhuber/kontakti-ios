# Changelog — kontakti-ios

Notable changes to the SwiftUI iOS app. Most recent at top.

---

## 2026-05-29

### Apple Contacts writeback

New `AppleContactsWriter` service + `AppleContactsWritebackSection` in `PersonDetailView`. Three explicit actions:

- **Link to existing** — opens `CNContactPickerViewController`, stores `kontakti_person_id ↔ CNContact.identifier` in a local-only SwiftData table (`AppleContactLinkEntity`).
- **Create new** — creates a `CNContact` via `CNSaveRequest`, stores the mapping.
- **Update existing** — opens a diff sheet (`Phone: empty → +1…`, `Company: empty → Acme`); saves on confirm.

Never silent: every write goes through diff-then-confirm or an explicit Create/Link. Hidden for `do_not_contact` people. Stale-link recovery: if the user deleted the linked CN on-device, the update flow surfaces the error and drops the local link. Mapping stays local to the device — never synced to the backend.

Commit: [`34a789d`](https://github.com/jasonhuber/kontakti-ios/commit/34a789d)

### Deprecation sweep

Dropped the deprecated `.onChange(of:perform:)` syntax across 7 files (`CompaniesListView`, `DiscussionsListView`, `LogDiscussionView`, `MainTabView`, `EditPersonView`, `LinkSocialPickerView`, `SearchView`). All call sites now use the iOS 17+ zero-arg or `(old, new)` form.

Commit: [`f21b26d`](https://github.com/jasonhuber/kontakti-ios/commit/f21b26d)

### Contact Review queue

New `ReviewContactsView` (Settings → Review contacts) consumes `/people/health`. Top-level lists each non-empty bucket with count; drill-in shows sampled rows with an inline "Reviewed" button per sample. `Person` model gains optional `needsReview` + `reviewedAt` via `decodeIfPresent` so older API responses still parse.

Commit: [`6e971f4`](https://github.com/jasonhuber/kontakti-ios/commit/6e971f4)

---

## 2026-05-28

### Multi-account linking + SwiftUI iOS-17 syntax + draft error type

- `GoogleAuthService.signInForLinking` stopped pretending it could restore the previous primary Google session — GIDSignIn only tracks one user at a time. Now explicitly signs out and lets the caller re-sign-in for Gmail reads.
- `SettingsView.linkNewAccount` always reloads accounts (success or failure) so the UI reflects actual server state.
- `PeopleListView` uses iOS 17+ `.onChange(of:)` zero-arg syntax.
- `DraftMessageSheet` binds `.failure` as `Error` and uses `localizedDescription` (the underlying `Result<String, Error>` had been mis-typed).

Commit: [`d35b3dd`](https://github.com/jasonhuber/kontakti-ios/commit/d35b3dd)

### Shared schemes

Three Xcode schemes (`KontaktiApp`, `KontaktiShare`, `KontaktiWidget`) committed to `xcshareddata/xcschemes/` so other contributors can build without re-creating them.

Commit: [`ed00e56`](https://github.com/jasonhuber/kontakti-ios/commit/ed00e56)

---

## 2026-05-22 and earlier

- **Contact-quiz** prompts with optional note ([`8ca2831`](https://github.com/jasonhuber/kontakti-ios/commit/8ca2831))
- **Person photos** gallery + API client photo methods ([`61b0f87`](https://github.com/jasonhuber/kontakti-ios/commit/61b0f87))
- **Today inbox, voice, push, duplicates, DNC, multi-phone/email** ([`fb3df87`](https://github.com/jasonhuber/kontakti-ios/commit/fb3df87))
- **App icons** (contact-reach theme) wired ([`d0b8bb0`](https://github.com/jasonhuber/kontakti-ios/commit/d0b8bb0))
- **Offline support, device-contacts import, Gmail discovery** ([`45bc720`](https://github.com/jasonhuber/kontakti-ios/commit/45bc720))
- **Initial placeholder** ([`148e07b`](https://github.com/jasonhuber/kontakti-ios/commit/148e07b))
