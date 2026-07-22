# Dashboard Redesign — Visual Hierarchy Pass

## Background

Phase 1 of the modern UI redesign (`2026-07-21-modern-ui-redesign-phase1-design.md`)
shipped the theme foundation, shape language, `ScoopedHeader`, pill nav, and a
first pass at the Dashboard screen (currently uncommitted). Reviewing that
result against the app's actual purpose — this is a South African personal
finance app, and the homepage should immediately answer "how much money do I
have left / am I overspending / what bills are coming / am I saving enough /
what should I do next" — surfaced problems the Phase 1 visual pass didn't
solve:

- Too many cards (hero, 4 mini-cards, 3 quick-action cards, chart card,
  expense-item cards) competing for attention at equal visual weight.
- The hero balance is a plain number with no supporting context.
- Quick Actions look identical to informational cards, so they don't read as
  controls.
- The spending chart floats alone with no surrounding context.
- Typography uses the same `titleLarge` style for every section header and
  several card titles, so nothing reads as more important than anything else.
- The nav bar's active/inactive states differ only by a tint, which reads as
  generic.
- Two of the five questions the dashboard should answer — "am I overspending"
  and "am I saving enough" — aren't answerable today; the screen only shows
  raw totals (income, expenses, obligations, goals saved), no comparison
  point. "What bills are coming" is also unanswered — only a lump obligations
  total is shown, no due-date information, despite `Obligation.debitOrderDate`
  already existing in the model.

This spec is a **structural and content redesign of `dashboard_screen.dart`
and `main_scaffold.dart`'s nav bar only** — not a new visual language. It
keeps every Phase 1 architectural decision (color tokens, `AppColors`
extension, shape radii, `ScoopedHeader`, floating pill nav container,
`Theme.of(context)` usage) and restructures how the Dashboard's content is
organized, weighted, and computed.

## Goals

- Reduce the number of distinct card containers on the page and give each
  remaining tier of information (hero / callout / actions / at-a-glance /
  spending / activity) its own container language, so hierarchy comes from
  treatment, not just position.
- Make the hero figure read as premium: larger, with a supporting
  income/expenses breakdown directly beneath it.
- Add a single computed "Next Action" callout that actually answers
  "am I overspending" and "what should I do next" using only data already
  loaded on this screen (no new providers, models, or settings fields).
- Add a compact "Upcoming Bills" preview (next 2 unpaid, active obligations
  by soonest due date, derived from `debitOrderDate`) so "what bills are
  coming" has a real answer.
- Establish one consistent type scale across the screen's section headers,
  replacing the current uniform `titleLarge` reuse.
- Restyle the nav bar's active state as a labeled pill among icon-only
  inactive tabs, rather than a tinted circle among identically-styled icons.

## Out of scope

- No new data models, providers, or settings fields (e.g. no budget/spending
  limit field — overspending and savings signals are derived from existing
  income/expenses/obligations/goals data per screen, not a stored target).
- No changes to routing, provider reads/writes, or business logic elsewhere
  in the app.
- No changes to any other screen (Expenses, Obligations, Goals, Settings,
  etc.) — those remain their own future phases per the Phase 1 spec.
- No changes to chart internals (`SpendingByCategoryChart`,
  `GoalsProgressChart`) beyond what Phase 1 already specified (token
  recoloring) — this spec places the existing chart widget in a new
  surrounding layout, it doesn't restructure the chart itself.
- No theme-mode / light-dark switcher work (still deferred per Phase 1).
- Goals progress chart's position: stays where Phase 1 put it (between
  Spending section and Recent Expenses) — not part of the tiers being
  restructured here, just recolored per Phase 1.

## Structure (top to bottom)

Replacing today's flat stack of ~7 equal-weight containers with four
container tiers:

1. **Hero** (inside `ScoopedHeader`, no card chrome — it *is* the header)
2. **Next Action callout** (one accent-tinted `Container`, own tier)
3. **Quick Actions** (circular icon buttons directly on page background, no
   card)
4. **At-a-glance strip** (one unified card, not four)
5. **Spending section** (one card/section containing the category chart +
   Upcoming Bills preview together)
6. **Recent Expenses** (plain divided list rows, no per-item card — quietest
   tier)

`GoalsProgressChart` keeps its current position and card treatment
(unchanged from Phase 1) between 5 and 6.

## Hero

- `ScoopedHeader`/emerald scoop, greeting row, and avatar are unchanged from
  Phase 1.
- Label text changes from "Free Cash Flow" to **"Left to spend this month"**.
- Amount text size increases from 34px to **44px** bold — the single most
  visually dominant element on the screen.
- New: a compact breakdown row directly beneath the amount, 13px muted-ink
  text: `↑ Income {currency}{totalIncome}` and `↓ Expenses
  {currency}{totalExpenses}` (small up/down arrow glyphs, `Icons.arrow_upward
  _rounded`/`Icons.arrow_downward_rounded` at ~14px), laid out in a `Row`
  with a small gap between the two figures.
- `freeCashFlow` calculation, trend icon logic, and all provider reads are
  unchanged.

## Next Action callout

A single `Container` (rounded, tinted background at ~12% opacity of its
semantic color, full-opacity icon + text), placed immediately below the
scoop, above Quick Actions. One computed `_NextAction` value (message, icon,
`AppColors`/`colorScheme` tint) per build, using this precedence — first
match wins:

1. `freeCashFlow < 0` → tint `colorScheme.error`: *"You've spent more than
   you've earned this month"*.
2. Any obligation where `isActive && !isPaidThisMonth` has a
   `debitOrderDate` (day-of-month) falling within the next 3 days
   (computed from today's date, handling month-end wraparound — e.g. today
   is the 29th of a 30-day month and `debitOrderDate` is 1) → tint
   `appColors.warning`: *"{obligation.name} — {currency}{amount} due in {n}
   day(s)"* (pick the single soonest such obligation).
3. `totalExpenses / (totalIncome - totalObligations)` (fraction of
   discretionary budget consumed; guard divide-by-zero/negative denominator
   by skipping this check) exceeds `dayOfMonth / daysInCurrentMonth` (fraction
   of month elapsed) by more than 0.10 → tint `appColors.warning`: *"You're
   spending faster than usual this month"*.
4. `totalIncome > 0 && freeCashFlow / totalIncome >= 0.2` → tint
   `appColors.success`: *"You're on track — saving {pct}% this month"*
   (pct = `(freeCashFlow / totalIncome * 100).round()`).
5. Fallback → tint `appColors.info`: *"Add today's expenses to keep your
   tracking up to date"*.

This is a pure function (`_computeNextAction` or similar private helper) over
`expensesState`, `incomesState`, `obligationsState`, computed each build — no
new providers, no persistence.

## Upcoming Bills (part of the Spending section)

- Filter `obligationsState.obligations` to `isActive && !isPaidThisMonth`.
- For each, compute days-until-due from `debitOrderDate` (same date-math
  helper as Next Action item 2, shared/reused rather than duplicated).
- Sort ascending by days-until-due, take the first 2.
- Render as compact rows (name, provider, "due in {n} days", amount) —
  same visual language as Recent Expenses rows (hairline divider, no card
  background per item).
- If the list is empty, omit the sub-section entirely (no empty-state
  placeholder card) — avoids introducing a purposeless empty block.

## Quick Actions

- Same 3 actions, same routes/AI-gate dialog logic, unchanged.
- Visual change only: each becomes a circular icon button — 56px circle,
  `colorScheme.primary` fill, `colorScheme.onPrimary` icon — with its label
  in 12px text directly beneath, laid out in a `Row` on the plain page
  background (no wrapping `Container`/card).

## At-a-glance strip

- Same 4 values (Income, Expenses, Obligations, Goals), same data bindings.
- Restructured from a 2×2 grid of 4 separate `Container`s into **one**
  `Container` (24px radius, `colorScheme.surface`) with a `Row` of 4 compact
  columns, each: small semantic-colored icon (no tinted chip background,
  just the icon in its color, ~16px), 11px muted label, 15px bold amount —
  separated by thin `VerticalDivider`s.

## Spending section

- One section header "Spending" (new consistent header style, see
  Typography below).
- `SpendingByCategoryChart` unchanged internally (Phase 1 recoloring only),
  placed as the first element under the header.
- Upcoming Bills preview (above) placed directly below the chart, inside the
  same section/card frame, so the chart has surrounding context instead of
  floating alone as an isolated card.

## Recent Expenses

- Same data (5 items via `.take(5)`), same `context.go('/expenses')` "View
  All" action, unchanged.
- Visual change: rows become a plain `Column` with a hairline `Divider`
  between items, no per-item `Container`/background/shadow. The category
  icon keeps its existing rounded-square color chip (useful scanning
  anchor); the row itself sits directly on the page background.

## Typography scale

Applied consistently to replace today's uniform `titleLarge` reuse across
section headers and card titles:

| Role | Size / weight |
|---|---|
| Hero amount | 44px bold |
| Hero label / eyebrow text | 13px, muted-on-primary, slightly opened letter-spacing |
| Section headers ("Quick Actions", "Spending", "Recent Expenses") | 17px semibold |
| Card/column titles (at-a-glance labels, list item names) | 14–15px medium |
| Captions / meta (category name, "due in 2 days") | 12px muted |

`GoalsProgressChart`'s own header (if it renders one) is out of scope —
unchanged from Phase 1.

## Nav bar (`lib/widgets/main_scaffold.dart`)

- Keeps the Phase 1 floating pill container and `GoRouter` navigation logic
  unchanged.
- `_NavItem` changes: the **active** tab renders icon + label together
  inside a filled pill (`colorScheme.primary` background,
  `colorScheme.onPrimary` content) instead of today's plain circular icon
  badge. **Inactive** tabs render icon-only, muted, no background — same as
  today. The asymmetry (one labeled pill among plain icons) replaces the
  current uniform-shape-different-tint treatment.

## Testing / verification

- `flutter analyze` must stay clean on every touched file
  (`dashboard_screen.dart`, `main_scaffold.dart`).
- `flutter test` (existing suite) must continue to pass — none of the
  existing tests assert on dashboard layout/colors.
- New pure-function date/derivation logic (days-until-due from
  `debitOrderDate` with month-wraparound, discretionary-budget-pace
  comparison, next-action precedence) should get a few unit tests covering:
  month-end wraparound for `debitOrderDate`, the divide-by-zero guard when
  `totalIncome - totalObligations <= 0`, and each of the 5 Next Action
  precedence branches picking the expected result.
- Per prior redesign lesson (Phase 1 spec, and prior session feedback):
  `flutter analyze`/`flutter test` passing does not catch layout/contrast
  problems. Claude stops at static analysis + automated tests; the user
  verifies the result on-device/emulator and provides a screenshot before
  this is considered visually complete.
