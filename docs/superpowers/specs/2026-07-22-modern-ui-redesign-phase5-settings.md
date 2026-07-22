# Modern UI Redesign — Phase 5: Settings Screen

## Background

Continues the per-screen cadence (Phase 1 theme+Dashboard, Phase 2
Expenses, Phase 3 Bills, Phase 4 Goals). This phase covers
`lib/screens/settings/settings_screen.dart`, the last bottom-nav
destination. Unlike the previous four screens, `sample_app/` has a direct
reference for this one: `9.5.3 - A - Settings.png` and
`9.5.0 - A - Profile.png` — a short hero (title only, no big figure) over a
flat list of rounded-square icon-chip rows.

## Goals

- `settings_screen.dart` fully migrates off `AppTheme.*` statics.
- Same shape language as the other four screens, adapted to a list/settings
  layout rather than a stats layout.
- All settings logic (edit dialogs, storage-mode switch, export/import,
  sign-out) unchanged — visual pass only.

## Deviation from the sampled reference (and why)

The reference's Settings list is flat (no grouped containers) and reached
by drilling in from Profile, hence its back arrow and notification bell.
This app's Settings is a bottom-nav tab root with five logically distinct
groups (Data storage, Account, Finances, Notifications, Account/Sign-out)
already organized as titled sections — collapsing that into one flat list
would lose information structure for a net loss in this app's specific data
density. This phase keeps the existing grouped-sections layout, applying
only the reference's short-hero-with-no-figure shape and its rounded-square
icon-chip row treatment. No back arrow or bell — consistent with the other
three tab-root screens, which also have neither.

## Screen layout

- **AppBar → short `ScoopedHeader`**: just the "Settings" title, ink on
  `colorScheme.primary` — no hero figure (nothing to total on this screen),
  no search/filter actions.
- **`_SettingsSection`**: container radius 24px (was 16px, to match every
  other screen's card radius), section title via default
  `textTheme.bodySmall` (was hardcoded `AppTheme.textMuted`).
- **`_SettingsTile` / `_SettingsToggle`**: leading bare `Icon` becomes a
  16px rounded-square icon-chip (tinted background + icon), matching the
  category/stat chips used on every other screen. Chevron and default icon
  tint move off `AppTheme.textMuted`/`AppTheme.primary` to
  `textTheme.bodySmall?.color`/`colorScheme.primary`. The three
  `SwitchListTile`s' `activeColor` (a param Flutter deprecated in favor of
  `activeThumbColor`) is updated to the non-deprecated API while this file
  is open, same token.
- **Dialogs** (`_EditFieldDialog`, `_EditCurrencyDialog`, sign-out/import
  confirmations): snackbars and destructive buttons move to
  `colorScheme.error`/`appColors.success`; the currency check-mark and
  default icon tints move to `colorScheme.primary`. Dialog chrome itself
  (AlertDialog shape, TextFormField borders) already inherits from the
  global `ThemeData` and needs no changes.

## Testing / verification

- `flutter analyze` stays clean on every touched file.
- `flutter test` continues to pass.
- Manual verification: user checks Settings screen (all sections, edit
  dialogs, currency picker, export/import, sign-out) on-device/emulator.

## Follow-up

With all five bottom-nav-reachable screens (Dashboard, Expenses, Bills,
Goals, Settings) and all 7 form modals done, remaining out-of-scope items
per the original Phase 1 list are: Income, Insights, Auth screens
(login/register), and Category/Family management screens.
