import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';

class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(UiConstants.pagePadding),
    this.borderRadius = UiConstants.cardRadius,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surfaceTop = isDark
        ? const Color(0xFF1E2735).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.72);
    final surfaceBottom = isDark
        ? const Color(0xFF18212F).withValues(alpha: 0.72)
        : const Color(0xFFF5F9FF).withValues(alpha: 0.60);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x66000000)
                : const Color(0xFF93A8C2).withValues(alpha: 0.14),
            blurRadius: 34,
            spreadRadius: -10,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: isDark
                ? const Color(0x33000000)
                : const Color(0xFF93A8C2).withValues(alpha: 0.08),
            blurRadius: 10,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [surfaceTop, surfaceBottom],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
