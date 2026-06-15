# Data formats — MiniMuster iOS

MiniMuster shares import/export formats with the [MiniMuster web app](https://github.com/jacobrozell/MiniMuster). Files produced on one platform can be consumed on the other.

All I/O is user-initiated through the system file picker or share sheet. Nothing is uploaded to a server.

## CSV — armies

**Export:** Settings → Data → **Export armies CSV**  
**Import:** Settings → Data → Import armies (replace or append)

### Required columns

| Column | Description |
|--------|-------------|
| `Army` | Army name (creates or merges into existing army) |
| `Unit` | Unit name |
| `Qty` | Model count (integer) |
| `State` | Painting pipeline stage key (e.g. `Unassembled`, `Built`, `Primed`) |

### Optional columns

| Column | Description |
|--------|-------------|
| `Game` | Game system (e.g. Age of Sigmar, 40k) |
| `Faction` | Faction name for crest/color resolution |
| `Source` | Box or provenance string |
| `Spearhead` | `true` / `false` — marks spearhead units |
| `Notes` | Free text |
| `Member` | Squad member index (1-based) for per-model tracking |
| `Member State` | State for individual squad member |
| `Member Notes` | Notes for individual squad member |

### Squad members

When `Qty` ≥ 2, member rows with the same army/unit/source/qty/spearhead group into one unit with per-model states. The importer pads or trims members to match `Qty`.

### Pipeline normalization

States are normalized against the **global pipeline** at import time (Settings → Pipeline). Unknown states map to the nearest valid stage or the first stage.

### Templates

Settings → Data → **Armies template** exports a header-only CSV for spreadsheet setup.

## CSV — paints

**Export:** Settings → Data → **Export paints CSV**  
**Import:** Settings → Data → Import paints (replace or append)

### Columns

| Column | Required | Description |
|--------|----------|-------------|
| `Name` | Yes | Paint name |
| `Type` | Yes | Category (e.g. Base, Layer, Shade) |
| `Swatch` | No | Hex color `#RRGGBB` |
| `Qty` | No | Bottle/tube count |
| `Brand` | No | Manufacturer |
| `Source` | No | Collection link — tapping in the app filters units by this source |

### Templates

Settings → Data → **Paints template** exports a header-only CSV.

## JSON — full backup

**Export:** Settings → Data → **Full backup (JSON)**  
**Restore:** Settings → Data → **Restore backup…** (replaces all armies, paints, and settings)

The backup matches the web app’s `exportSnapshot` shape. Field names use web conventions (`army`, `unit`, `color`, `armySort: "csv"`, etc.) — see `MiniMuster/DataIO/Backup/Snapshot.swift`.

### Top-level structure

```json
{
  "version": 1,
  "exportedAt": "2026-06-15T12:00:00.000Z",
  "armies": [ /* ArmyDTO[] */ ],
  "paints": [ /* PaintDTO[] */ ],
  "config": {
    "theme": "system",
    "globalPipeline": [ /* PipelineStage[] */ ],
    "factionOverrides": { /* crest/color overrides */ },
    "armySort": "csv"
  }
}
```

### Army object

| Field | Description |
|-------|-------------|
| `army` | Army name |
| `game`, `faction` | Metadata |
| `crest`, `color` | Resolved display values |
| `crestOverride`, `colorOverride` | User overrides |
| `pipeline` | Optional per-army custom stages |
| `units` | Array of unit objects |

### Unit object

| Field | Description |
|-------|-------------|
| `unit`, `qty`, `source`, `state`, `spearhead`, `notes` | Core fields |
| `members` | Optional `[{ state, notes }]` for squad tracking |

### Paint object

| Field | Description |
|-------|-------------|
| `name`, `type`, `swatch`, `qty`, `brand`, `source` | Inventory fields |

### Restore behavior

Restore **replaces** all local data. The app shows a confirmation dialog first. Invalid or corrupt JSON surfaces a native alert with the error message.

`BackupSanitizer` strips unknown keys and clamps values so slightly older or hand-edited backups still load when possible.

## Import modes

| Mode | Armies | Paints |
|------|--------|--------|
| **Replace** | Deletes existing armies/units, then imports | Deletes existing paints, then imports |
| **Append** | Merges by army name; units append or merge by squad key | Appends rows (duplicate names allowed) |

Replace mode shows a confirmation warning before proceeding.

## Limits

- Import files must be UTF-8 text under `Limits.maxImportBytes` (see `MiniMuster/Domain/Limits.swift`).
- Row and field validation errors are collected; partial imports are not committed — the file must parse cleanly.

## Web ↔ iOS workflow

1. **Web → iOS:** Export CSV or JSON from the web app → AirDrop or Files → Import in iOS Settings → Data.
2. **iOS → Web:** Export from iOS → open the web app → import via its Data settings.
3. **Backup strategy:** Periodically export **Full backup (JSON)**; the app can remind you after 30 days (dismissible).

## Implementation reference

| Format | Swift module |
|--------|--------------|
| CSV parsing | `DataIO/CSV/CSV.swift` |
| Armies CSV | `DataIO/CSV/ArmyCSV.swift` |
| Paints CSV | `DataIO/CSV/PaintCSV.swift` |
| JSON backup | `DataIO/Backup/BackupCodec.swift`, `Snapshot.swift` |
| UI wiring | `Features/Settings/SettingsDataSection.swift`, `Features/Shared/DataActions.swift` |
