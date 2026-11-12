import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// A floating "island" of frosted glass with Apple-style continuous
/// (superellipse) corners — the material used by the bottom bar pieces.
///
/// Content behind it shows through a blur, with a hairline edge and a soft
/// shadow. When the user has high contrast on, it turns solid with a clear
/// border instead.
class GlassIsland extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  const GlassIsland({
    super.key,
    required this.child,
    required this.borderRadius,
    this.padding = EdgeInsets.zero,
  });

  /// A full capsule / circle for an island of the given height.
  GlassIsland.capsule({
    super.key,
    required this.child,
    required double height,
    this.padding = EdgeInsets.zero,
  }) : borderRadius = BorderRadius.circular(height / 2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);

    final fill = highContrast
        ? scheme.surface
        : (isDark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.72)
            : Colors.white.withValues(alpha: 0.78));

    final edge = highContrast
        ? BorderSide(color: scheme.outline, width: 1.5)
        : BorderSide(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: isDark ? 0.12 : 0.06),
            width: 0.5,
          );

    final shape = RoundedSuperellipseBorder(
      borderRadius: borderRadius,
      side: edge,
    );

    final surface = DecoratedBox(
      decoration: ShapeDecoration(color: fill, shape: shape),
      child: Padding(padding: padding, child: child),
    );

    return DecoratedBox(
      // Soft lift, like the photo's floating buttons.
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(borderRadius: borderRadius),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRSuperellipse(
        borderRadius: borderRadius,
        child: highContrast
            ? surface
            : BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: surface,
              ),
      ),
    );
  }
}
