# Modern UI Redesign — Phase 2: Expenses Screen

## Background

Phase 1 (`2026-07-21-modern-ui-redesign-phase1-design.md`) established the
theme foundation and shape language (emerald `ColorScheme`, `AppColors`
extension, `ScoopedHeader`, pill nav, 24px cards, 16px rounded-square icon
chips) on the Dashboard. This phase applies that established pattern to the
Expenses screen — the next screen in the bottom nav and the closest
structural sibling to Dashboard (stat figures, category icon chips, a
scrollable list).

No new tokens or shapes are introduced. Reference: `sample_app/8 - A -
Transaction.png` and `9.3.0 - A - Transaction.png` (the reference app's
combined income/expense ledger) for the hero/list shape — adapted to this
screen's actual scope, which is expenses only (income has its own screen and
provider).

## Goals

- `lib/screens/expenses/expenses_screen.dart` fully migrates off
  `AppTheme.*` statics to `Theme.of(context)` / `AppColors`, per the
  Phase 1 migrate-as-touched convention.
- Same visual language as Dashboard: `ScoopedHeader` hero, 24px sheet cards,
  16px rounded-square category chips, pill-shaped controls, `infoText` for
  expense amounts (not error-red).
- All existing behavior — month paging, date-range filter, category filter
  menu, search, swipe-to-delete, edit-on-tap, add-expense FAB — is
  unchanged. This is a visual pass only.

## Out of scope

- `add_expense_modal.dart` — not touched; still opened the same way via
  `showModalBottomSheet`. Its own redesign is a later phase.
- The category→icon mapping (`_getCategoryIcon`) is unchanged. The
  category→**color** mapping switches from the ad hoc `Colors.green/blue/…`
  switch to the same hash-based palette cycle used on Dashboard's
  `_ExpenseItem` (`colorScheme.primary` / `colorScheme.secondary` /
  `appColors.warning` / `appColors.success`), for visual consistency between
  the two screens' category chips.
- Filtering/search/delete logic, provider reads, and routing are unchanged.

## Screen layout

- **AppBar → `ScoopedHeader`.** The existing `AppBar` (title, search toggle,
  filter menu) is replaced by a `ScoopedHeader` in `colorScheme.primary`,
  matching Dashboard's treatment (full-bleed under the status bar, ink
  `onPrimary` text/icons, `AnnotatedRegion` for dark status icons). Hero
  content: title "Expenses", with the search-toggle and category-filter
  icon buttons inline (ink-tinted, same as today's `IconButton`s but
  restyled to sit on `colorScheme.primary`). When search is active, the
  `TextField` replaces the title within the hero, same as today.
- **Total Expenses figure** moves into the scoop as the hero figure —
  reusing the same `_SummaryFigure`-shaped treatment as Dashboard's Free
  Cash Flow (title + trend icon + large amount, ink `onPrimary`) — replacing
  today's separate white-on-red gradient card. The "N items" badge becomes a
  small pill chip next to the figure (`onPrimary.withValues(alpha: 0.15)`
  fill, ink text), still ink instead of white-on-transparent.
- **Filter row** (`MonthSelector` + `DateRangeFilter`) sits in the sheet,
  directly below the scoop, restyled (see Shared widgets below) but
  unchanged in behavior/position.
- **Expense list** (`_ExpenseCard` → align naming/shape with Dashboard's
  `_ExpenseItem`): 24px-radius surface card per row (was 12px), 16px
  rounded-square category icon chip (was a soft-round `12px` box), amount
  in `AppColors.infoText` (was `AppTheme.error`), category/date secondary
  text via `Theme.of(context).textTheme.bodySmall` (was hardcoded
  `AppTheme.textMuted`). Swipe-to-delete background and the delete
  confirmation dialog's destructive action keep `colorScheme.error` —
  deletion is genuinely destructive, unlike a normal expense amount.
- **Empty / loading states**: icon and text colors migrate to
  `Theme.of(context).textTheme.bodySmall?.color` / `colorScheme` reads,
  matching Dashboard's empty-state treatment. `ListScreenSkeleton` (in
  `loading_skeleton.dart`) has its shimmer base color moved off
  `AppTheme.textMuted` to `Theme.of(context).textTheme.bodySmall?.color`,
  since it's shared chrome likely reused by other screens' loading states.
- **FAB**: `FloatingActionButton.extended` becomes a pill shape
  (`StadiumBorder`) in `colorScheme.primary` with ink foreground — same
  widget, restyled shape/colors only.

## Shared widgets touched

These are used only by Expenses and Income today; restyling them now
benefits Income's own phase later at no extra cost, but no Income-screen
logic changes here.

- **`lib/widgets/cards/month_selector.dart`**: surface pill
  (`StadiumBorder`, `colorScheme.surface`) instead of a 12px rounded
  rectangle; chevron colors via `colorScheme`/`textTheme` instead of
  `AppTheme.textSecondary`/`textMuted`.
- **`lib/widgets/date_range_filter.dart`**: the `OutlinedButton` and clear
  `IconButton` restyled to pill shape; clear button uses
  `colorScheme.error` (destructive/clear action, consistent with existing
  use). The `showDateRangePicker` theme override switches from
  `AppTheme.primary`/hardcoded white-on-black to
  `Theme.of(context).colorScheme` values so the picker matches app theming
  instead of being hardcoded light-only.

## Testing / verification

- `flutter analyze` stays clean on every touched file.
- `flutter test` (existing suite) continues to pass — no test asserts on
  Expenses screen colors/shapes.
- Manual verification: user checks Expenses screen (list, search, filters,
  add/edit/delete flow) on-device/emulator; Claude does not launch the
  emulator itself.

## Follow-up

Income screen (next user of `MonthSelector`/`DateRangeFilter`) gets its own
phase per the established per-screen cadence; the shared-widget restyle
here is not a signal to also redesign Income screen's own layout.
