# Modern UI Redesign — Phase 3: Bills/Obligations Screen

## Background

Continues the per-screen cadence from Phase 1 (theme foundation + Dashboard)
and Phase 2 (Expenses). This phase covers the Bills screen
(`lib/screens/obligations/obligations_screen.dart`), the next stop on the
bottom nav. No reference screenshot in `sample_app/` covers a bills/
subscriptions layout specifically, so this phase follows the internal
pattern already established on Dashboard/Expenses (`ScoopedHeader` hero +
24px sheet cards + 16px rounded-square chips) rather than a new sampled
reference.

## Goals

- `obligations_screen.dart` fully migrates off `AppTheme.*` statics.
- Same visual language as Dashboard/Expenses: `ScoopedHeader` hero in
  `colorScheme.primary` (the brand hero color is consistent chrome across
  screens — it doesn't change to match a screen's semantic color, the same
  way Expenses' hero stayed emerald even though its content is an outflow).
- Filtering/search/payment/delete logic, provider reads, and routing are
  unchanged, except one consolidation (see below).

## Color convention fixes (not just token swaps)

Two spots in this screen currently violate the Phase 1 rule that error-red
is reserved for destructive actions/real errors:

- The "Unpaid" status tag uses `AppTheme.error`. Being unpaid isn't an error
  state, it's a pending one — moves to `appColors.warning`.
- The debt balance line ("Balance: R X") uses `AppTheme.error`. It's
  informational (an amount owed), not a destructive action — moves to
  `appColors.warning` (a "pay attention" signal, distinct from the plain
  outflow figure).
- The monthly bill amount itself (currently `AppTheme.warning`) moves to
  `appColors.infoText`, matching the app-wide convention that outflow
  amounts render in info-blue (established for expenses in Phase 2) —
  bills are outflows too, and this unifies "money going out" styling
  across screens. Warning is freed up for the two cases above.
- The FAB currently overrides to `AppTheme.warning` to visually mark
  "this is the bills tab." Every other screen's FAB is `colorScheme.primary`;
  this phase drops the override for consistency, since the tab bar and
  screen chrome already make context clear.

## Screen layout

- **AppBar → `ScoopedHeader`**, same treatment as Expenses: title "Monthly
  Bills", search toggle, and the show/hide-inactive toggle as ink-tinted
  icon buttons on the hero.
- **Hero figure**: "Total Monthly Bills" (same title+icon+amount shape as
  Dashboard/Expenses), with Paid/Unpaid counts as two small ink-tinted pill
  chips next to it (replacing the current white-on-gradient `_StatusChip`),
  colored dot per status (`appColors.success` / `appColors.warning`).
- **Fixed/Variable breakdown** moves out of the hero and into the sheet as
  two 24px stat cards (mirrors Dashboard's Income/Expenses mini-cards):
  icon chip + label + amount. Fixed uses `colorScheme.primary` (stable),
  Variable uses `appColors.warning` (can change).
- **Bill list** (`_ObligationCard`): 24px card radius (was 12px), tag chips
  (Paid/Unpaid/Fixed/Variable) restyled to the semantic tokens above,
  provider/date text via `Theme.of(context).textTheme.bodySmall` instead of
  hardcoded `AppTheme.textMuted`. The "Record Payment" footer strip drops
  its `AppTheme.background`-colored bar (a leftover scaffold-background
  token, mismatched with the new surface system) in favor of a plain
  divider inside the same card.
- **Empty/loading states**: same treatment as Expenses (`textTheme.bodySmall`
  color, `ListScreenSkeleton`).

## Behavioral consolidation (flagged, not purely visual)

`_recordPayment` currently opens its own ad hoc `AlertDialog` with plain
`TextField`s and a hardcoded `Colors.red` snackbar — duplicating
`lib/widgets/forms/record_payment_modal.dart`, a fully-built (and, since
Phase 2, already redesigned) bottom sheet for the same action that no
screen actually calls. This phase wires the FAB-adjacent "Record Payment"
button to `showModalBottomSheet` with `RecordPaymentModal` instead,
deleting the inline dialog and its duplicate validation logic. This is a
small behavior change (bottom sheet instead of a small dialog) rather than
a pure re-theme, called out here rather than silently bundled in.

## Testing / verification

- `flutter analyze` stays clean on every touched file.
- `flutter test` continues to pass — no test asserts on this screen's
  colors/shapes or on the inline record-payment dialog being replaced.
- Manual verification: user checks Bills screen (list, search, show
  inactive, add/edit/delete, record payment) on-device/emulator.

## Follow-up

Goals screen is next in the bottom-nav order.
