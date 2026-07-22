# Shared Widget System (Phase A of the design-brief redesign)

## Context

The app is mid-redesign toward a premium, calm, token-driven look (see commits
`0d80d3d`…`efb3e09` and `lib/core/theme.dart`'s `AppColors`/`ColorScheme`). A
new design brief (Apple/Stripe/Linear-grade: less UI, more whitespace, few
colors, typography-driven hierarchy, 120-250ms motion) sets the bar for all
remaining work. Before touching the screens still on the old theme
(auth, income, insights, category/family management — identified by grep for
`AppTheme.<deprecated static>` usage), this phase cleans up and extracts the
shared widget layer so those screen redesigns consume real components instead
of each hand-rolling its own card/empty-state/error-state.

## Findings (audit)

- `lib/widgets/cards/glass_card.dart` (`GlassCard`), `lib/widgets/animated_empty_state.dart`
  (`AnimatedEmptyState`, `AnimatedFab`, `AnimatedCard`), `lib/widgets/error_view.dart`
  (`ErrorView`, `ErrorBanner`, `NetworkErrorView`, `EmptyStateView`) have **zero
  call sites** anywhere in `lib/` — confirmed via grep across screens, router,
  and `main.dart`. They predate the redesign and were superseded by inline
  `Container`/`BoxDecoration` blocks in each redesigned screen.
- `lib/widgets/connection_indicator.dart` (`ConnectionIndicator`) is also
  unmounted anywhere, despite `connectivity_plus` being a live dependency
  purely for its sake. Its `_ConnectionBanner` uses raw `AppTheme.success`/
  `AppTheme.error` fills with no dark-theme consideration.
- The redesigned screens (Dashboard, Expenses, Bills/Obligations, Goals) each
  duplicate the same card shell: `Container(decoration: BoxDecoration(color:
  colorScheme.surface, borderRadius: BorderRadius.circular(24)))`, e.g.
  `dashboard_screen.dart`'s `_UpcomingBillsCard`/`_AtAGlanceStrip`, and
  the empty-state block in `obligations_screen.dart:272-306` /
  `expenses_screen.dart:304+` / `goals_screen.dart:225+` (icon + title +
  subtitle, only strings differ).
- `lib/widgets/loading_skeleton.dart` is already ~90% migrated to
  `Theme.of(context).colorScheme` — only `SummaryCardSkeleton` and
  `MiniCardSkeleton` still reference the deprecated `AppTheme.surface`.
- `lib/widgets/ai_gate_dialog.dart` is small, actively used, and only needs
  `AppTheme.primary` → `colorScheme.primary`. Its stock `AlertDialog` chrome
  is intentionally left as-is — system dialogs are appropriate here.

## Decisions (confirmed with user)

1. Delete the dead widgets rather than resurrect them as-is; extract new
   components from the patterns already proven in the redesigned screens.
2. Revive the offline/online banner (still useful for cloud-mode users), on
   the new tokens, actually wired into the app this time — gated so it does
   nothing in local-storage mode.
3. Finish `loading_skeleton.dart`'s migration (2-line fix) rather than
   redesigning it — it already matches spec.

## Components

### `AppCard` — `lib/widgets/cards/app_card.dart` (replaces `glass_card.dart`)

```dart
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
}
```

- Shell: `Material(color: transparent) > InkWell(borderRadius: 24) > Container(
  decoration: BoxDecoration(color: color ?? colorScheme.surface, borderRadius:
  circular(24)))`. No border (the brief: "no thick borders"; token surfaces
  already separate from the scaffold background without one).
- `onTap` optional — cards without it render as plain elevated surfaces, no
  ripple.
- Existing inline card `Container`s in Dashboard/Expenses/Obligations/Goals
  are **not** forcibly migrated in this phase (that's screen-touch work,
  scoped to each screen's own future phase) — `AppCard` just needs to exist
  and be correct so those phases can consume it instead of reinventing it.
  Exception: any inline card this phase touches directly (empty/error states)
  is built on `AppCard`.

### `AppEmptyState` — `lib/widgets/empty_state.dart` (replaces `animated_empty_state.dart`)

```dart
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
}
```

- Layout matches the existing inline pattern (`obligations_screen.dart:272`):
  `AppCard(padding: 24) > Center > Column(icon 48px muted, title titleLarge,
  message bodySmall, optional action)`.
- One `FadeTransition` (200ms, `Curves.easeOut`) on entrance — no slide, no
  rotation, no elastic scale. The brief calls for animation everywhere, but
  also calm/premium/confident; a fade is the restrained version, and a busy
  entrance on every empty list would read as trying too hard, not premium.
- `AnimatedFab` and `AnimatedCard` (from the old file) are **not** recreated —
  no current call site needs them, and inventing new animated primitives with
  no consumer repeats the exact problem this phase is fixing.

### `AppErrorState` — `lib/widgets/error_state.dart` (replaces `error_view.dart`)

```dart
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  final String? message;
  final VoidCallback? onRetry;
  final IconData icon;
}
```

- Same shell as `AppEmptyState` (in fact shares a private `_IconMessageCard`
  helper the two build on) — icon colored `colorScheme.error`, default title
  "Something went wrong", optional `ElevatedButton.icon` retry action.
- Collapses `ErrorView` + `ErrorBanner` + `NetworkErrorView` (3 widgets, all
  unused) into this one parametrized widget. No inline banner variant is
  recreated — nothing currently needs an inline dismissible error banner
  distinct from the full-state view; add one later if a screen actually needs
  it.

### `ConnectionBanner` — rewritten `lib/widgets/connection_indicator.dart`

- Same `Connectivity` stream logic, `_isOnline`/`_showBanner` transition
  behavior (show on drop, auto-hide 3s after recovery) — that state machine is
  sound, only the visual layer and wiring change.
- Visual: slim bar (not a floating rounded pill with heavy shadow), background
  `colorScheme.errorContainer`/success-tinted surface rather than a solid
  saturated fill, text `bodyMedium`, matching "very few colors, avoid bright
  colors unless they communicate meaning" — offline *is* meaningful, so the
  color stays, but toned down to sit inside the app's restrained palette
  rather than looking like a system toast.
- Self-gates on `storageModeProvider`: if mode is `StorageMode.local`, the
  widget doesn't subscribe to connectivity at all and always renders just
  `child` — no banner, no listener overhead. Requires converting it to a
  `ConsumerStatefulWidget` (it's in a widgets/ file but reads a Riverpod
  provider, consistent with `ai_gate_dialog.dart` already doing the same).
- Wired into `main_scaffold.dart`: wraps the `Scaffold`'s `body: child` so it
  overlays every tab, mounted once at the nav-shell level rather than per
  screen.

### `loading_skeleton.dart`

- No new component. Replace the two remaining `AppTheme.surface` reads in
  `SummaryCardSkeleton` and `MiniCardSkeleton` with
  `Theme.of(context).colorScheme.surface`.

### `ai_gate_dialog.dart`

- One-line change: `AppTheme.primary` → `Theme.of(context).colorScheme.primary`.

## Migration / call-site changes

- Delete: `glass_card.dart`, `animated_empty_state.dart`, `error_view.dart`.
- Add: `app_card.dart`, `empty_state.dart`, `error_state.dart`.
- Rewrite: `connection_indicator.dart` (keep filename/class name
  `ConnectionIndicator` as the public wrapper widget; `ConnectionBanner` stays
  private, matching the old `_ConnectionBanner` naming convention internally).
- Edit: `loading_skeleton.dart` (2-line token fix), `ai_gate_dialog.dart`
  (1-line token fix), `main_scaffold.dart` (wrap body in `ConnectionIndicator`).
- No screen currently importing the deleted widgets needs updating (zero call
  sites, confirmed above) — this phase is additive/corrective at the shared-
  widget layer only, no screen files change except `main_scaffold.dart`.

## Testing

- No existing tests reference the deleted widgets (`flutter test` baseline
  stays green after deletion — verify via `grep -r "GlassCard\|AnimatedEmptyState\|ErrorView" test/`).
- Add a widget test for `ConnectionIndicator`: verifies no banner renders and
  no `Connectivity` subscription is made when `storageModeProvider` is
  `StorageMode.local` (the actual behavior change worth locking in).
- `flutter analyze` should show zero new warnings; deleting 3 files should
  reduce the pre-existing-info baseline (currently 124), not increase it.

## Out of scope (future phases)

- Migrating Dashboard/Expenses/Obligations/Goals' existing inline cards to
  `AppCard` — left as-is; future screen phases adopt it as they're touched.
- Redesigning Income, Insights, Auth (login/register), Category/Family
  management screens — separate specs, now able to build on `AppCard`/
  `AppEmptyState`/`AppErrorState` instead of inline decoration.
