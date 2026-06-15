# MiniMuster iOS — documentation

Index of project documentation for developers, release managers, and App Store submission.

## Getting started

| Document | Audience | Contents |
|----------|----------|----------|
| [../README.md](../README.md) | Everyone | Overview, quick start, project layout, test commands |
| [DEVELOPMENT.md](DEVELOPMENT.md) | Contributors | Targets, architecture, signing, UI tests, CI |
| [DATA_FORMATS.md](DATA_FORMATS.md) | Contributors & power users | CSV schemas, JSON backup, web interoperability |

## Release & App Store

| Document | Audience | Contents |
|----------|----------|----------|
| [RELEASE_1.0.0.md](RELEASE_1.0.0.md) | Release manager | Ship blockers, polish checklist, manual regression |
| [ROADMAP.md](ROADMAP.md) | Product & contributors | Post–1.0 sequencing — 1.0.1 → 1.2 Muster |
| [APP_STORE.md](APP_STORE.md) | Release manager | Description, keywords, screenshots, review notes |

## Legal & accessibility

| Document | Audience | Contents |
|----------|----------|----------|
| [PRIVACY.md](PRIVACY.md) | Users & App Store | Privacy policy (source for bundled copy) |
| [privacy.html](privacy.html) | App Store | Hosted privacy page (GitHub Pages) |
| [accessibility.html](accessibility.html) | App Store | Hosted accessibility statement |
| [../MiniMuster/Resources/ACCESSIBILITY.md](../MiniMuster/Resources/ACCESSIBILITY.md) | Users | In-app accessibility copy (keep in sync with HTML) |

**Contact email** for all public-facing docs: `jacob.rozell83@gmail.com`

## Future work

| Document | Audience | Contents |
|----------|----------|----------|
| [POLISH_IDEAS.md](POLISH_IDEAS.md) | Product & contributors | User-centric polish backlog — quick wins, 1.0.1, 1.1 |
| [ARMY_LIST_BUILDER.md](ARMY_LIST_BUILDER.md) | Contributors | Muster tab — product spec & UX |
| [ARMY_LIST_BUILDER_IMPL.md](ARMY_LIST_BUILDER_IMPL.md) | Implementers | Muster tab — files, code sketches, tests |
| [ARMY_LIST_BUILDER_AGENT_PROMPT.md](ARMY_LIST_BUILDER_AGENT_PROMPT.md) | Implementers | Copy-paste agent prompt + MCP verify loop |
| [PUSH_NOTIFICATIONS.md](PUSH_NOTIFICATIONS.md) | Contributors | Delight-first local notifications — milestones, backup, digest |
| [CLOUD_SYNC.md](CLOUD_SYNC.md) | Contributors | iCloud + SwiftData sync — mandatory eventual path |
| [MODEL_PHOTOS.md](MODEL_PHOTOS.md) | Contributors | Unit photos, progress timeline, branded share exports |
| [BARCODE_SCANNER.md](BARCODE_SCANNER.md) | Contributors | GW barcode scan & box import spec (1.2+, not scheduled) |

## GitHub Pages

The `docs/` folder is the site root when GitHub Pages is enabled (repo → Settings → Pages → branch `main`, folder `/docs`).

| URL | File |
|-----|------|
| `https://jacobrozell.github.io/MiniMuster/` | [index.html](index.html) |
| `https://jacobrozell.github.io/MiniMuster/privacy.html` | [privacy.html](privacy.html) |
| `https://jacobrozell.github.io/MiniMuster/accessibility.html` | [accessibility.html](accessibility.html) |

Declare the privacy and accessibility URLs in App Store Connect → App Information.

## Scripts

| Script | Purpose |
|--------|---------|
| `../scripts/test-coverage.sh` | Unit + UI tests with coverage report |
| `../scripts/capture-app-store-screenshots.sh` | Marketing screenshots via UI automation |
| `../scripts/generate-launch-assets.py` | Regenerate launch screen image assets |
