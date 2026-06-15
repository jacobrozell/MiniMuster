# Spec — encouraging local notifications

**Status:** Future release — spec only (not scheduled)  
**Target:** 1.1+ (after 1.0 ship; pairs well with photos & cloud sync milestones)  
**App:** MiniMuster (iOS)

> **Delight-first.** Notifications celebrate progress and protect data — they never guilt users for not painting. See anti-patterns below.

**See also:** [CLOUD_SYNC.md](CLOUD_SYNC.md) · [POLISH_IDEAS.md](POLISH_IDEAS.md) · [RELEASE_1.0.0.md](RELEASE_1.0.0.md)

---

## Summary

Add **opt-in, on-device local notifications** that feel like a hobby buddy checking in — not a productivity app nagging you to hit streaks.

All v1 notification types are scheduled with `UNUserNotificationCenter` on the device. **No push server, no APNs token, no analytics.** Content is derived from collection stats already in SwiftData.

Today, backup encouragement is an in-app alert after 14 days ([`RootView.checkBackupReminder`](../MiniMuster/App/RootView.swift)). This spec extends that pattern to the lock screen — and adds milestone celebrations once cloud sync reduces manual-backup anxiety.

---

## Goals

| Goal | Rationale |
|------|-----------|
| Celebrate real progress | Army hits 100%, first unit battle-ready, sprue count drops — moments worth a smile |
| Protect data (pre-cloud) | Gentle backup nudges when iCloud sync is off |
| Re-engage without shame | “You’ve got 12 on the sprue” not “You haven’t painted in 9 days” |
| Stay local-first | No server, no account, no tracking |
| Respect attention | Hard caps, quiet hours, granular toggles |

## Non-goals

- Remote push / marketing campaigns
- Paint-session timers or “wash is dry” reminders (too niche for v1; see [POLISH_IDEAS.md](POLISH_IDEAS.md) Live Activity idea)
- Daily streaks, XP, or gamification
- Notifications that fire more than **3× per week** by default
- Mandatory opt-in — permission is requested only when user enables a category in Settings

---

## Design principles

1. **Celebrate, don’t scold.** Copy uses “you finished…”, “nice progress”, “ready when you are” — never “you forgot” or “don’t break your streak”.
2. **Tied to real data.** Every notification maps to a measurable event (stage change, army %, backup age).
3. **Actionable tap.** Opens the relevant screen via `minimuster://` deep link.
4. **Silence is a feature.** Default off until user opts in; easy global mute.
5. **Cloud-aware.** Backup notifications auto-suppress when [iCloud sync is healthy](CLOUD_SYNC.md).

---

## Notification categories

### 1. Milestones (delight) — default **on** when notifications enabled

| Trigger | Example copy | Deep link |
|---------|--------------|-----------|
| Army reaches 100% pipeline progress | *Ultramarines are mustered — every unit battle-ready. For the Emperor!* | `minimuster://army/{id}` |
| Roster becomes 100% fieldable (Phase 2) | *Your Grey Knights list is fully fieldable from collection.* | `minimuster://muster/{id}` |
| First unit reaches final pipeline stage | *Intercessors crossed the finish line. Snap a victory photo?* | `minimuster://unit/{id}` |
| Sprue count hits 0 (collection-wide) | *No models left on the sprue. The pile of shame is defeated.* | `minimuster://collection/overview` |
| N models advanced in one day (threshold: 5+, once per day max) | *Big session — 8 models moved forward today.* | `minimuster://collection/overview` |
| First photo added to a unit | *Progress pic saved. Your bench is coming alive.* | `minimuster://unit/{id}` |

**Rules**

- Fire at most **one milestone notification per calendar day**.
- Army-complete fires **once per army** (store `celebratedArmyIds` in `AppConfiguration` or UserDefaults).
- Respect Reduce Motion — no requirement for rich notification attachments in v1.

### 2. Backup & safety — default **on** when notifications enabled; **off** when iCloud sync healthy

| Trigger | Example copy | Deep link |
|---------|--------------|-----------|
| 14+ days since `lastBackupAt` and no iCloud sync | *It’s been a while since your last backup. Export takes 10 seconds in Settings.* | `minimuster://settings/data` |
| 30+ days (escalation, once) | *Your collection has grown — worth a JSON backup before the next hobby splurge.* | `minimuster://settings/data` |

**Rules**

- Mirrors existing in-app 14-day alert; notification is **additive**, not duplicate same-day (coordinate via shared `BackupReminderService`).
- Snooze: 7 days (reuse `backupReminderSnoozedUntil` or move to `AppConfiguration`).
- When [CLOUD_SYNC.md](CLOUD_SYNC.md) reports last successful upload, suppress this category entirely.

### 3. Weekly digest (optional) — default **off**

| Trigger | Example copy | Deep link |
|---------|--------------|-----------|
| Sunday 7 PM local (user-configurable) | *This week: 4 models advanced, 23 on the sprue. Open MiniMuster* | `minimuster://collection/overview` |

**Rules**

- Only schedule if user has opened app at least once in prior 30 days.
- Skip week if zero stage changes (don’t send “0 progress” — that feels like scolding).

### 4. Gentle return (optional) — default **off**

| Trigger | Example copy | Deep link |
|---------|--------------|-----------|
| 21 days since last app open | *Still 12 models on the sprue whenever you’re ready.* | `minimuster://collection/backlog` |

**Rules**

- Maximum **once per 30 days**.
- Never mention “we miss you” or inactivity guilt.
- Cancel immediately on next app open.

---

## Settings UI

**Settings → Notifications** (new section)

| Control | Type | Default |
|---------|------|---------|
| Allow notifications | Master toggle → triggers system permission if enabling | Off |
| Milestones | Toggle | On (if master on) |
| Backup reminders | Toggle | On (if master on; hidden when iCloud sync on) |
| Weekly digest | Toggle | Off |
| Gentle return | Toggle | Off |
| Digest day & time | Picker | Sunday 7:00 PM |
| Quiet hours | Toggle + start/end | On, 10 PM – 8 AM |

Footer copy: *Notifications are scheduled on your device. Nothing is sent to our servers.*

If system permission denied: inline link **Open Settings** to enable in iOS.

---

## Technical approach

### Stack

```text
┌─────────────────────────────────────────────────────────┐
│  SwiftUI — Settings, milestone hooks in ArmyStore, etc. │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  NotificationScheduler (@MainActor)                     │
│  — rescheduleAll() on launch + after data mutations     │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  UNUserNotificationCenter (local only)                  │
└─────────────────────────────────────────────────────────┘
```

### `NotificationScheduler` responsibilities

- Request authorization when user enables master toggle.
- Register notification categories with actions (optional v1.1: *Open*, *Snooze backup*).
- `scheduleMilestone(_:)` — immediate one-shot on event.
- `rescheduleRecurring()` — weekly digest, return nudge, backup check.
- `cancelAll()` / `cancel(category:)` on preference change.
- Debounce: coalesce rapid advances into single end-of-day summary if over daily cap.

### Hook points

| Event | Source |
|-------|--------|
| Stage change | `ArmyStore.setState`, `ArmyStore.advance`, `SquadStore` |
| Army progress 100% | After unit advance in army |
| Backup exported | `DataActions.backupJSON` |
| App backgrounded | `scenePhase` — refresh return-nudge schedule |
| iCloud sync status | `CloudSyncService` (future) |

### Deep links

Extend [`AppDeepLink`](../MiniMuster/Support/AppDeepLink.swift):

| URL | Destination |
|-----|-------------|
| `minimuster://collection/backlog` | Existing |
| `minimuster://collection/overview` | Overview sheet |
| `minimuster://settings/data` | Settings → Data |
| `minimuster://army/{uuid}` | Army detail |
| `minimuster://unit/{uuid}` | Unit detail |
| `minimuster://muster` | Muster home ([ARMY_LIST_BUILDER.md](ARMY_LIST_BUILDER.md)) |
| `minimuster://muster/{uuid}` | Roster editor |

Handle in `RootView.onOpenURL` alongside widget links.

### Persistence (`AppConfiguration` additions)

```swift
var notificationsEnabled: Bool = false
var notifyMilestones: Bool = true
var notifyBackup: Bool = true
var notifyWeeklyDigest: Bool = false
var notifyGentleReturn: Bool = false
var notificationDigestWeekday: Int = 1        // 1 = Sunday
var notificationDigestHour: Int = 19
var notificationQuietHoursEnabled: Bool = true
var celebratedCompleteArmyIds: [UUID] = []    // milestone dedup
```

Store snooze timestamp in `AppConfiguration` (migrate from `@AppStorage`).

---

## Rate limits (hard)

| Limit | Value |
|-------|-------|
| Max notifications per rolling 7 days | 3 (user can raise to 5 in Settings — “More celebrations”) |
| Max per calendar day | 1 (except backup + milestone same day: allow 2 max) |
| Quiet hours | No delivery; defer to next allowed window |
| Permission denied | No retries; show in-app banner on relevant action instead |

---

## Privacy & App Store

- Update [`PRIVACY.md`](PRIVACY.md): notifications are local; no server transmission; optional permission.
- No notification content in iCloud (only prefs).
- App Store privacy questionnaire: notifications are user-initiated feature, not tracking.

**Info.plist:** No extra keys for local notifications. If camera notifications added later, separate concern.

---

## Implementation phases

### Phase 1 — Foundation (1.1)

- [ ] `NotificationScheduler` + permission flow
- [ ] Settings → Notifications section
- [ ] Milestone: army 100%, first unit complete
- [ ] Deep links: army, unit, settings/data, overview
- [ ] Unit tests: scheduling logic, rate caps, quiet hours (inject `Date`/`Calendar`)

### Phase 2 — Safety & digest (1.1)

- [ ] Backup notification (coordinate with in-app alert)
- [ ] Weekly digest
- [ ] Migrate snooze to `AppConfiguration`
- [ ] UI tests: permission denied state

### Phase 3 — Polish (1.2)

- [ ] Gentle return nudge
- [ ] Photo-added milestone
- [ ] Notification Service Extension only if rich images needed (likely skip)
- [ ] Suppress backup category when cloud sync healthy

---

## Copy bank (tone reference)

**Do**

- *Ultramarines are mustered — 100% battle-ready.*
- *Big painting session: 6 models advanced today.*
- *23 models still on the sprue — whenever you’re ready.*
- *Backup reminder: export from Settings → Data takes a moment.*

**Don’t**

- *You haven’t opened MiniMuster in 3 weeks!*
- *Don’t lose your streak!*
- *Other painters advanced 50 models…*
- *You’re falling behind on your backlog.*

---

## Open questions

1. Should army-complete copy use **faction-flavored** variants (Imperium, Chaos, etc.) or stay neutral?
2. **“More celebrations”** toggle — is 5/week too many for a hobby app?
3. Integrate with **Focus modes** / iOS notification summary automatically, or document for users?
4. When cloud sync ships, rename category to **“Data safety”** and only fire on sync errors?

---

## Changelog

| Date | Notes |
|------|-------|
| 2026-06-15 | Initial spec — delight-first local notifications |
