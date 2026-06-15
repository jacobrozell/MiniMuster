# Model photos, progress timeline & share exports

Verbose implementation plan for MiniMuster iOS photo tracking, stage history, and branded share exports.

**Status:** In progress (Phase 1 underway)  
**See also:** [DATA_FORMATS.md](DATA_FORMATS.md) · [DEVELOPMENT.md](DEVELOPMENT.md) · [README.md](README.md)

---

## Goals

1. Let hobbyists attach photos to units (and later squad members) — the collection should *look* like their bench, not just read like a spreadsheet.
2. Build a **progress timeline** from stage changes and photo checkpoints without extra logging friction.
3. Export **branded before/after images and GIF/MP4 timelapses** for Instagram, Discord, and Reddit — organic marketing that respects local-first privacy.

Non-goals for v1 of this feature set:

- Custom server sync — see [CLOUD_SYNC.md](CLOUD_SYNC.md) for iCloud path
- Web app parity in the first slice (JSON backup photo bundling comes in Phase 4)
- Paint-recipe overlays on exports (future delight)

---

## User stories

| As a… | I want to… | So that… |
|-------|------------|----------|
| Painter | Add a photo when I finish priming | I can see visual progress later |
| Collector | See thumbnails in my unit list | My army feels alive at a glance |
| Squad painter | Track photos per model | I know which Intercessor is still grey plastic |
| Sharer | Export a branded before/after | I can post progress without opening Photos |
| Power user | Include photos in backup | I don't lose images when switching phones |

---

## Architecture overview

```text
┌─────────────────────────────────────────────────────────────┐
│  SwiftUI (UnitDetailView, UnitRow, ShareExportSheet, …)     │
└───────────────────────────┬─────────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────────┐
│  PhotoStore / StageEventStore (mutations, undo hooks)         │
└─────────────┬─────────────────────────────┬───────────────────┘
              │                             │
┌─────────────▼──────────────┐   ┌──────────▼──────────────────┐
│  SwiftData                  │   │  PhotoFileStore (disk)     │
│  ModelPhoto, StageEvent     │   │  Application Support/      │
│  Unit, SquadMember          │   │  MiniMuster/Photos/*.jpg   │
└────────────────────────────┘   └────────────────────────────┘
```

**Principles**

- **Metadata in SwiftData, bytes on disk.** JPEG files live under Application Support; models store `fileName`, not `Data`.
- **Stage key on every photo.** Enables timeline grouping and GIF frame labels without inferring from timestamps alone.
- **Cover photo** — one `isCover` flag per unit for list thumbnails; first photo becomes cover by default.
- **Local-first preserved.** Photos never leave the device unless the user exports or shares.

---

## Data model

### `ModelPhoto`

```swift
import Foundation
import SwiftData

/// A JPEG checkpoint attached to a unit (or squad member in Phase 3).
@Model
final class ModelPhoto {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    /// Pipeline stage key at capture time (e.g. "Primed").
    var stageKey: String = ""
    var caption: String = ""
    /// File name only, relative to PhotoFileStore.directory (e.g. "A1B2….jpg").
    var fileName: String = ""
    var isCover: Bool = false
    var sortIndex: Int = 0
    /// nil = unit-level photo; non-nil = per-model index when squad tracking is on.
    var memberIndex: Int?

    var unit: Unit?

    init(stageKey: String, fileName: String, memberIndex: Int? = nil) {
        self.stageKey = stageKey
        self.fileName = fileName
        self.memberIndex = memberIndex
    }
}
```

### `StageEvent`

Automatic log when painting state changes — powers timeline and optional “snap this stage?” prompts.

```swift
@Model
final class StageEvent {
    var id: UUID = UUID()
    var occurredAt: Date = Date()
    var stageKey: String = ""
    var previousStageKey: String?
    /// nil = unit-level; non-nil = squad member index.
    var memberIndex: Int?
    var unit: Unit?

    init(stageKey: String, previousStageKey: String?, memberIndex: Int? = nil) {
        self.stageKey = stageKey
        self.previousStageKey = previousStageKey
        self.memberIndex = memberIndex
    }
}
```

### `Unit` relationship additions

```swift
// In Unit.swift
@Relationship(deleteRule: .cascade, inverse: \ModelPhoto.unit)
var photos: [ModelPhoto] = []

@Relationship(deleteRule: .cascade, inverse: \StageEvent.unit)
var stageEvents: [StageEvent] = []

var coverPhoto: ModelPhoto? {
    photos.first(where: \.isCover) ?? photos.sorted { $0.sortIndex < $1.sortIndex }.first
}

var orderedPhotos: [ModelPhoto] {
    photos.sorted {
        if $0.sortIndex != $1.sortIndex { return $0.sortIndex < $1.sortIndex }
        return $0.createdAt < $1.createdAt
    }
}
```

### Limits (`Limits.swift`)

```swift
static let maxPhotosPerUnit   = 24
static let maxPhotoBytes      = 4 * 1024 * 1024   // 4 MB per import
static let maxPhotoDimension  = 2048                // longest edge after resize
static let jpegQuality        = 0.82
```

---

## File storage (`PhotoFileStore`)

```swift
enum PhotoFileStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appending(path: "MiniMuster/Photos", directoryHint: .isDirectory)
    }

    static func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    static func writeJPEG(_ data: Data, id: UUID = UUID()) throws -> String {
        try ensureDirectory()
        let name = "\(id.uuidString.lowercased()).jpg"
        try data.write(to: directory.appending(path: name), options: .atomic)
        return name
    }

    static func url(for fileName: String) -> URL {
        directory.appending(path: fileName)
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
```

### Image processing (`PhotoStore`)

```swift
@MainActor
enum PhotoStore {
    static func addPhoto(from imageData: Data, to unit: Unit, stageKey: String,
                         memberIndex: Int? = nil, in ctx: ModelContext) throws -> ModelPhoto {
        guard unit.photos.count < Limits.maxPhotosPerUnit else {
            throw PhotoError.tooManyPhotos
        }
        let jpeg = try JPEGProcessor.normalize(imageData)
        let fileName = try PhotoFileStore.writeJPEG(jpeg)
        let photo = ModelPhoto(stageKey: stageKey, fileName: fileName, memberIndex: memberIndex)
        photo.sortIndex = (unit.photos.map(\.sortIndex).max() ?? -1) + 1
        if unit.photos.isEmpty { photo.isCover = true }
        photo.unit = unit
        ctx.insert(photo)
        try ctx.save()
        return photo
    }

    static func delete(_ photo: ModelPhoto, in ctx: ModelContext) {
        PhotoFileStore.delete(fileName: photo.fileName)
        let unit = photo.unit
        let wasCover = photo.isCover
        ctx.delete(photo)
        if wasCover, let unit, let next = unit.orderedPhotos.first {
            next.isCover = true
        }
        try? ctx.save()
    }

    static func purgeFiles(for unit: Unit) {
        for p in unit.photos { PhotoFileStore.delete(fileName: p.fileName) }
    }
}
```

---

## Stage event logging

Hook `ArmyStore.setState` and `ArmyStore.advance` (and squad member changes in `SquadStore`):

```swift
enum StageEventStore {
    static func recordUnit(_ unit: Unit, from previous: String, to next: String, in ctx: ModelContext) {
        guard previous != next else { return }
        let event = StageEvent(stageKey: next, previousStageKey: previous, memberIndex: nil)
        event.unit = unit
        ctx.insert(event)
    }

    static func recordAdvance(_ unit: Unit, pipeline: [PipelineStage], in ctx: ModelContext) {
        // Called inside Pipeline.advanceOneStep wrapper — log each effective transition.
    }
}
```

**Advance + photo prompt (Phase 2 UI):**

```swift
// After ArmyStore.advance in UnitDetailView:
@State private var showPhotoPrompt = false
@State private var pendingStageKey: String?

Button("Advance one stage") {
    let prev = unit.state
    ArmyStore.advance(unit, pipeline: pipeline, in: context)
    pendingStageKey = unit.state
    if Config.current(context).promptPhotoOnAdvance { showPhotoPrompt = true }
}
.sheet(isPresented: $showPhotoPrompt) {
    PhotoPromptSheet(stageKey: pendingStageKey ?? unit.state) { data in
        try? PhotoStore.addPhoto(from: data, to: unit, stageKey: unit.state, in: context)
    }
}
```

---

## UI plan

### Phase 1 — Hero photo & gallery (MVP)

- [x] `ModelPhoto` model + `PhotoFileStore` + `PhotoStore`
- [x] `Unit.photos` relationship + `coverPhoto` helper
- [x] `UnitPhotoSection` in `UnitDetailView` — `PhotosPicker`, cover badge, delete
- [x] Optional thumbnail on `UnitRow` when cover exists
- [x] Info.plist: `NSPhotoLibraryUsageDescription`
- [x] Unit tests for `PhotoStore` / `JPEGProcessor`
- [x] Accessibility identifiers: `unitAddPhoto`, `unitCoverPhoto`
- [ ] UI test screenshot flows updated for photo section

**`UnitPhotoSection` sketch:**

```swift
struct UnitPhotoSection: View {
    let unit: Unit
    let pipeline: [PipelineStage]
    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        Section("Photos") {
            if let cover = unit.coverPhoto, let uiImage = PhotoStore.loadImage(cover) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Add photo", systemImage: "photo.badge.plus")
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await importPhoto(item) }
            }
            ForEach(unit.orderedPhotos) { photo in
                PhotoThumbRow(photo: photo, pipeline: pipeline)
            }
        }
    }
}
```

### Phase 2 — Timeline & prompt on advance

- [x] `StageEvent` model + logging in `ArmyStore` / `SquadStore`
- [x] `UnitTimelineSection` — stage chip, date, optional nearby photo thumb
- [ ] `AppConfiguration.promptPhotoOnAdvance` setting (default on)
- [ ] `PhotoPromptSheet` after swipe-advance in army detail
- [ ] Before/after compare slider on unit detail

### Phase 3 — Branded share exports

- [ ] `ShareExportService` — render frames with `ImageRenderer` / Core Graphics
- [ ] Templates: classic timelapse, before/after, squad grid
- [ ] End card: `BrandCrest`, unit name, faction color accent, optional watermark toggle
- [ ] Export GIF via `CGImageDestination` (kUTTypeGIF) or MP4 via `AVAssetWriter`
- [ ] Share sheet from unit detail toolbar
- [ ] Strip EXIF location metadata on export

**GIF frame loop (sketch):**

```swift
enum ShareExportService {
    static func makeGIF(photos: [ModelPhoto], labels: Bool, branding: Bool) throws -> URL {
        let frames = photos.compactMap { PhotoStore.loadCGImage($0) }
        let url = FileManager.default.temporaryDirectory.appending(path: "timelapse.gif")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString,
                                                         frames.count, nil) else { throw ExportError.gif }
        let delay = 0.9
        for frame in frames {
            CGImageDestinationAddImage(dest, frame, [
                kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]
            ] as CFDictionary)
        }
        CGImageDestinationFinalize(dest)
        return url
    }
}
```

### Phase 4 — Backup, settings & squad photos

- [ ] JSON backup v4: optional `photos` manifest + sidecar zip (`minimuster-backup.zip`)
- [ ] Settings → Storage: cache size, “delete all photos”, quality slider
- [ ] Per-`SquadMember` photos (`memberIndex` already on model)
- [ ] Widget: “latest finished” photo (opt-in)
- [ ] Update `PRIVACY.md` / App Store copy for photo library access

---

## Backup format (future v4)

Extend `Snapshot` without breaking web JSON round-trip for data-only backups:

```json
{
  "version": 4,
  "collection": [ "…" ],
  "photos": [
    {
      "id": "uuid",
      "unitName": "Intercessors",
      "armyName": "Ultramarines",
      "stageKey": "Primed",
      "createdAt": "2026-06-15T12:00:00Z",
      "file": "photos/uuid.jpg",
      "isCover": true,
      "memberIndex": null
    }
  ]
}
```

Zip layout: `backup.json` + `photos/*.jpg`. Import restores files then links `ModelPhoto` rows.

---

## Privacy & permissions

| Permission | When | Info.plist key |
|------------|------|----------------|
| Photo library read | User taps Add photo | `NSPhotoLibraryUsageDescription` |
| Camera (optional later) | “Take photo” action | `NSCameraUsageDescription` |

Update privacy policy: photos stored on device; exports user-initiated; no network upload.

---

## Testing checklist

- [x] `PhotoStoreTests` — add, cover promotion, delete, purge, limit enforcement
- [x] `StageEventStoreTests` — logged on setState and advance
- [ ] `ShareExportServiceTests` — GIF frame count, branding flag
- [ ] Backup round-trip with zip (Phase 4)
- [ ] Manual: large HEIC import, dark mode gallery, VoiceOver on thumb rows

---

## Implementation log

| Date | Phase | Done |
|------|-------|------|
| 2026-06-15 | Plan | This document |
| 2026-06-15 | 1 | Models, file store, photo store, unit detail UI, row thumbnail, tests |
| 2026-06-15 | 2 (partial) | StageEvent model + ArmyStore logging, `UnitTimelineSection` |

---

## Open questions

1. **Duplicate unit** — copy photos or start fresh? → *Start fresh* (simpler; note in duplicate banner).
2. **Merge duplicates** — drop photos on merged-away row? → *Yes, purge files on deleted unit*.
3. **CSV** — no photo columns; document that CSV remains data-only.
