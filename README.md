# Dominion (Flutter App)

A privacy-first personal finance app for iOS and Android. Track expenses,
manage debit orders and bills, monitor savings goals, and get AI-powered
insights — with your data stored **locally on your device** by default.

## Features

### Local-First Storage (no account required)
- **"Continue without an account"** — use the full app with zero sign-up
- All data stored on-device in SQLite (Drift); nothing leaves your phone
- Optional **cloud sync mode** — sign in to sync via the Dominion API
- Switch modes anytime from Settings → Data storage
- **Backup & restore** — export all data as a versioned JSON file via the
  share sheet; import merges by id (idempotent, non-destructive)

### Dashboard
- Free Cash Flow at a glance (income − expenses − obligations)
- Income / Expenses / Obligations / Goals summary tiles
- Spending by Category chart with monthly totals
- Quick actions: Add Expense, Scan Receipt, Insights

### Expense Management
- Full CRUD with month navigation, search, category filter, date ranges
- 12 categories (Groceries, Dining, Transport, Housing, Debt, …)
- AI receipt scanning (camera/gallery — requires an account; data is
  processed transiently, never stored)

### Bills & Obligations
- Debit order / recurring bill tracking with paid/unpaid status
- Payment recording with per-month history
- Fixed vs variable totals

### Income, Goals & Family
- Multiple income sources (salary, freelance, side hustle, …)
- Savings goals with progress bars, add-funds flow, completion tracking
- Person/family budgets with per-person spending

### Settings
- Monthly income, payday, currency (ZAR / USD / EUR / GBP), monthly budget
- Notification preferences
- Data storage mode + backup/restore

## Tech Stack

- **Framework**: Flutter (Dart)
- **State**: Riverpod 3 (Notifier pattern)
- **Navigation**: go_router
- **Local database**: Drift (SQLite)
- **HTTP**: Dio (JWT + refresh interceptors) → .NET Dominion API (cloud mode)
- **Charts**: fl_chart
- **Storage/etc.**: flutter_secure_storage, share_plus, file_picker, image_picker

## Architecture

UI (screens/widgets) → Riverpod providers → **abstract repositories** →
either `Remote*Repository` (Dio/API) or `Local*Repository` (Drift), selected
at runtime by the persisted `StorageMode`. This is what makes local-first a
switch, not a fork.

```
lib/
├── core/           # router, theme, constants, storage_mode
├── data/local/     # Drift database + backup service
├── models/         # plain Dart models (fromJson/toJson)
├── providers/      # Riverpod state notifiers
├── repositories/   # abstract interfaces
│   ├── remote/     # HTTP implementations
│   └── local/      # Drift implementations
├── screens/        # dashboard, expenses, income, obligations, goals, insights, settings, auth
└── widgets/        # cards, charts, forms, scaffold
```

## Getting Started

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift codegen
flutter run
```

- **Local mode**: tap "Continue without an account" — works immediately.
- **Cloud mode**: run the Dominion .NET API and set `apiBaseUrl` in
  `lib/core/constants.dart`. Note: from an Android emulator, use
  `http://10.0.2.2:5000/api` (not `localhost`).

## Testing

```bash
flutter test      # repository, provider, storage-mode, backup round-trip tests
flutter analyze
```

## Backup Format

Versioned JSON envelope: `{"version": 1, "exportedAt": ..., "app": "dominion",
"data": {settings, persons, expenses, incomes, obligations, payments, goals}}`.
Import validates the envelope and upserts by id in one transaction.

## License

MIT
