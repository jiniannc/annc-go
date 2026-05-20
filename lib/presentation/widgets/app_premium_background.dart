import 'package:flutter/material.dart';

class AppPremiumBackground extends StatelessWidget {
  const AppPremiumBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF18243C), Color(0xFF1F2F4B)],
            stops: [0.0, 0.48, 1.0],
          ),
        ),
      );
    }
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFDFEFF), Color(0xFFF7F9FF), Color(0xFFF8FCFF)],
              stops: [0.0, 0.48, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -90,
          left: -70,
          child: _PastelBlob(
            size: 260,
            color: const Color(0xFFB9E8FF).withValues(alpha: 0.42),
          ),
        ),
        Positioned(
          top: 120,
          right: -80,
          child: _PastelBlob(
            size: 240,
            color: const Color(0xFFD9E0FF).withValues(alpha: 0.34),
          ),
        ),
        Positioned(
          bottom: -80,
          left: 20,
          child: _PastelBlob(
            size: 220,
            color: const Color(0xFFDDF0FF).withValues(alpha: 0.30),
          ),
        ),
      ],
    );
  }
}

class _PastelBlob extends StatelessWidget {
  const _PastelBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.02)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}
