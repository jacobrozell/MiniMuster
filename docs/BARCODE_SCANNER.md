# Spec — GW Barcode Scanner & Product Import

**Status:** Future release — spec only (not scheduled)  
**Target:** 1.2+ (TBD; after 1.0 ship and 1.1 polish)  
**App:** MiniMuster (iOS)  
**Author:** Research brainstorm, June 2026

> **Not in scope for 1.0 or 1.1.** This document captures research and a proposed design for when the feature is prioritized. See [`RELEASE_1.0.0.md`](RELEASE_1.0.0.md) deferred list.

---

## Summary

Add a barcode scanner that identifies Games Workshop product boxes and imports their **unit contents** into the user's collection — pre-filling army, faction, unit names, quantities, and `Source` (box provenance).

The feature should be **offline-first**: a curated product catalog ships in the app bundle, with optional remote catalog updates. Per-scan third-party API calls are a fallback for identification only, not for box contents.

---

## Goals

| Goal | Rationale |
|------|-----------|
| Fast box intake | Combat Patrols and battleforces contain many units; manual entry is tedious |
| Match existing data model | Reuse `Unit`, `Army`, CSV import conventions, and `Source` provenance |
| Work offline | Aligns with MiniMuster's local-first, no-account posture |
| High accuracy on curated set | Prefer a smaller, verified catalog over a large, noisy one |

## Non-goals (v1)

- Paint / Citadel product scanning (separate domain; paint CSV schema differs)
- Rules lookups, points, or datasheet stats
- GW product images or official marketing copy redistribution
- Real-time cloud sync of user collections
- Scanning sprue barcodes or individual model parts

---

## Background — how the app models products today

MiniMuster already tracks **where models came from** via the `Source` field on units. Sample data uses box names like `Skaventide`, `Combat Patrol 1`, and `Stormcast Painting Kit`.

Units use parenthetical model counts in names, parsed by `ModelCount`:

- `Liberators (5)` qty 1 → 5 models
- `Reclusians + Memorians (x3 + x2)` qty 1 → 5 models
- `Prosecutors` qty 3 → 3 models (no parens → qty is model count)

Army CSV import (`ArmyCSV`) and `ArmyStore.addUnit` are the natural insertion path. A scan import produces `[UnitDraft]` and appends to an existing or new `Army`.

**Relevant code:**

| Area | Location |
|------|----------|
| Unit model | `MiniMuster/Models/Unit.swift` |
| Import drafts | `MiniMuster/DataIO/Drafts.swift` |
| Army CSV import | `MiniMuster/DataIO/CSV/ArmyCSV.swift` |
| Army mutations | `MiniMuster/Features/Armies/ArmyStore.swift` |
| Faction resolution | `MiniMuster/Domain/Factions/FactionResolver.swift` |
| Model count parsing | `MiniMuster/Domain/ModelCount.swift` |
| Sample conventions | `MiniMuster/Resources/warhammer_armies.csv` |

---

## Research findings — data sources

### Official GW APIs

**None publicly available.** GW's trade catalog (barcodes, order forms, product sheets) is restricted to registered retailers via the Retailers Network. There is no consumer or developer API for product lookup or box contents.

### Third-party barcode APIs (Buycott, UPCItemDB, etc.)

| Capability | Assessment |
|------------|------------|
| Resolve EAN → product title | Sometimes works for GW; coverage is incomplete |
| Return structured box contents | **No** — titles only, often scraped from retailers |
| Offline / privacy | Requires network; sends barcode to third party |
| Cost / reliability | API keys, rate limits, terms may change |

**Verdict:** Optional fallback to suggest a product *name* when the bundled catalog misses. Not suitable as the primary contents source.

### Wahapedia / BSData / 40kdc

Excellent for **datasheet names, factions, wargear, and points** — the rules layer.

They do **not** map plastic boxes → unit lists. A Combat Patrol and a single-character blister are both "products" in the real world but only the former needs a multi-unit contents array.

**Verdict:** Use as a **normalization layer** (canonical unit names, faction labels) when building the catalog — not as the catalog itself.

### Scalemates

Large community kit database (~650k products) with barcodes, GWS codes, and kit metadata. No public export API. Data matching is internal to their marketplace. Scraping is ethically and legally risky.

**Verdict:** Useful as a manual research reference when curating entries. Not an automated ingestion source.

### Recommended approach

| Layer | Mechanism |
|-------|-----------|
| **Primary** | Curated JSON catalog bundled with the app |
| **Updates** | Versioned JSON delta downloaded from project CDN/GitHub releases (optional, quarterly) |
| **Fallback** | Manual GWS code search within app; optional barcode API for title hint only |
| **Future** | Opt-in community barcode submissions merged into catalog releases |

---

## GW product identifier landscape

A single kit may be reachable via multiple keys. The catalog must index all of them to one canonical product record.

| Key | Example | Where found | Notes |
|-----|---------|-------------|-------|
| **EAN-13** | `5011921170036` | Box barcode | GW prefix `5011921`; can change on reprint/region |
| **GWS code** | `56-15` | Box back, retailer listings | Stable product identity; preferred internal ID |
| **GW catalog #** | `99120113082` | Trade/retailer systems | Internal SKU; alternate lookup key |
| **Box title** | "XV88 Broadside Battlesuit" | Packaging | Marketing name; may differ from datasheet name |

**Reprint example:** Broadside `56-15` has been associated with EANs `5011921170036` and `5011921091973` across listings. Same GWS code, different barcodes.

**Product versioning:** When contents change under the same GWS code (sculpt refresh), version products explicitly (e.g. `56-15@2017` vs `56-15@2022`).

---

## Catalog data model

### File layout

```
MiniMuster/Resources/ProductCatalog/
  catalog.json          # Full catalog (or split by game)
  catalog-index.json    # Optional: barcode → product id only (fast load)
```

Ship compressed in bundle. Target size for MVP: ~50–80 products, &lt;200 KB uncompressed.

### JSON schema

```json
{
  "version": "2026.06.1",
  "generatedAt": "2026-06-14",
  "products": {
    "56-15": {
      "id": "56-15",
      "gws": "56-15",
      "catalogNumber": "99120113082",
      "name": "XV88 Broadside Battlesuit",
      "game": "40k",
      "faction": "T'au Empire",
      "type": "single",
      "barcodes": ["5011921170036", "5011921091973"],
      "contents": [
        { "unit": "XV88 Broadside Battlesuit", "qty": 1 },
        { "unit": "MV8 Missile Drone", "qty": 1 },
        { "unit": "Shield Drone", "qty": 1 }
      ],
      "aliases": ["Broadside Battlesuit", "GWS 56-15"]
    },
    "combat-patrol-grey-knights-2024": {
      "id": "combat-patrol-grey-knights-2024",
      "gws": null,
      "name": "Grey Knights Combat Patrol",
      "game": "40k",
      "faction": "Grey Knights",
      "type": "box",
      "barcodes": ["5011921XXXXXXXX"],
      "contents": [
        { "unit": "Castellan Crowe", "qty": 1 },
        { "unit": "Venerable Dreadnought", "qty": 1 },
        { "unit": "Nemesis Dreadknight", "qty": 1 },
        { "unit": "Brotherhood Terminators (5)", "qty": 1 },
        { "unit": "Grey Knights Strike Squad (5)", "qty": 1 }
      ]
    }
  },
  "barcodeIndex": {
    "5011921170036": "56-15",
    "5011921091973": "56-15"
  },
  "gwsIndex": {
    "56-15": "56-15",
    "56/15": "56-15"
  }
}
```

### Field definitions

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Stable catalog key (GWS code or slug for multi-unit boxes) |
| `gws` | No | Games Workshop product code when assigned |
| `name` | Yes | Display name; becomes default `Source` on import |
| `game` | Yes | Maps to app game picker (`40k`, `AoS`, etc.) |
| `faction` | Yes | Passed through `FactionResolver.normalize()` |
| `type` | Yes | `single` \| `box` \| `terrain` \| `paint` (paint excluded from v1) |
| `barcodes` | No | EAN-13 strings |
| `contents` | Yes | Array of `{ unit, qty }` |
| `contents[].unit` | Yes | Unit name; use `(N)` convention for squad sizes |
| `contents[].qty` | Yes | Number of that unit entry (not always model count) |
| `aliases` | No | Search terms for manual lookup |

### Unit naming rules (must match `ModelCount`)

1. Squad size in first parenthetical: `Intercessors (5)`
2. Compound squads: `Reclusians + Memorians (x3 + x2)`
3. Multiple identical entries vs qty: prefer **one row with qty** when the box contains multiple separate sprues of the same datasheet (e.g. `Prosecutors` qty 3)
4. Optional `canonicalUnit` field (future): map display name to Wahapedia datasheet name when they diverge

### Catalog build pipeline (maintainer tooling)

1. **Seed** — Manually curate high-value boxes (Combat Patrols, Spearhead, battleforces, army sets)
2. **Enrich** — Unit counts from official GW box descriptions (back-of-box, product pages)
3. **Normalize** — Fuzzy-match unit strings against Wahapedia export / existing user CSV conventions
4. **Barcodes** — Collect EANs from retailer listings and community submissions; map to GWS code
5. **Validate** — CI test: every `contents[].unit` parses via `ModelCount`; every `faction` resolves via `FactionResolver`

---

## User experience

### Entry points

- **Collection tab** — toolbar "Scan box" action
- **Army detail** — "Add from scan" (pre-selects target army)
- **Settings** — optional "Update product catalog" when remote updates ship

### Primary flow

```
Scan barcode
    → Catalog lookup (EAN)
        → Hit: Product preview sheet
        → Miss: "Unknown product" sheet
            → Search by GWS code / product name
            → Report unknown barcode (optional, v2)
    → User selects units to import (all checked by default)
    → User picks target army or creates new army
        → Pre-fill game + faction from product
        → Army name: existing or suggested (e.g. faction name)
    → Confirm import
    → Units appended via ArmyStore; source = product.name
    → Default state = first pipeline stage (e.g. Unassembled)
    → Success toast / navigate to army
```

### Product preview sheet

- Product name, GWS code, game, faction
- Checklist of units with qty and estimated model count (`ModelCount`)
- Toggle all / none
- Army picker (existing armies matching game+faction surfaced first)
- "Create new army" with editable name

### Unknown product sheet

- Scanned barcode displayed (user can verify scan)
- Search field: GWS code, catalog number, or product name against bundled catalog
- Link to manual "Add unit" as fallback
- (v2) Submit barcode + optional photo for catalog contribution

### Secondary flow — GWS code OCR (optional, Phase 2)

VisionKit text recognition on box back for `GWS XX-XX` or `XX-XX` patterns when barcode is damaged or missing.

---

## Technical architecture

### New modules

| Module | Responsibility |
|--------|----------------|
| `ProductCatalog` | Load JSON, build indexes, `lookup(barcode:)`, `lookup(gws:)`, `search(query:)` |
| `ProductRecord` | Codable struct mirroring catalog entry |
| `ProductImportService` | `ProductRecord` + selected contents → `[UnitDraft]` → `ArmyStore` |
| `BarcodeScannerView` | VisionKit `DataScannerViewController` wrapper (EAN-13, UPC-A) |
| `ProductImportSheet` | SwiftUI preview + army picker + confirm |
| `CatalogUpdater` | (Phase 3) Download, verify signature, merge catalog version |

### Integration with existing code

```swift
// ProductImportService (conceptual)
func importProduct(
    _ product: ProductRecord,
    selectedContents: [ProductContent],
    into army: Army,
    defaultState: String,
    context: ModelContext
) {
    for item in selectedContents {
        var draft = UnitDraft(
            name: item.unit,
            qty: item.qty,
            source: product.name,
            state: defaultState
        )
        ArmyStore.addUnit(from: draft, to: army, in: context)
    }
}
```

Faction strings pass through `FactionResolver.normalize()` before army creation or display.

### Permissions & Info.plist

- `NSCameraUsageDescription` — "Scan barcodes on Games Workshop boxes to import units into your collection."

### Remote catalog updates (optional)

- Host `catalog-{version}.json` on GitHub releases or static CDN
- App stores `catalogVersion` in `UserDefaults`
- On launch or manual refresh: if remote version &gt; bundled, download and cache in Application Support
- Lookup order: cached remote → bundled fallback
- Sign or checksum verify to prevent tampering

### Testing

| Test | Type |
|------|------|
| Catalog JSON decodes; indexes are consistent | Unit |
| Barcode → product resolution | Unit |
| GWS code normalization (`56/15` → `56-15`) | Unit |
| Import produces correct `UnitDraft` / model counts | Unit |
| Faction normalization for all catalog factions | Unit |
| Scanner permission denied → graceful fallback to manual search | UI |
| Unknown barcode → search UI | UI |

Fixture: `MiniMusterTests/Fixtures/product-catalog-sample.json`

---

## Phased rollout

### Phase 1 — MVP (recommended first ship)

**Scope**

- Bundled catalog: ~50–80 **multi-unit boxes** (Combat Patrols, Start Collecting, Spearhead, battleforces, army sets)
- EAN barcode scan via VisionKit
- Manual GWS code / name search in catalog
- Import to existing or new army

**Why first:** Highest units-per-scan value; matches existing `Source` conventions in sample CSV.

**Acceptance criteria**

- [ ] Scan known Combat Patrol barcode → correct product preview
- [ ] User can deselect units before import
- [ ] Imported units have `source` = box name, correct faction/game
- [ ] Works fully offline
- [ ] Unknown barcode shows search/manual fallback (no crash)

### Phase 2 — Single kits & OCR

- Expand catalog to individual character/vehicle/sprue boxes
- GWS code OCR fallback on box back
- Improved search (aliases, fuzzy match)

### Phase 3 — Dedup & catalog updates

- If unit with same name + source exists, offer increment qty vs new row
- Remote catalog update download
- Catalog version shown in Settings

### Phase 4 — Community contributions

- Opt-in anonymous barcode submission
- Maintainer merge workflow for quarterly catalog releases

---

## Edge cases & risks

| Issue | Mitigation |
|-------|------------|
| Box name ≠ datasheet name | `canonicalUnit` mapping; show box name, import canonical |
| Multi-faction boxes | Split import across armies or use `Terrain` faction (existing pattern) |
| Same unit, different states | Allow duplicate rows (existing CSV pattern); Phase 3 dedup UX |
| OOP products | Keep in catalog; mark `discontinued: true` |
| Reprint changes EAN | Multiple barcodes per product; `barcodeIndex` |
| Reprint changes contents | Product versioning by year |
| Wrong community data | Curated catalog with PR review; no auto-ingest from APIs |
| Bundle size bloat | Start with box sets only; compress JSON; split by game if needed |
| GW legal | Names + unit lists only; no GW images or long marketing copy; disclaimer in app |
| iPad / Mac | VisionKit scanner works on iPhone/iPad; Mac Catalyst may need manual entry only |

---

## Legal & attribution

- MiniMuster is not affiliated with Games Workshop.
- Product catalog contains factual product identifiers and unit lists for personal collection tracking — same category as community roster data (BSData, Wahapedia-derived tools).
- Do not scrape GW.com or redistribute copyrighted assets.
- If Wahapedia names are used for normalization, follow their attribution guidance ("powered by Wahapedia") wherever rules-derived naming is surfaced to users (optional for pure product names).

---

## Privacy

- Barcode lookup is local (bundled catalog) — no data leaves device in MVP.
- Optional remote catalog update: downloads public JSON only; no user PII.
- Phase 4 community submissions: explicit opt-in; submit barcode + optional product name only.

Update `docs/PRIVACY.md` and `docs/privacy.html` if network catalog updates or submissions ship.

---

## Open questions

1. **Army naming on import** — Default to faction name (`Grey Knights`) or product name (`Grey Knights Combat Patrol`)?
2. **Terrain boxes** — Import into dedicated `Terrain` army or prompt each time?
3. **Spearhead flag** — Auto-set for units in Spearhead boxes when game supports it?
4. **Web app parity** — Should the same `catalog.json` ship with the MiniMuster web app?
5. **Catalog maintenance** — Repo location: `ios/MiniMuster/Resources/` vs shared monorepo package?
6. **Kill Team / Horus Heresy / Old World** — Include in v1 catalog or 40k + AoS only?

---

## Success metrics

| Metric | Target |
|--------|--------|
| Catalog hit rate (MVP boxes) | &gt;95% of scans on curated Combat Patrols |
| Time to import 6-unit box | &lt;30 seconds from scan to confirm |
| Offline success | 100% for bundled catalog |
| Crash-free scanner sessions | No crashes on deny permission / unknown barcode |

---

## References

- Sample import conventions: `MiniMuster/Resources/warhammer_armies.csv`
- Wahapedia data export: https://wahapedia.ru/wh40k10ed/the-rules/data-export/
- GW retailer network (trade-only): https://trade.games-workshop.com/
- VisionKit Data Scanner: Apple `DataScannerViewController` (iOS 16+)
- Related depot pattern (Wahapedia → bundled JSON): https://github.com/fjlaubscher/depot

---

## Appendix — example import mapping

**Input:** Scan EAN `5011921170036` → Broadside `56-15`

**Product preview:**

| Unit | Qty | Models |
|------|-----|--------|
| XV88 Broadside Battlesuit | 1 | 1 |
| MV8 Missile Drone | 1 | 1 |
| Shield Drone | 1 | 1 |

**User selects army:** `T'au Empire` (existing)

**Resulting CSV-equivalent rows:**

```
40k,T'au Empire,T'au Empire,XV88 Broadside Battlesuit,1,XV88 Broadside Battlesuit,Unassembled,,
40k,T'au Empire,T'au Empire,MV8 Missile Drone,1,XV88 Broadside Battlesuit,Unassembled,,
40k,T'au Empire,T'au Empire,Shield Drone,1,XV88 Broadside Battlesuit,Unassembled,,
```

This mirrors how `Combat Patrol 1` and `Skaventide` populate `Source` in the sample collection.
