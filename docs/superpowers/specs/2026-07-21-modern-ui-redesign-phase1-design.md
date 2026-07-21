# Modern UI Redesign — Phase 1: Theme Foundation + Dashboard

## Background

The app's current UI (dark navy/purple Material 3 defaults) reads as generic —
flat cards, default widget shapes, no distinctive visual identity. We're
redesigning the whole app to feel modern and crafted, using a Figma finance-app
UI kit (`sample_app/` in the repo root) as visual inspiration: a bright emerald
theme with a signature "scooped" curve between hero header and content sheet,
fully pill-shaped buttons/inputs/nav, and rounded-square icon-avatar chips for
categories.

This is a large project (theme system + ~11 screens + ~7 form modals + shared
chrome), so it's being built in phases. **This spec covers Phase 1 only**:
the theme foundation (light + dark, since the app currently only has one
hardcoded dark theme) and one flagship screen — Dashboard plus the bottom nav
— to establish the pattern that later phases repeat per-screen.

Colors were not guessed — they were sampled directly (via PIL) from the
reference PNGs in `sample_app/`.

## Goals

- Establish a real light/dark theme pair (the app currently has neither —
  `AppTheme` is a single set of hardcoded dark colors referenced as static
  consts throughout the codebase, not via `Theme.of(context)`).
- Introduce the shape language that will carry through every later phase:
  large-radius scooped headers, pill buttons/inputs/nav, rounded-square icon
  chips.
- Ship one complete, working example (Dashboard + bottom nav) so later phases
  have an established pattern to repeat rather than re-deriving decisions.
- Do not break any other screen — screens not touched in this phase must
  continue to render correctly against the new `ThemeData` (Material
  defaults filling any gaps) until their own redesign phase.

## Out of scope for Phase 1

Expenses, Bills/Obligations, Income, Goals, Insights, Settings body content,
Auth (login/register), Category management, Family management, and all 7 form
modals (`add_expense_modal`, `add_obligation_modal`, `add_income_modal`,
`add_goal_modal`, `add_funds_modal`, `record_payment_modal`,
`scan_receipt_modal`). These stay visually as-is and get their own redesign
passes in later phases, migrating off static `AppTheme.*` consts as each is
touched — this was a deliberate choice (fold the Theme.of(context) migration
into the same pass as the visual redesign, rather than doing it as separate
prep work across the whole app).

Chart internals (`spending_by_category_chart.dart`,
`goals_progress_chart.dart`) are recolored via the new tokens but not
restructured.

## Color tokens

| Role | Light | Dark |
|---|---|---|
| Brand primary (emerald) | `#00D09E` | `#00D09E` |
| Ink / text primary | `#052224` | `#EAFBF3` |
| Text secondary | `#4B6B67` (derived, muted teal-gray) | `#8FB3AC` |
| Text muted | `#7C9A96` (derived) | `#5E827D` |
| Background | `#F1FFF3` | `#04191A` |
| Surface / card | `#FFFFFF` | `#0E2E2C` |
| Surface elevated (hero/nav bg) | `#DFF7E2` | `#123634` |
| Secondary accent (info, category icons) | `#3299FF` | `#4FA8FF` |
| Success | `#00D09E` | `#00D09E` |
| Warning | `#F5A623` | `#F5A623` |
| Error (destructive actions only) | `#EF4444` | `#F87171` |

Convention carried over from the reference: expense/negative amounts render in
the **info-blue** accent, not error-red. Error-red is reserved for destructive
actions (delete confirmations) and real error states.

Derived text-secondary/muted tones are computed by blending ink/background at
~65%/40% opacity — not sampled, since the reference doesn't expose enough
muted-text examples to sample cleanly.

## Theme architecture

1. **`lib/core/theme.dart`** (rewritten):
   - `AppColors` — a `ThemeExtension<AppColors>` holding `success`, `warning`,
     `info`, `surfaceElevated` (the fields `ColorScheme` doesn't provide).
     Implements `copyWith` and `lerp` per the `ThemeExtension` contract.
   - `AppTheme.light` and `AppTheme.dark` — two `ThemeData` objects, each
     built from a `ColorScheme.light(...)`/`ColorScheme.dark(...)` using the
     tokens above, with `extensions: [AppColors(...)]`, and shape defaults
     (see Shape language below) applied to `cardTheme`, `elevatedButtonTheme`,
     `inputDecorationTheme`, `textTheme`, etc. — following the structure of
     the current single `darkTheme` getter.
   - No more bare static color consts (`AppTheme.primary` as a `Color`)
     — call sites read `Theme.of(context).colorScheme.primary` or
     `Theme.of(context).extension<AppColors>()!.success`, etc.

2. **`lib/core/theme_mode.dart`** (new — mirrors `lib/core/storage_mode.dart`):
   - `ThemeModeStore` abstract + `SecureThemeModeStore` impl using
     `flutter_secure_storage` under key `theme_mode`, values `system` /
     `light` / `dark`.
   - `ThemeModeNotifier extends Notifier<ThemeMode>`, `build()` defaults to
     `ThemeMode.system`, `load()` reads persisted value, `setThemeMode(mode)`
     persists + updates state.
   - Loaded in `main()` before `runApp`, same as `StorageModeNotifier.load()`
     today, so there's no flash of the wrong theme on cold start.

3. **`main.dart`**: `MaterialApp.router` gets `theme: AppTheme.light`,
   `darkTheme: AppTheme.dark`, `themeMode: ref.watch(themeModeProvider)`.

4. **`settings_screen.dart`**: new "Appearance" row (System/Light/Dark
   selector, e.g. a segmented control or three-way radio tile group) placed
   near the existing "Data storage" section, calling
   `ref.read(themeModeProvider.notifier).setThemeMode(...)`.

## Shape language

- **Radii**: cards/sheets `24px`; buttons, text fields, nav bar — full pill
  (`StadiumBorder` / `BorderRadius.circular(999)`); icon-avatar chips
  (category icons, stat-card icons) `16px` rounded-square.
- **`ScoopedHeader`** (new, `lib/widgets/cards/scooped_header.dart`): reusable
  widget that renders a colored hero region with a large bottom-rounded
  corner, with the content sheet below it starting further up so it visually
  overlaps/scoops into the hero — the signature shape from the reference.
  Takes a `Widget child` for the hero content and a `Color background`.
  Dashboard is the first consumer; later phases reuse it on other screens
  that want the same treatment (this spec doesn't mandate which — that's a
  per-screen decision in its own phase).

## Bottom nav (`lib/widgets/main_scaffold.dart`)

- Rewritten as a floating pill: `Container` with horizontal+bottom margin
  (not edge-to-edge), `StadiumBorder`/pill shape, `surfaceElevated` fill.
  - Same 5 destinations (Home, Expenses, Bills, Goals, Settings), same
  `GoRouter` navigation logic — this is a visual-only change to `_NavItem`
  and the wrapping container.
- Active tab: icon shown inside a filled circular badge in `colorScheme.primary`
  with a white/onPrimary icon color, matching the reference's active-pill
  treatment (as opposed to today's tinted-background rectangle).

## Dashboard screen (`lib/screens/dashboard/dashboard_screen.dart`)

- Header becomes a `ScoopedHeader` in `colorScheme.primary`, containing:
  greeting + name + avatar (unchanged content/logic), and the "Free Cash
  Flow" hero figure — replacing today's separate purple-gradient
  `_SummaryCard` container (the hero figure moves *into* the scoop instead of
  being its own card below it).
- Stat row: today's 2×2 `_MiniCard` grid (Income/Expenses/Obligations/Goals)
  restyled — white/surface cards, `16px` rounded-square icon-avatar chips
  using the new semantic colors (success/info/warning) instead of ad hoc
  `Colors.green` etc. Same data bindings.
- Quick actions: same 3 actions (Add Expense, Scan Receipt, Insights),
  restyled as pill-topped icon buttons on `colorScheme.surface`.
- Charts: `SpendingByCategoryChart`/`GoalsProgressChart` recolored via new
  tokens only — no structural change.
- Recent expenses list: `_ExpenseItem` restyled with `16px` rounded-square
  category icon-avatar chips using a new category→color mapping drawn from
  the token palette (replacing the current raw `Colors.green/blue/orange/...`
  switch), and amounts shown in `AppColors.info` instead of `AppColors.error`.
- All provider reads, calculations, and routing (`context.go(...)`) are
  unchanged — this is a visual pass over the existing widget tree.

## Testing / verification

- `flutter analyze` must stay clean (no new errors) on every touched file.
- `flutter test` (existing 20 tests) must continue to pass — none of them
  assert on colors/shapes, so this phase shouldn't break any, but they're the
  regression backstop for the `ThemeModeNotifier` persistence logic, which
  should get 2-3 new unit tests mirroring the existing `storage_mode_test.dart`
  coverage (defaults to system, persists + reloads a chosen mode).
- Manual verification: user checks the Dashboard and bottom nav in both light
  and dark mode on-device/emulator (per established workflow, Claude does not
  launch the emulator itself — static verification only, then hand off).

## Follow-up phases (not part of this spec)

Once Phase 1 lands and is reviewed, subsequent phases apply the same
established pattern (tokens + shapes + `ScoopedHeader` where relevant) to:
Expenses, Bills, Income, Goals, Insights, Settings body, Auth screens,
Category/Family management, and the 7 form modals — each migrating off
static `AppTheme.*` consts as it's touched, per phase.
