# Kontakti iOS

This is a thin pointer. The actual Xcode project lives one level down at [`KontaktiApp/`](./KontaktiApp/), and its README is the canonical setup guide.

## Quick links

- 🍎 [iOS app README](./KontaktiApp/README.md) — stack, setup, build commands
- 📋 [Project HANDOFF](./HANDOFF.md) — architecture, deploy, cross-platform context
- 🛣️ [NEXT_STEPS](./NEXT_STEPS.md) — active work
- 📜 [CHANGELOG](./CHANGELOG.md) — per-commit history

## Build (one-liner)

```bash
cd KontaktiApp
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project KontaktiApp.xcodeproj \
             -scheme KontaktiApp \
             -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
             build
```
