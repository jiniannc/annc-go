import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';

/// 글래스 카드. [onTap] / [onLongPress] 를 주면 인터랙티브 상태(idle / hovered /
/// pressed)에 따라 미세한 lift·brightness·scale 변화가 들어간다.
///
/// 기존 호출부와 호환을 위해 콜백을 주지 않으면 시각·동작 모두 이전과 동일하다.
class LiquidGlassCard extends StatefulWidget {
  const LiquidGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(UiConstants.pagePadding),
    this.borderRadius = UiConstants.cardRadius,

    /// 0: 기존 플레이트 글래스 톤. 1 가까워질수록 더 불투명·밝게(예: 메인 카드 전체화면 포커스).
    /// 0~1로만 사용한다.
    this.elevateStrength = 0,
    this.onTap,
    this.onLongPress,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final double elevateStrength;

  /// 탭 콜백. 주면 호버/프레스 상태에 따라 자동으로 시각 반응이 들어간다.
  final VoidCallback? onTap;

  /// 롱프레스 콜백. 주면 long press 시 호출된다.
  final VoidCallback? onLongPress;

  bool get _isInteractive => onTap != null || onLongPress != null;

  @override
  State<LiquidGlassCard> createState() => _LiquidGlassCardState();
}

class _LiquidGlassCardState extends State<LiquidGlassCard> {
  bool _hovered = false;
  bool _pressed = false;

  /// 인터랙션 상태별 시각 보정.
  ///
  /// - hovered: 살짝 lift (Transform Y -1px) + brightness +3%
  /// - pressed: scale 0.985 + brightness -2%
  static const Duration _stateAnimDuration = Duration(milliseconds: 180);
  static const Curve _stateAnimCurve = Curves.easeOutCubic;

  double get _scale {
    if (_pressed) {
      return 0.985;
    }
    if (_hovered) {
      return 1.005;
    }
    return 1.0;
  }

  double get _liftY {
    if (_pressed) {
      return 0.0;
    }
    if (_hovered) {
      return -1.0;
    }
    return 0.0;
  }

  /// 표면 위에 얹는 미세 brightness 오버레이. light/dark 모두에서 작동.
  double get _overlayAlpha {
    if (_pressed) {
      return 0.04;
    }
    if (_hovered) {
      return 0.06;
    }
    return 0;
  }

  Color get _overlayColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_pressed) {
      // 어두워지는 방향
      return isDark ? Colors.black : Colors.black;
    }
    // 밝아지는 방향
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    Widget card = _buildCard(context);

    if (!widget._isInteractive) {
      return card;
    }

    // 인터랙티브 상태 오버레이: brightness shift + scale + lift.
    card = Stack(
      children: [
        card,
        // 클릭 가능 표면 위에 미세한 색 오버레이를 입혀 hover/press 상태를 표현.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedContainer(
              duration: _stateAnimDuration,
              curve: _stateAnimCurve,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                color: _overlayColor.withValues(alpha: _overlayAlpha),
              ),
            ),
          ),
        ),
      ],
    );

    card = AnimatedSlide(
      duration: _stateAnimDuration,
      curve: _stateAnimCurve,
      // borderRadius 단위로 환산하지 않고 SizedBox 의 fractional offset 단위.
      // 카드 높이 대비 약 -0.4% 정도 lift — 거의 인지 한계 수준이지만
      // hover 시 "살짝 부유"하는 인상을 만든다.
      offset: Offset(0, _liftY / 100),
      child: AnimatedScale(
        duration: _stateAnimDuration,
        curve: _stateAnimCurve,
        scale: _scale,
        child: card,
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: card,
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = widget.elevateStrength.clamp(0.0, 1.0);

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
    final surfaceBottom = Color.lerp(
      surfaceBottomMuted,
      surfaceBottomBright,
      t,
    )!;
    final blurSigma = _lerp(22.0, 11.0, t);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.borderRadius),
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
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: widget.padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [surfaceTop, surfaceBottom],
              ),
              borderRadius: BorderRadius.circular(widget.borderRadius),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }

  static double _lerp(double a, double b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);
}
