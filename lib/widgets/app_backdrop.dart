import 'package:flutter/material.dart';

class AppBackdrop extends StatelessWidget {
  final Widget child;

  const AppBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D131A),
            colorScheme.surface,
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -90,
            child: _GlowCircle(
              size: 260,
              color: colorScheme.primary.withValues(alpha: 0.09),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -100,
            child: _GlowCircle(
              size: 280,
              color: colorScheme.tertiary.withValues(alpha: 0.07),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
