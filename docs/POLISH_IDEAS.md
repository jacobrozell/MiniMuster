# Polish ideas — user lens

Brainstorm of small-to-medium improvements that make MiniMuster feel more *finished* for hobbyists — not new domain features, but the moments that build trust, speed, and delight.

**Status:** Living backlog — pick items for 1.0.1, 1.1, or photo Phase 2+  
**See also:** [RELEASE_1.0.0.md](RELEASE_1.0.0.md) · [MODEL_PHOTOS.md](MODEL_PHOTOS.md) · [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md) · [CLOUD_SYNC.md](CLOUD_SYNC.md) · [BARCODE_SCANNER.md](BARCODE_SCANNER.md)

---

## How to read this

Each idea is written as a user thought (“I wish…”, “When I…”) with a suggested fix. Tags:

| Tag | Meaning |
|-----|---------|
| **Quick** | ~1 session, mostly UI/copy |
| **Medium** | A few files, no new models |
| **Larger** | New surface area or infra |
| **1.0.1** | Safe post-ship polish |
| **1.1+** | Pairs with photos, sync, or bigger bets |

Impact: **High** = many users feel it daily · **Medium** = power users or specific workflows · **Delight** = memorable but not blocking

---

## Personas (who we’re polishing for)

| Persona | Typical session | Cares most about |
|---------|-----------------|------------------|
| **Bench painter** | 5 min between coats — advance one unit, check what’s next | Speed, swipe, undo, haptics |
| **Weekend assembler** | Adds boxes, sets everything to “On the Sprue” | Bulk add, defaults, less typing |
| **Army organizer** | Renames, moves units, custom pipelines per faction | Context menus, iPad layout, filters |
| **Paint hoarder** | Logs Citadel pots, links paints to units | Grid view, source deep links, search |
| **Migrator** | Coming from web CSV / JSON backup | Import clarity, round-trip trust |
| **Show-off** | Posts WIP to Discord / Instagram | Photos, share exports, cover thumbnails |
| **Anxious archivist** | Fears losing years of data | Backup reminders, export success, storage visibility |

---

## First launch & empty collection

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “Is this app for me?” | Onboarding page 4 could show a *single* screenshot-style preview (collection + swipe) instead of only icons — sets expectations before they tap Load sample. | Quick | Medium |
| “I don’t want demo data.” | Empty state: secondary path “Start empty” is already there; add one line: *You can import anytime from Settings → Data.* | Quick | Medium |
| “What do I do first?” | After onboarding → Load sample, subtle banner: *Swipe a unit right to advance its stage* (links to existing `SwipeAdvanceTip`). | Quick | High |
| “I closed onboarding too fast.” | Settings → Help: **Show welcome tour again** (resets `hasSeenOnboarding`). | Quick | Medium |
| “Where’s Settings?” | Empty collection toolbar gear is easy to miss on iPad — ensure Settings is reachable from tab bar long-press or collection overflow if we add more entry points later. | Medium | Low |

---

## Daily painting loop

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “I advanced the wrong unit.” | Undo banner already exists — add VoiceOver hint on first advance: *Shake or tap Undo in the banner.* | Quick | Medium |
| “Did that swipe work?” | Row briefly highlights or chip animates (respect Reduce Motion) on successful advance — haptics exist, visual confirm helps in bright sunlight. | Quick | High |
| “I always advance from detail, not the list.” | Unit detail: prominent **Advance one stage** button when `canAdvance` (toolbar or section footer), same as squad members. | Quick | High |
| “My Intercessors are all at different stages.” | Squad member rows: swipe-to-advance parity with unit list (if not already identical affordance). | Medium | High |
| “What’s left on this army?” | Army header: tap progress ring → scroll to first non-finished unit (or filter to WIP). | Medium | Medium |
| “I finished a whole batch tonight.” | After batch advance: celebratory copy — *Advanced 6 units to Basecoated* — and optional confetti-free haptic pattern (success already partial). | Quick | Delight |
| “Which unit should I paint next?” | Overview or army detail: **Suggest next** — highest qty unit still on first pipeline stage, or oldest `updatedAt` if we add touch timestamps later. | Larger | Medium |
| “I use the same stages for every army.” | Per-army pipeline editor: show *Using global pipeline* badge when unset; one tap to customize. | Quick | Medium |

---

## Browsing, search & filters

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “I only care about WIP this week.” | Pin **WIP** quick filter to collection toolbar (or remember last filter in `AppConfiguration`). | Medium | High |
| “Search didn’t find ‘Ogor’.” | Search matches `ogors` today — document fuzzy behavior in empty search results: *Try partial names or army names.* | Quick | Low |
| “How filtered am I?” | When filters active: persistent chip bar under nav title (tap X to clear one, Clear all). | Medium | High |
| “I want to see progress for just Ultramarines.” | Overview already respects filters — add footnote when scoped: *Showing 3 armies, 42 models.* | Quick | Medium |
| “Too many armies to scroll.” | Army list: optional sort (A–Z, progress %, model count) — `sortIndex` exists for manual order later. | Medium | Medium |
| “I forgot what this unit’s tags mean.” | Tag chips on unit row/detail with long-press → edit/remove. | Medium | Low |

---

## Unit & army management

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “I bought another box of the same kit.” | Duplicate unit is great — after duplicate, offer *Merge quantities* if same name+state in same army. | Medium | Medium |
| “Wrong army.” | Move unit is done — add **Move** to unit detail toolbar (not only context menu). | Quick | Medium |
| “I typo’d the army name.” | Army rename from list context menu — done; ensure iPad sidebar shows same menu on long-press. | Quick | Low |
| “I need to add 10 units from a combat patrol.” | Add unit sheet: **Add another** toggle — keep sheet open after save. | Quick | High |
| “Reorder matters for painting priority.” | Army unit list: drag reorder in edit mode (deferred in release plan — high user ask). | Medium | High |
| “Notes are buried.” | Unit notes: show first line under name in row when non-empty (truncated). | Quick | Medium |

---

## Photos & progress (in progress — [MODEL_PHOTOS.md](MODEL_PHOTOS.md))

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “I just primed — let me snap it.” | Photo prompt on advance (Phase 2) — default on, Settings toggle. | Medium | High |
| “Which photo is the thumbnail?” | Long-press photo → **Set as cover**; star badge on cover in gallery. | Quick | High |
| “I want to compare before/after.” | Before/after slider on unit detail (Phase 2). | Medium | Delight |
| “I took this at the wrong stage.” | Edit photo stage chip (picker from pipeline). | Quick | Medium |
| “Full-screen gallery?” | Tap cover → paging `fullScreenCover` with pinch zoom. | Medium | High |
| “Camera, not library.” | **Take photo** via `UIImagePickerController` / camera button next to library picker. | Medium | High |
| “My army list should look like Instagram.” | Optional list mode: larger thumbs when cover exists (compact vs visual toggle in army detail). | Medium | Delight |
| “Share my progress.” | Branded export / GIF (Phase 3) — biggest social polish win. | Larger | Delight |

---

## Paints tab

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “I ran out of Macragge Blue.” | Paint detail: **Mark empty** toggle → dims row, sorts to bottom optionally. | Medium | Medium |
| “Which units use this paint?” | Source link exists — show count badge on paint row: *Used in 4 units*. | Medium | Medium |
| “I have 200 pots.” | Grid view: group by brand or type (Base / Layer / Shade) from CSV type column. | Medium | Medium |
| “Quick add at the store.” | Add paint sheet: remember last brand; barcode later ([BARCODE_SCANNER.md](BARCODE_SCANNER.md)). | Quick | Medium |
| “Wrong name on import.” | Inline rename on paint row (swipe or context menu) without opening full detail. | Quick | Medium |

---

## Data, backup & trust

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “Did my backup work?” | After export: show file name + size in success banner; *Open in Files* button. | Quick | High |
| “How long since I backed up?” | **Last backup** in Settings → Data — ✅ shipped (`lastBackupAt` on full JSON export). Polish: relative date (*3 days ago*), amber when stale + iCloud off. | Quick | High |
| “I’m scared to tap Restore.” | Restore confirmation: bullet list of what will be replaced; require typing `RESTORE` for extra safety (optional setting). | Medium | Medium |
| “Import said 3 warnings.” | Import results sheet — done; add **View skipped rows** expandable detail. | Quick | Medium |
| “Where did my photos go?” | When photos ship: backup section explains CSV vs JSON vs zip; storage row shows photo disk usage. | Medium | High |
| “I use web and iOS.” | Settings → Data: one-line **Sync workflow** doc link (export JSON on web → restore on iOS). Superseded long-term by [CLOUD_SYNC.md](CLOUD_SYNC.md). | Quick | Medium |

---

## Widget & glance surfaces

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “Sprue count isn’t enough.” | Widget family: small = sprue count; medium = sprue + % complete progress bar. | Medium | High |
| “Tap widget — take me to WIP.” | Deep link variants: sprue backlog vs filtered WIP collection. | Medium | Medium |
| “Show my latest finished model.” | Photo widget (Phase 4) — random cover from *Battle Ready* stage. | Larger | Delight |
| “Live Activity for paint drying?” | Silly but memorable — timer Live Activity (*Wash drying — 20 min*). Fun 1.2+ easter egg. | Larger | Delight |

---

## iPad & multitasking

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “Three columns feel cramped.” | Verify unit detail uses readable max width in regular horizontal size class. | Quick | Medium |
| “I want collection + paints side by side.” | Stage Manager / multi-window — ensure each window gets own `ModelContainer` or document group (future). | Larger | Low |
| “Keyboard shortcuts?” | ⌘F search, ⌘N new unit when army selected — pro iPad polish. | Medium | Medium |

---

## Accessibility & comfort

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|--------|
| “VoiceOver on photos?” | Gallery: explicit actions — Set cover, Delete, stage label. | Quick | High |
| “Too much animation.” | Audit remaining implicit animations against Reduce Motion (splash, tips, progress ring — partial). | Quick | Medium |
| “Bold Text / AX5.” | Spot-check photo section and overview ring at AX5 in screenshot variant. | Quick | Medium |
| “I use Increase Contrast.” | State chips: verify contrast on custom pipeline colors; warn in editor if hex is too light. | Medium | Medium |

---

## Delight & identity (Warhammer hobby flavor)

| User thought | Polish idea | Effort | Impact |
|--------------|-------------|--------|--------|
| “This could be any tracker app.” | Faction crest on army row is good — subtle faction accent color on army detail nav bar. | Quick | Delight |
| “I hit 100% on an army.” | First time army reaches 100% progress: tasteful banner *Army complete — for the Emperor!* (faction-flavored copy optional). Also: lock-screen milestone via [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md). | Quick | Delight |
| “Pipeline stage names are boring.” | Default pipeline is fine; Settings tip: *Rename stages to match your desk — e.g. “Basing” or “NMM highlights”.* | Quick | Low |
| “More tips?” | TipKit: filter sheet, batch select, paint source link, add photo — one tip per feature, not all at once. | Medium | Medium |
| “App icon on my home screen.” | Done — ensure widget uses matching crest glyph for brand consistency. | Quick | Low |

---

## Suggested priority stacks

### Ship-adjacent (1.0.1 — no new models)

Good follow-up release while photos finish Phase 2:

1. Unit detail **Advance** button + row visual confirm on swipe  
2. **Add another** on add-unit sheet  
3. **Last backup** date + richer export success  
4. Filter **chip bar** when active  
5. **Show welcome tour again** in Settings  
6. Photo: **Set as cover** + full-screen tap on cover  

### Photo release bundle (1.1)

Align with [MODEL_PHOTOS.md](MODEL_PHOTOS.md) Phase 2–3:

1. Prompt on advance + timeline view  
2. Camera capture + full-screen gallery  
3. Share export / before-after  
4. Backup v4 + storage row  

### Bigger bets (1.2+)

- Army/unit drag reorder  
- Barcode scan ([BARCODE_SCANNER.md](BARCODE_SCANNER.md))  
- **Muster tab** — army list builder ([ARMY_LIST_BUILDER.md](ARMY_LIST_BUILDER.md))  
- iCloud sync — [CLOUD_SYNC.md](CLOUD_SYNC.md) (mandatory eventual path)  
- Encouraging notifications — [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md)  
- Shortcuts / App Intents (“Advance [unit]”)  
- Medium widget + WIP deep link  

---

## Anti-patterns (don’t polish into complexity)

- **No gamification XP** — hobbyists aren’t looking for streaks or badges unless opt-in and subtle.  
- **No mandatory accounts** — local-first is the brand; iCloud uses the user’s Apple ID ([CLOUD_SYNC.md](CLOUD_SYNC.md)), not a MiniMuster login.  
- **No notification spam** — see [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md): celebrate progress, cap at 3/week, no guilt copy.  
- **No auto cloud upload of photos** — sync is user’s private iCloud when enabled; exports remain user-initiated.  
- **Avoid settings bloat** — group advanced options under “Data” or “Photos,” not top-level clutter.  

---

## Open questions

1. Should **last-used filter** persist across launches or reset to “all”?  
2. **Army complete** celebration — once per army or every time they hit 100% after adding units?  
3. **List vs visual** unit rows — per-army setting or global?  
4. **Merge duplicate units** — same name only, or fuzzy match on source box?  

---

## Changelog

| Date | Notes |
|------|-------|
| 2026-06-15 | Initial brainstorm from 1.0.0 ship + in-progress photos work |
| 2026-06-15 | Linked PUSH_NOTIFICATIONS + CLOUD_SYNC specs; last backup marked shipped |
