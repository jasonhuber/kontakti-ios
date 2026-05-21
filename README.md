# Kontakti iOS

Mobile client for the Kontakti personal CRM.

## Strategy

Two viable paths — choose one when ready to build:

### Option A: React Native (Recommended for Code Reuse)

Shares API client, TypeScript types, and business logic hooks with the web frontend.

```
iOS/
└── KontaktiMobile/     React Native project
    ├── src/
    │   ├── api/        same api.ts from Website/frontend/src/lib
    │   ├── screens/    native screens
    │   ├── components/ shared components
    │   └── hooks/      shared hooks
    ├── ios/            native iOS Xcode project
    ├── android/        Android target (shared)
    └── package.json
```

**Setup:**
```bash
npx @react-native-community/cli init KontaktiMobile --template react-native-template-typescript
```

### Option B: SwiftUI

Full native experience. More work, no code sharing with web.

```
iOS/
└── KontaktiApp.xcodeproj
    └── KontaktiApp/
        ├── Models/
        ├── Views/
        ├── ViewModels/
        └── Services/
            └── APIClient.swift
```

---

## API Integration

The backend is API-first with token authentication. Both paths consume the same endpoints.

**Base URL:** `https://your-domain.com/api/v1`  
**Auth:** Bearer token via `Authorization: Bearer {token}`

Key endpoints used by mobile:
- `GET /people` — contacts list with search
- `GET /people/{id}/timeline` — person activity
- `GET /deals` — pipeline view
- `GET /feed` — activity feed
- `POST /notes` — quick note capture
- `POST /tasks` — quick task/follow-up
- `GET /search?q=` — global search

---

## Offline Support (Phase 2)

Design uses a sync-capable architecture:
- All records have UUIDs (safe to create offline)
- Optimistic updates on the frontend
- Background sync queue when connection restored
- Conflict resolution: last-write-wins on `updated_at`

Consider: SQLite local cache via WatermelonDB (React Native) or Core Data (SwiftUI)

---

## Current Status

Placeholder — backend API ready first, then mobile.
