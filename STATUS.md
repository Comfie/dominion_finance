# Dominion App — Development Status

_Last updated: 21 July 2026_

Quick orientation for picking development back up. The ecosystem is three sibling
repos in `/Volumes/MacBackup/Projects/personal/`:

| Repo | Stack | Role | State |
|------|-------|------|-------|
| `dominion_app` | Flutter + Riverpod | Mobile app (this repo) | Local-first mode complete, cloud mode untested against a live API |
| `dominion-api` | .NET 10 + EF Core | Backend for the mobile app (JWT) | ~95% done; missing bank import, push, snapshot automation |
| `dominion-core` | Next.js 16 + Prisma | Original web app / PWA | Hardened for sharing (zod validation, rate limiting); deployable |

## What's done in this repo

- **Repository layer** (`lib/repositories/`) — providers depend on abstract
  interfaces; `remote/` (Dio → .NET API) and `local/` (Drift/SQLite) implementations.
- **Local-first storage** — full app works with no account: Drift database
  (`lib/data/local/database.dart`), persisted `StorageMode` (secure-storage key
  `storage_mode`, loaded in `main()` before the first route), "Continue without an
  account" on the login screen, mode switch in Settings → Data storage.
- **AI gating** — receipt scan + insights require an account (dialog explains why);
  `AiRepository` abstraction, widgets no longer touch `ApiClient` directly.
- **Settings** — fields are actually editable (income, payday, currency, budget)
  and persist; single-row invariant enforced with self-healing (see the race note
  below).
- **Backup/restore** — Settings → Data storage → Export/Import. Versioned JSON
  envelope, share-sheet export, upsert-by-id import (idempotent, non-destructive).
- **Bug sweeps** — enum-as-String latent crashes fixed across dashboard/expenses/
  category-management (screens had never rendered real data before local mode);
  category filter and category stats now actually work.
- **Tests** — 20 passing (`flutter test`): local repositories, settings race
  regression, storage mode, backup round-trip/idempotence/validation.
  `flutter analyze` baseline: 124 pre-existing infos/warnings, no errors.

## What's left (in rough priority order)

1. **Point cloud mode at a real API.** `AppConstants.apiBaseUrl` is
   `http://localhost:5000/api` — unreachable from devices/emulators (emulator →
   host is `10.0.2.2`). Deploy `dominion-api` or make the URL configurable per
   build flavor. Cloud mode has never been exercised end-to-end with data —
   expect wiring bugs like the ones fixed in local mode.
2. **Register screen** — route exists, UI was never implemented (login works).
3. **Cloud↔local data migration** — switching modes currently just switches which
   dataset you see. Export/import covers the manual path for local; a guided
   migration (import local backup into cloud account and vice versa) is unbuilt.
4. **Push notifications** — .NET API has schema/endpoints only; needs FCM/APNS
   integration on both sides.
5. **Store release track** — app icons/splash, signing config, versioning,
   Play Store/App Store listings ($25 one-off / $99-year), privacy policy
   (easy to write given local-first).
6. **Insights UI polish** — provider is wired; screen is minimal (and gated in
   local mode).
7. **.NET API gaps** (see `dominion-core/MIGRATION_STATUS.md` for detail): bank
   statement import (PDF/CSV, the SA-bank parser lives in the Next.js repo),
   monthly snapshot automation, account reset endpoint, tests + CI.
8. **Web app (dominion-core) release**: deploy to Vercel as the shareable PWA.
   Before wide sharing, consider a password-reset flow (VerificationToken table
   exists, no email flow) and swapping the in-memory rate limiter for Upstash
   Redis if serverless.

## Gotchas / tribal knowledge

- **Android SDK lives on the external drive** (`/Volumes/MacBackup/Android/`,
  symlinked from `~/Library/Android/sdk` etc.). Builds fail confusingly if the
  drive isn't mounted. Emulator: `flutter emulators --launch Medium_Phone_API_36.1`.
- **First launch on the emulator is slow** (asset extraction + JIT); a frozen
  app right after install is usually emulator starvation, not an app bug.
- **Settings single-row invariant**: concurrent first reads used to insert
  duplicate default rows, which made every settings read/write throw
  (`getSingleOrNull`). `LocalSettingsRepository` now uses a fixed row id +
  insert-or-ignore and self-heals duplicates. Don't add code that inserts
  settings rows directly.
- **Enums are real Dart enums** (`Category`, `IncomeSource`, `GoalCategory` in
  `lib/core/constants.dart`). Use `.name` for keys/comparisons and
  `.displayName` for UI text — never treat them as `String` (that class of bug
  crashed three screens).
- **The .NET API and Next.js API differ slightly**: .NET returns computed fields
  (`personName`, `isPaidThisMonth`, `progressPercentage`) and defaults `paidAt`;
  Next.js requires `paidAt` (the Flutter client now always sends it). When
  consolidating on one backend, reconcile these.

## Useful commands

```bash
flutter test                 # 20 tests, no device needed
flutter analyze              # baseline: 124 pre-existing infos
flutter build apk --debug    # needs /Volumes/MacBackup mounted
flutter run                  # on the running emulator/device
```
