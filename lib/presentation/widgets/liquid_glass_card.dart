import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';

class LiquidGlassCard extends StatelessWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(UiConstants.pagePadding),
    this.borderRadius = UiConstants.cardRadius,
    /// 0: 기존 플레이트 글래스 톤. 1 가까워질수록 더 불투명·밝게(예: 메인 카드 전체화면 포커스).
    /// 0~1로만 사용한다.
    this.elevateStrength = 0,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double elevateStrength;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = elevateStrength.clamp(0.0, 1.0);

    final surfaceTopMuted = isDark
        ? const Color(0xFF1E2735).withValues(alpha: 0.78)
        : Colors.white.withValues(alpha: 0.72);
    final surfaceBottomMuted = isDark
        ? const Color(0xFF18212F).withValues(alpha: 0.72)
        : const Color(0xFFF5F9FF).withValues(alpha: 0.60);

    /// 어두운 배경·스크림 위에서 카드 본체가 회색으로 뭉개지지 않도록 밝게.
    final surfaceTopBright = isDark
        ? const Color(0xFF293548).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.96);
    final surfaceBottomBright = isDark
        ? const Color(0xFF222C3F).withValues(alpha: 0.92)
        : const Color(0xFFFAFCFE).withValues(alpha: 0.94);

    final surfaceTop = Color.lerp(surfaceTopMuted, surfaceTopBright, t)!;
    final surfaceBottom =
        Color.lerp(surfaceBottomMuted, surfaceBottomBright, t)!;
    final blurSigma = _lerp(22.0, 11.0, t);

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
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
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

  static double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);
}
