# Spec — iCloud sync (mandatory path)

**Status:** Future release — spec only (not scheduled)  
**Target:** 1.1–1.2 (phased); **becomes primary persistence strategy** — manual JSON backup remains, but users should not need it for device changes  
**App:** MiniMuster (iOS)

> **Strategic direction:** Cloud save is **mandatory eventually**. Local-first stays the UX principle (works offline, no custom account), but iCloud becomes the default safety net so collections survive phone upgrades without friction.

**See also:** [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md) · [MODEL_PHOTOS.md](MODEL_PHOTOS.md) · [DATA_FORMATS.md](DATA_FORMATS.md) · [PRIVACY.md](PRIVACY.md)

---

## Summary

Sync armies, units, paints, settings, stage events, and photos across a user’s Apple devices using **CloudKit + SwiftData** (private database). The user signs in with their **Apple ID / iCloud account** already on the device — no MiniMuster account, no custom backend.

Manual **Full backup (JSON)** and CSV export remain for web interoperability, power users, and disaster recovery — but day-to-day “I got a new phone” should *just work* when iCloud is enabled.

---

## Goals

| Goal | Rationale |
|------|-----------|
| Automatic backup | Users shouldn’t lose years of hobby data on device loss |
| Multi-device | iPhone on the bench, iPad on the desk — same collection |
| No new account | iCloud is the auth; matches Apple ecosystem trust |
| Offline-first UX | Edit locally; sync when network available |
| Photo bytes included | Model photos are part of the collection, not an afterthought |
| Web backup compatibility | JSON export still round-trips with web app |

## Non-goals (v1 cloud)

- Android or web client sync
- Shared / collaborative armies (family guild sync)
- Custom server or Firebase backend
- End-to-end encryption beyond Apple’s CloudKit private DB guarantees
- Real-time multiplayer editing
- Sync with non-Apple cloud drives (Dropbox, Google Drive) — use export instead

---

## Why CloudKit + SwiftData

Models are already **CloudKit-ready** — defaults on all properties, no `@Attribute(.unique)`, optional relationships ([`Army.swift`](../MiniMuster/Models/Army.swift) comment).

```swift
// Target container configuration (sketch)
ModelConfiguration(
    cloudKitDatabase: .private("iCloud.com.jacobrozell.minimuster")
)
```

| Approach | Verdict |
|----------|---------|
| CloudKit + SwiftData | **Primary** — Apple-maintained sync, matches stack |
| NSPersistentCloudKitContainer manual | Skip — SwiftData wraps this |
| Custom sync server | Reject — ops burden, privacy narrative break |
| iCloud Documents (file bundle) | Reject for structured data — conflict hell |

---

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│  SwiftUI — Settings → iCloud status, conflict UI (rare)     │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  SwiftData ModelContainer (CloudKit .private)               │
│  Army, Unit, SquadMember, Paint, ModelPhoto, StageEvent,    │
│  AppConfiguration                                         │
└─────────────┬───────────────────────────┬───────────────────┘
              │                           │
┌─────────────▼──────────────┐   ┌────────▼──────────────────┐
│  CloudKit Private DB        │   │  PhotoFileStore (local)   │
│  CKAsset for JPEG bytes     │   │  ↔ CKAsset upload/download│
└────────────────────────────┘   └───────────────────────────┘
```

### Synced entities

| Model | Sync | Notes |
|-------|------|-------|
| `Army` | Yes | Including `customPipeline`, `sortIndex` |
| `Unit` | Yes | Squad members embedded or related |
| `SquadMember` | Yes | If separate model |
| `Paint` | Yes | |
| `AppConfiguration` | Yes | Per-device overrides TBD (see below) |
| `ModelPhoto` | Yes | Metadata in SwiftData; bytes as `CKAsset` |
| `StageEvent` | Yes | Timeline history |

### Per-device vs shared settings

| Field | Sync? | Reason |
|-------|-------|--------|
| `themeRaw` | Per-device | User may want dark on phone, light on iPad |
| Filters (`gameFilter`, etc.) | Per-device | Context differs by device |
| `globalPipeline`, `factionOverrides` | **Shared** | Collection semantics |
| `lastBackupAt` | Per-device | Export is device-action |
| `hasSeenOnboarding` | Per-device | |
| Notification prefs | Per-device | See [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md) |

**Implementation:** Split into `AppConfiguration` (synced) + `DevicePreferences` (local UserDefaults or non-synced SwiftData singleton) in Phase 2 if conflicts arise.

---

## Photos strategy

Photos today: metadata in SwiftData, JPEG on disk ([`PhotoFileStore`](../MiniMuster/DataIO/Photos/PhotoFileStore.swift)).

**Cloud approach:**

1. On save: write local JPEG (fast display) + enqueue `CKAsset` upload keyed by `ModelPhoto.id`.
2. On sync download: write to `PhotoFileStore` path from `fileName`; dedupe by UUID.
3. On delete: remove local file + CloudKit record cascade.
4. Limits (`maxPhotosPerUnit`, `maxPhotoBytes`) still enforced client-side.

Backup v4 zip ([MODEL_PHOTOS.md](MODEL_PHOTOS.md)) remains for web migration; cloud is the live multi-device path.

---

## User experience

### Settings → Data (revised)

| Row | Behavior |
|-----|----------|
| **iCloud sync** | Toggle + status: *Up to date* / *Syncing…* / *Paused — no iCloud account* / *Error* |
| **Last synced** | Relative time (`AppConfiguration.lastCloudSyncAt` or CloudKit account status) |
| **Last backup** | Keep existing `lastBackupAt` for manual JSON export — **already implemented** in Settings → Data |
| **Full backup (JSON)** | Secondary path: *Export for web app or archive* |
| **Restore backup…** | Unchanged; may disable while sync on with warning |

### First-run / upgrade flow

1. Existing users: banner on upgrade — *Turn on iCloud to keep your collection across devices.*
2. Enabling sync: one-time explainer — data stays in **your** private iCloud; we can’t read it.
3. If iCloud unavailable: app works fully local; periodic [backup notifications](PUSH_NOTIFICATIONS.md) until enabled.

### Conflict resolution

SwiftData + CloudKit uses **last-write-wins** per record at the field level in most cases.

| Scenario | UX |
|----------|-----|
| Same unit edited offline on two devices | Newer `updatedAt` wins; rare conflict → banner *Collection updated from another device* |
| Delete vs edit | Delete wins (tombstone via CloudKit) |
| Restore JSON while sync on | Confirmation: *This replaces local data and will sync to iCloud* |

Add `updatedAt: Date` to `Unit`, `Army`, `Paint` if not present — bump on every mutation.

---

## Offline behavior

- All reads/writes work offline against local store.
- CloudKit queues changes; UI shows *Syncing…* or *Waiting for network* in Settings.
- Widget reads local App Group snapshot (unchanged); `WidgetUpdater` after sync completes.

---

## Privacy & legal (required before ship)

Update [`PRIVACY.md`](PRIVACY.md) and App Store copy:

| Today | After cloud |
|-------|-------------|
| “No network transmission” | “Collection syncs to **your** iCloud private database when enabled” |
| “No account required” | “Uses your Apple ID iCloud account; no separate MiniMuster login” |
| — | Link to Apple iCloud terms; data not accessible to developer |

**Entitlements:** `iCloud.com.jacobrozell.minimuster` container; CloudKit capability in Xcode + Developer portal.

**App Store Connect:** iCloud checkbox; privacy nutrition label updated for data stored in iCloud.

---

## Relationship to manual backup

| Concern | Cloud sync | JSON backup |
|---------|------------|-------------|
| New phone | Primary | Fallback if iCloud off |
| Web app migration | Export still needed | Primary |
| User trust / archivist | Automatic | Explicit file they control |
| Corrupt state recovery | Time-machine via CK (limited) | Restore known-good JSON |

**Last backup in Settings** stays valuable:

- Shows when user last exported manually (`lastBackupAt` on full JSON export — **already wired**).
- Future: show *Last synced* alongside *Last backup* so anxious archivists see both safety nets.

Enhancements (from [POLISH_IDEAS.md](POLISH_IDEAS.md)):

- Relative date (*3 days ago*)
- Tap → export backup action
- Amber styling when both iCloud off **and** backup &gt; 30 days

---

## Migration plan

### Phase 0 — Prep (can ship before cloud)

- [ ] Add `updatedAt` to mutable models
- [ ] Audit CloudKit schema defaults on all `@Model` types
- [ ] Split device-only prefs if needed
- [ ] Document entitlement setup in [DEVELOPMENT.md](DEVELOPMENT.md)

### Phase 1 — Sync core data (1.1)

- [ ] Enable `cloudKitDatabase: .private(...)` on `ModelContainer`
- [ ] Settings: iCloud toggle + account status
- [ ] Migration: existing local store uploads on first enable
- [ ] Tests: two-simulator sync (CI optional, manual required)
- [ ] Update privacy policy + App Store description

### Phase 2 — Photos (1.1–1.2)

- [ ] `CKAsset` pipeline for `ModelPhoto`
- [ ] Storage row: local + cloud byte estimate
- [ ] Conflict test: delete photo on A, view on B

### Phase 3 — Mandatory default (1.2+)

- [ ] Onboarding page: recommend iCloud (not block without it)
- [ ] Deprecate 14-day backup **notifications** when sync healthy ([PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md))
- [ ] Consider opt-out only for users without iCloud (local-only mode explicit)

**“Mandatory” definition:** Not “forced Apple ID” — means **product expectation** is that a normal user never thinks about backup because iCloud handles it. Local-only remains supported for air-gapped users.

---

## Testing checklist

- [ ] Fresh install + enable sync → empty CK zone
- [ ] Upgrade install with 500 units → initial upload completes
- [ ] Airplane mode edit → sync on reconnect
- [ ] Two devices: advance unit on A → appears on B
- [ ] Delete army on A → gone on B
- [ ] Sign out of iCloud → graceful degradation message
- [ ] JSON restore with sync on → warning + full replace
- [ ] Photo round-trip across devices
- [ ] Widget counts match after sync

---

## Open questions

1. **Single zone vs custom CK record zones** for future sharing features?
2. **App Configuration** single row — sync one global row or per-device replica merged?
3. **Free tier iCloud storage** — warn when photo library threatens quota?
4. **Web app** — long-term, read-only CK API or keep JSON export as the bridge?
5. Phase 3: should local-only users see a **persistent** Settings badge until first backup?

---

## Changelog

| Date | Notes |
|------|-------|
| 2026-06-15 | Initial spec — iCloud as mandatory eventual path |
