import 'package:flutter/material.dart';

/// The app's single reusable card shell: rounded surface, optional ripple.
///
/// Replaces every hand-rolled `Container(decoration: BoxDecoration(...))`
/// card block duplicated across the redesigned screens (dashboard, expenses,
/// obligations, goals) with one definition.
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

  static const _radius = 24.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(_radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
