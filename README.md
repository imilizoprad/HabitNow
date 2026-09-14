# HabitNow Arena

**A serverless, peer-to-peer competitive habit tracker for Android.**
Build habits, challenge friends on the same network, put points on the
line, settle in the Arena — no accounts, no servers, no cloud. Ever.

```
Today          Habits         Tasks          Arena          You
check-ins +    streaks &      one-shot +     radar, duels,  awards,
perfect-day    heatmaps       recurring +    league,        stats &
ring           & stats        focus timer    forfeits       settings
```

---

## How the competitive layer works (zero infrastructure)

HabitNow Arena is fully **peer-to-peer**. Two phones on the same Wi-Fi
(or one phone's hotspot) find each other and sync directly:

```
┌──────────────┐  UDP broadcast :45102 (presence, every 2.5 s) ┌──────────────┐
│   Device A   │ ◄───────────────────────────────────────────► │   Device B   │
│              │                                               │              │
│  TCP :45103  │ ── hello → sync.request → sync.state ───────► │              │
│              │ ◄───────────── checkin.delta (live) ────────  │              │
└──────────────┘                                               └──────────────┘
```

- **Discovery** — each device announces itself with a magic-prefixed UDP
  broadcast and keeps a freshness-TTL map of visible peers. A Wi-Fi
  multicast lock is held on Android so local broadcasts are received.
- **Sessions** — length-prefixed JSON frames over raw TCP, with a mutual
  `hello` handshake and a watchdog for half-open sockets. Duplicate
  connection races are resolved deterministically (larger device id keeps
  the outgoing connection) so both sides converge on exactly one session.
- **Sync** — full-state exchange on connect, then live deltas. Every
  shared entity carries `updatedAt`/`updatedBy`; conflict resolution is
  last-write-wins with a deterministic device-id tiebreak, so all peers
  converge to identical state with no central arbiter.
- **Trust** — peers only accept challenges/forfeits that involve them, and
  only merge check-ins scoped to the *other* device's actor id. Your
  private habits, notes and tasks never leave the device.

### Why settlement is trustworthy without a server

Challenge totals are computed by a pure, deterministic `ScoreEngine`
(`lib/data/score_engine.dart`) that runs **identically on both devices**
over the merged check-in ledger. Because the inputs converge and the
functions are total, both phones independently derive the same winner —
that's what makes "winner takes the stake" safe without a referee.

## Punishments, both kinds

1. **Stakes** — every duel puts points on the line (`+stake` winner,
   `−stake` loser, draws refund). Stakes feed the weekly league and the
   all-time scoreboard via an append-only scoring ledger.
2. **Forfeits** — the winner can assign a real-world dare ("no sugar for
   3 days"). The bearer serves it, the assigner confirms over the wire,
   and missed deadlines auto-fail (−20) on both devices.

## Features

- **Habits** — weekday cadences, reminders (exact alarms, reboot-safe via
  `BOOT_COMPLETED` restore), 16-week GitHub-style heatmap, streaks,
  best-streak, 30-day consistency rate.
- **Today** — animated completion ring, perfect-day streak, forfeit
  alerts, pending invites, live duel mini-cards.
- **Tasks** — one-shot + recurring (daily / chosen days / every N days),
  priorities, categories, swipe-to-delete with undo.
- **Focus timer** — tap-to-start ring from the original HabitNow,
  redesigned; sessions are logged and feed awards.
- **Awards** — 12 milestones with a celebration overlay + confetti.
- **Light & dark themes** — warm-paper light, blue-shifted dark, tuned
  type scale, tabular numerals for counters, one motion language.

## Building (arm64-v8a)

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
# → build/app/outputs/flutter-apk/app-release.apk
```

The Android project is pre-configured for `arm64-v8a` only
(`ndk.abiFilters` in `android/app/build.gradle`), AGP 8.7 / Gradle 8.12 /
Kotlin 2.0, `minSdk 24`, `targetSdk 35`. Release builds sign with the
debug keystore for frictionless installs — add your own `signingConfig`
before any store upload.

Requirements: Flutter 3.38+ (Dart 3.6+). The codebase has **zero
third-party pub dependencies** — networking is pure `dart:io`, persistence
is a purpose-built platform channel — so builds are fully reproducible.

## Architecture

```
lib/
├── main.dart                 entry point
├── app.dart                  MaterialApp, AppScope (InheritedNotifier DI)
├── app_routes.dart           named routes + house page transition
├── core/
│   ├── theme/                design tokens, palette (ThemeExtension), type, ThemeData
│   ├── widgets/              AppButton, AppCard, AnimatedCheck, ProgressRing,
│   │                         DuelBar, heatmap, sheets, toasts, confetti…
│   ├── p2p/                  protocol framing, UDP discovery, TCP sessions, sync engine
│   ├── storage/              atomic JSON persistence via platform channel
│   ├── native/               reminders bridge
│   └── utils/                dates, ids, haptics
├── data/
│   ├── models/               Profile, Habit(+checkins), Task, Challenge, Forfeit, Ledger
│   ├── local_db.dart         in-memory store + debounced JSON persistence
│   ├── score_engine.dart     deterministic scoring/settlement math
│   └── seed.dart             first-run content
├── state/                    AppStore → HabitStore / TaskStore / ArenaStore
└── features/                 one folder per tab + sheets & detail pages
```

State management is plain `ChangeNotifier` + `InheritedNotifier` — no
codegen, no streams, surgical rebuilds. Every widget that listens,
listens to the narrowest store that can change.

## Testing two devices

1. Install the APK on two phones.
2. Put them on the same Wi-Fi (or start a hotspot from one and join from
   the other). AP-isolated guest networks won't work.
3. Open the app on both — each appears in the other's **Arena → Radar**.
4. Tap **Connect**, then **Duel ⚔️**: pick the shared habit, stake and
   length. Accept on the second phone and check in daily.

## License

MIT — inherited from the base project.
