import 'package:flutter/material.dart';

/// Full-bleed hero block that "scoops" into the page background below it —
/// the signature curve from the UI redesign reference (see
/// docs/superpowers/specs/2026-07-21-modern-ui-redesign-phase1-design.md).
///
/// Achieved by layering a rounded-top strip of the page background directly
/// under the hero: the strip's rounded corners read as a concave notch
/// carved into the hero color, rather than a separate floating card.
///
/// Designed to sit at the very top of a screen, full-bleed behind the status
/// bar: it pads its content by the top view inset itself, so do NOT wrap it
/// in a top [SafeArea] (the hero color would stop at the status bar edge).
/// The screen is responsible for setting status bar icon brightness to
/// contrast with [background] (e.g. via [AnnotatedRegion]).
class ScoopedHeader extends StatelessWidget {
  final Widget child;
  final Color background;
  final double scoopRadius;

  const ScoopedHeader({
    super.key,
    required this.child,
    required this.background,
    this.scoopRadius = 32,
  });

  @override
  Widget build(BuildContext context) {
    final sheetColor = Theme.of(context).scaffoldBackgroundColor;
    final topInset = MediaQuery.paddingOf(context).top;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: double.infinity,
          color: background,
          padding: EdgeInsets.fromLTRB(20, 20 + topInset, 20, 28),
          child: child,
        ),
        Container(
          width: double.infinity,
          height: scoopRadius,
          color: background,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: sheetColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(scoopRadius),
                topRight: Radius.circular(scoopRadius),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
