# App Store Connect — MiniMuster 1.0.0

Draft metadata for App Store submission. Copy into App Store Connect when ready.

---

## Privacy policy URL

**Hosted page (enable GitHub Pages on this repo, source: `/docs`):**

`https://jacobrozell.github.io/MiniMuster/privacy.html`

**Setup:** GitHub repo → Settings → Pages → Build from branch `main`, folder `/docs`.

Until Pages is enabled, use the in-repo file for review: `docs/privacy.html`.

---

## App information

| Field | Value |
|-------|--------|
| **Name** | MiniMuster |
| **Subtitle** | Track armies, units & paints |
| **Bundle ID** | com.musterroll.app |
| **SKU** | minimuster-ios-1 |
| **Primary category** | Utilities |
| **Secondary category** | Lifestyle |
| **Age rating** | 4+ (no restricted content) |
| **Copyright** | © 2026 Jacob Rozell |

---

## Description

Track your Warhammer armies, painting progress, and paint stash — all on your device.

MiniMuster is a local-first hobby tracker built for painters and collectors. Organize armies and units, advance models through your custom painting pipeline, manage your paint inventory, and see how many models are still on the sprue.

**Features**
• Browse armies with search, filters, and collection overview stats
• Swipe to advance units through your painting stages
• Squad members, notes, tags, and per-army custom pipelines
• Paint inventory with list and grid views
• Import and export CSV — compatible with the MiniMuster web app
• Full JSON backup and restore
• Home screen widget: models on the sprue at a glance
• iPad split view for army → units → detail
• Dark mode and accessibility support

**Your data stays on your device.** No account, no cloud sync, no tracking.

For the Emperor. For the Great Horned Rat. Sigmar watches.

---

## Promotional text (optional, 170 chars max)

Track armies, units, and paints locally. Import from the web app, advance your pipeline, and check sprue counts from the home screen widget.

---

## Keywords

warhammer,age of sigmar,40k,painting,hobby,miniatures,army,paint,tracker,collection,tabletop,wargaming,sprue

_(100 characters max — trim if App Store Connect rejects)_

---

## Support URL

Use the GitHub repo or a personal site:

`https://github.com/jacobrozell/MiniMuster`

---

## Marketing URL (optional)

Same as support URL, or omit.

---

## App Privacy (nutrition labels)

| Question | Answer |
|----------|--------|
| Data collection | **No, we do not collect data** |
| Data linked to you | None |
| Data used to track you | None |
| Third-party SDKs | None |

Aligns with `docs/PRIVACY.md` and in-app Settings → Privacy Policy.

---

## Screenshots

Capture with:

```bash
# iPhone (6.7" — App Store required size)
./scripts/capture-app-store-screenshots.sh --iphone

# iPad Pro 13" (recommended for iPad listing)
./scripts/capture-app-store-screenshots.sh --ipad

# Both devices
./scripts/capture-app-store-screenshots.sh --all
```

Output:
- `.app-store-screenshots/iphone/` — 6 PNGs (iPhone 17 Pro Max)
- `.app-store-screenshots/ipad/` — 6 PNGs (iPad Pro 13-inch M5)

| File | Screen |
|------|--------|
| `01-empty-collection` | Empty collection welcome |
| `02-collection-armies` | Sample armies loaded |
| `03-army-units` | Hallowed Knights unit list |
| `04-unit-detail` | Unit detail |
| `05-paints` | Paint inventory |
| `06-settings-data` | Settings / Data section |

**Required device sizes (verify in App Store Connect at submit time):**
- 6.7" display (iPhone 15 Pro Max / 16 Pro Max class) — `./scripts/capture-app-store-screenshots.sh --iphone` (uses `iPhone 17 Pro Max`)
- 6.5" if still listed — `IPHONE_DESTINATION='platform=iOS Simulator,name=iPhone 11 Pro Max' ./scripts/capture-app-store-screenshots.sh --iphone`
- iPad Pro 13" for iPad listing — `./scripts/capture-app-store-screenshots.sh --ipad` (uses `iPad Pro 13-inch (M5)`)

---

## What's New (1.0.0)

Initial release.

• Native collection browser with search, filters, and overview stats
• Unit detail editing, swipe advance, and batch select
• Paint inventory with collection deep links
• Import/export and backup compatible with the web app
• Local-first — your data stays on device
• Home screen widget
• iPad split-view support

---

## Review notes (optional)

MiniMuster is a local hobby tracker. No login is required. To explore with data, tap **Load sample data** on the empty collection screen or from Settings → Data. No network access is needed for core functionality.

---

## TestFlight checklist

- [ ] iPhone SE / small phone — layout OK
- [ ] iPhone Pro Max — layout OK
- [ ] iPad — split view: army → units → detail
- [ ] Large text (AX5) — no clipped critical UI
- [ ] Cold launch — no crash
- [ ] Widget updates after sample load / advance / delete

---

## Pre-submission

- [ ] `MARKETING_VERSION` = `1.0.0` in `project.yml`
- [ ] Privacy URL live and matches bundled policy
- [ ] Screenshots uploaded for all required sizes
- [ ] Manual regression checklist (`docs/RELEASE_1.0.0.md`) passed on iPhone + iPad
- [ ] CI green (unit + UI tests)
