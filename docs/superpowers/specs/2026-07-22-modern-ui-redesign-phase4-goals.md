# Modern UI Redesign — Phase 4: Goals Screen

## Background

Continues the per-screen cadence (Phase 1 theme+Dashboard, Phase 2
Expenses, Phase 3 Bills). This phase covers the Goals screen
(`lib/screens/goals/goals_screen.dart`), the last bottom-nav tab besides
Settings. `goals_progress_chart.dart` was already migrated in Phase 1 and
needs no changes. No `sample_app/` reference covers a savings-goals layout,
so this follows the internal pattern (as Bills did).

## Goals

- `goals_screen.dart` fully migrates off `AppTheme.*` statics.
- Same `ScoopedHeader` + 24px sheet card + pill-button language as the
  other three redesigned screens.
- Filtering/CRUD logic, provider reads, and routing unchanged.

## Screen layout

- **AppBar → `ScoopedHeader`**: title "Savings Goals" + the
  Active/Completed filter menu as an ink-tinted icon on the hero (same
  `PopupMenuButton`, restyled icon color only).
- **Hero figure**: "Total Saved" (title+icon+amount, same shape as the
  other three screens) with a goals-count pill chip, replacing the current
  white-on-info-gradient card.
- **Target/Progress breakdown** moves out of the hero into two 24px sheet
  stat cards (same move as Bills' Fixed/Variable): "Target" in
  `colorScheme.secondary`, "Progress" (overall %) in `appColors.success`.
- **Goal cards** (`_GoalCard`): 24px radius (was 12px). Per-goal custom
  hex colors (`goal.color`, user data) are left alone — same as Bills left
  obligation-specific data untouched — only the static `AppTheme.*` chrome
  around them migrates:
  - category label / "of target" text → default `textTheme.bodySmall`
    (was hardcoded `AppTheme.textMuted`).
  - "Overdue" date text → `appColors.warning`, not error — consistent with
    the Phase 3 call that a missed-target-date state is an attention
    signal, not a destructive action (same reasoning applied there to
    "Unpaid").
  - "Goal Completed!" badge → `appColors.success` (already semantically
    right, just off the static const).
  - Swipe-to-delete background and the delete-confirmation dialog keep
    `colorScheme.error` — this one is genuinely destructive.
  - `_getColorFromHex`'s fallback (`AppTheme.info` today) becomes
    `colorScheme.secondary`, and the method takes `BuildContext` to reach
    it.
  - "Add Funds" `OutlinedButton` gets an explicit `StadiumBorder` (pill)
    via `style:`, matching the per-widget pill overrides already used
    elsewhere (e.g. Expenses' date-range button) rather than a global
    `outlinedButtonTheme` change, which would ripple into every
    not-yet-migrated screen.
- **FAB**: drops its `AppTheme.info` override, becomes `colorScheme.primary`
  pill like the other three screens' FABs.
- **Empty/loading states**: same treatment as the other screens.

## Testing / verification

- `flutter analyze` stays clean on every touched file.
- `flutter test` continues to pass.
- Manual verification: user checks Goals screen (list, active/completed
  filter, add/edit/delete, add funds) on-device/emulator.

## Follow-up

Insights, Settings body, Auth screens, Category/Family management, and the
remaining out-of-scope items stay per the Phase 1 follow-up list.
