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
- Do not break any other screen — the legacy `AppTheme.*` static consts
  (~260 usages across ~30 untouched files) are **kept** in Phase 1, marked
  `@Deprecated`, with their current values unchanged, so untouched screens
  keep compiling and render as they do today (modulo the new `ThemeData`
  defaults underneath them — a slight palette shift on scaffold background
  and default text styles is expected and accepted). The consts are deleted
  in the final phase once the last screen has migrated.

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

**The user-facing theme switcher is also deferred.** Untouched screens still
hardcode dark `AppTheme.*` colors (dark navy `surface` cards, light-gray
`textMuted` text), so light mode would render them illegibly against the new
mint background. Phase 1 builds and wires both `ThemeData` objects but pins
`themeMode: ThemeMode.dark`; the Settings "Appearance" row, the
`ThemeModeNotifier`/persistence machinery (`lib/core/theme_mode.dart`), and
the flip to a `ThemeMode.system` default all ship in a later phase, once
enough screens have migrated for light mode to be presentable.

Chart internals (`spending_by_category_chart.dart`,
`goals_progress_chart.dart`) are recolored via the new tokens but not
restructured.

## Color tokens

| Role | Light | Dark |
|---|---|---|
| Brand primary (emerald) | `#00D09E` | `#00D09E` |
| On-primary (text/icons on emerald) | `#052224` | `#052224` |
| Ink / text primary | `#052224` | `#EAFBF3` |
| Text secondary | `#4B6B67` (derived, muted teal-gray) | `#8FB3AC` |
| Text muted | `#7C9A96` (derived) | `#5E827D` |
| Background | `#F1FFF3` | `#04191A` |
| Surface / card | `#FFFFFF` | `#123A37` |
| Surface elevated (hero/nav bg) | `#DFF7E2` | `#16453F` |
| Secondary accent (info, category icons) | `#3299FF` | `#4FA8FF` |
| Success | `#22C55E` | `#22C55E` |
| Warning | `#F5A623` | `#F5A623` |
| Error (destructive actions + expenses) | `#EF4444` | `#F87171` |

`onPrimary` is **ink** (`#052224`) in both modes — white on emerald fails
contrast (~2.0:1), and the reference kit uses dark ink on emerald throughout.
Hero-header text, the active nav badge icon, and anything else sitting on
`primary` uses ink.

**Deviation from the reference kit, made deliberately after reviewing the
first implementation pass:** `success` is a distinct hue (`#22C55E`, true
green) from brand `primary` (`#00D09E`, teal-leaning emerald) rather than
reusing the same value. Reusing brand color as the "good news" semantic color
meant income/gains looked visually identical to ordinary chrome (nav,
buttons, hero background) — no signal value. Likewise, expense/negative
amounts render in **error-red**, not the info-blue the reference kit uses —
red=spend/green=gain is a near-universal scanning convention in financial
UIs, and preserving it for usability outweighs matching the mockup's color
choice exactly. `error` is consequently no longer "destructive actions only."

The vivid accents also fail AA as *text* on light surfaces (`#3299FF` on
white ≈ 2.9:1, `#22C55E` ≈ 3.3:1 (pre-adjustment; see below)), so `AppColors`
carries darkened text variants used for amount text in light mode:
`infoText #1A6FCB`, `successText #15803D` (≥ 4.5:1 on white, verified).
Dark mode reuses the base tokens for text — `#22C55E` on both the dark
background (`#04191A`, ~7.9:1) and dark surface (`#123A37`, ~5.5:1) passes
AA comfortably. The vivid tokens remain for icon chips, fills, and badges in
both modes.

Derived text-secondary/muted tones are computed by blending ink/background at
~65%/40% opacity — not sampled, since the reference doesn't expose enough
muted-text examples to sample cleanly.

## Theme architecture

1. **`lib/core/theme.dart`** (rewritten):
   - `AppColors` — a `ThemeExtension<AppColors>` holding `success`,
     `successText`, `warning`, `info`, `infoText`, `surfaceElevated` (the
     fields `ColorScheme` doesn't provide).
     Implements `copyWith` and `lerp` per the `ThemeExtension` contract.
   - `AppTheme.light` and `AppTheme.dark` — two `ThemeData` objects, each
     built from a `ColorScheme.light(...)`/`ColorScheme.dark(...)` using the
     tokens above, with `extensions: [AppColors(...)]`, and shape defaults
     (see Shape language below) applied to `cardTheme`, `elevatedButtonTheme`,
     `inputDecorationTheme`, `textTheme`, etc. — following the structure of
     the current single `darkTheme` getter.
   - The legacy static color consts (`AppTheme.primary` etc.) **remain**,
     annotated `@Deprecated('Use Theme.of(context) / AppColors instead')`,
     with their current values untouched — they are load-bearing for every
     screen outside this phase, and changing their values would alter
     screens the spec promises to leave visually as-is. New and redesigned
     code reads `Theme.of(context).colorScheme.primary` or
     `Theme.of(context).extension<AppColors>()!.success`, etc.; the consts
     are deleted in the final phase. (Accepted transition artifact: untouched
     screens keep their purple accents next to the new emerald chrome until
     their own phase.)

2. **Theme-mode plumbing — deferred.** `lib/core/theme_mode.dart`
   (`ThemeModeStore` / `SecureThemeModeStore` / `ThemeModeNotifier`,
   mirroring `lib/core/storage_mode.dart`) ships together with the Settings
   "Appearance" selector in a later phase — with `themeMode` pinned to dark
   this phase, building the notifier now would be dead code.

3. **`main.dart`**: `MaterialApp.router` gets `theme: AppTheme.light`,
   `darkTheme: AppTheme.dark`, `themeMode: ThemeMode.dark` (hardcoded this
   phase; becomes the notifier-driven value when the selector ships).
   The startup `SystemChrome.setSystemUIOverlayStyle` block — currently
   hardcoded dark (`systemNavigationBarColor: AppTheme.surface`, light
   status-bar icons) — is removed; instead each `ThemeData` sets
   `appBarTheme.systemOverlayStyle` for its own brightness
   (`systemNavigationBarColor: surfaceElevated`, status/nav bar icon
   brightness matching the theme), so system bars stay correct when light
   mode is eventually enabled.

## Shape language

- **Radii**: cards/sheets `24px`; buttons, text fields, nav bar — full pill
  (`StadiumBorder` / `BorderRadius.circular(999)`); icon-avatar chips
  (category icons, stat-card icons) `16px` rounded-square.
- **`ScoopedHeader`** (new, `lib/widgets/scooped_header.dart` — it's screen
  chrome, not a card, so it lives beside `main_scaffold.dart` rather than in
  `widgets/cards/`): reusable
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
  with the ink `onPrimary` icon color (white fails contrast on emerald — see
  Color tokens), matching the reference's active-pill treatment (as opposed
  to today's tinted-background rectangle).

## Dashboard screen (`lib/screens/dashboard/dashboard_screen.dart`)

- Header becomes a `ScoopedHeader` in `colorScheme.primary`, containing:
  greeting + name + avatar (unchanged content/logic), and the "Free Cash
  Flow" hero figure — replacing today's separate purple-gradient
  `_SummaryCard` container (the hero figure moves *into* the scoop instead of
  being its own card below it). Note: the greeting currently uses
  `Theme.of(context).textTheme` styles; inside the primary-colored scoop
  these must be explicitly overridden to `onPrimary`-derived (ink) variants,
  or they'll pick up the theme's default text colors.
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
  switch), and amounts shown in `colorScheme.error` (red — see Color tokens
  for why this deviates from the reference kit's blue).
- All provider reads, calculations, and routing (`context.go(...)`) are
  unchanged — this is a visual pass over the existing widget tree.

## Testing / verification

- `flutter analyze` must stay clean (no new errors) on every touched file.
- `flutter test` (existing 20 tests) must continue to pass — none of them
  assert on colors/shapes, so this phase shouldn't break any. (The
  `ThemeModeNotifier` unit tests mirroring `storage_mode_test.dart` move to
  the later phase that introduces the theme-mode plumbing.)
- Manual verification: user checks the Dashboard and bottom nav
  on-device/emulator (per established workflow, Claude does not launch the
  emulator itself — static verification only, then hand off). The app ships
  dark-only this phase; the light `ThemeData` is spot-checked during
  development by temporarily flipping `themeMode: ThemeMode.light` on the
  Dashboard, then reverting.
- **Lesson from the first review pass:** `flutter analyze`/`flutter test`
  passing does not catch low-contrast colors or a widget that was supposed
  to be recolored but wasn't touched — the first implementation pass left
  `SpendingByCategoryChart`/`GoalsProgressChart` on the old deprecated
  palette (despite this spec calling for them to be recolored) and shipped a
  dark-mode card surface (`#0E2E2C`) too close in luminance to the
  background (`#04191A`) to read as a distinct card — both only surfaced
  from an actual on-device screenshot. Static checks are necessary but not
  sufficient; a real screenshot per phase is part of verification, not
  optional.

## Follow-up phases (not part of this spec)

Once Phase 1 lands and is reviewed, subsequent phases apply the same
established pattern (tokens + shapes + `ScoopedHeader` where relevant) to:
Expenses, Bills, Income, Goals, Insights, Settings body, Auth screens,
Category/Family management, and the 7 form modals — each migrating off
static `AppTheme.*` consts as it's touched, per phase.

Once enough screens are migrated for light mode to be presentable, a phase
ships the theme-mode plumbing: `lib/core/theme_mode.dart`
(`ThemeModeStore`/`SecureThemeModeStore` on `flutter_secure_storage` key
`theme_mode` + `ThemeModeNotifier`, loaded in `main()` before `runApp` like
`StorageModeNotifier`), the Settings "Appearance" System/Light/Dark selector,
the switch from hardcoded `ThemeMode.dark` to the notifier-driven value
(defaulting to `ThemeMode.system`), and 2-3 unit tests mirroring
`storage_mode_test.dart`.

The final phase, after the last screen migrates, deletes the deprecated
`AppTheme.*` static consts.
