import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 살아 숨쉬는 프리미엄 배경.
///
/// 단일 [AnimationController]를 60초 주기로 무한 반복시키고, 그 위상([phase])
/// 에서 파생한 sin/cos 값으로 각 blob의 위치·스케일과 starfield의 트윙클을
/// 동시에 구동한다. 컨트롤러를 하나만 쓰기 때문에 모든 모션이 같은 호흡으로
/// 흘러가고, [RepaintBoundary] 안에 격리해 다른 UI 레이어를 무효화하지 않는다.
///
/// - Light: 3개 파스텔 blob 이 천천히 표류 + 0.95~1.05 스케일 호흡
/// - Dark: 깊은 navy blob 1개 표류 + 12개 별이 비대칭 주기로 트윙클 (항공
///   야간 운항의 *기내 창밖 도시 야경* 메타포)
class AppPremiumBackground extends StatefulWidget {
  const AppPremiumBackground({super.key});

  @override
  State<AppPremiumBackground> createState() => _AppPremiumBackgroundState();
}

class _AppPremiumBackgroundState extends State<AppPremiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          final phase = _ambient.value * 2 * math.pi;
          return isDark ? _buildDark(phase) : _buildLight(phase);
        },
      ),
    );
  }

  Widget _buildLight(double phase) {
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
          top: -90 + 18 * math.sin(phase),
          left: -70 + 22 * math.cos(phase * 0.8),
          child: Transform.scale(
            scale: 1.0 + 0.04 * math.sin(phase * 1.3),
            child: _PastelBlob(
              size: 260,
              color: const Color(0xFFB9E8FF).withValues(alpha: 0.42),
            ),
          ),
        ),
        Positioned(
          top: 120 + 24 * math.cos(phase * 0.9 + 1.2),
          right: -80 + 16 * math.sin(phase * 1.1),
          child: Transform.scale(
            scale: 1.0 + 0.05 * math.cos(phase * 1.1),
            child: _PastelBlob(
              size: 240,
              color: const Color(0xFFD9E0FF).withValues(alpha: 0.34),
            ),
          ),
        ),
        Positioned(
          bottom: -80 + 20 * math.sin(phase * 0.7 + 2.4),
          left: 20 + 26 * math.cos(phase * 0.6),
          child: Transform.scale(
            scale: 1.0 + 0.04 * math.sin(phase * 0.9 + 1.5),
            child: _PastelBlob(
              size: 220,
              color: const Color(0xFFDDF0FF).withValues(alpha: 0.30),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDark(double phase) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F172A), Color(0xFF18243C), Color(0xFF1F2F4B)],
              stops: [0.0, 0.48, 1.0],
            ),
          ),
        ),
        // 깊은 navy blob 1개 — 화면 우측 상단에서 매우 천천히 표류.
        Positioned(
          top: 60 + 28 * math.sin(phase),
          right: -120 + 30 * math.cos(phase * 0.6),
          child: Transform.scale(
            scale: 1.0 + 0.06 * math.sin(phase * 1.2),
            child: _PastelBlob(
              size: 300,
              color: const Color(0xFF24416E).withValues(alpha: 0.55),
            ),
          ),
        ),
        Positioned(
          bottom: -120 + 24 * math.cos(phase * 0.7 + 1.8),
          left: -80 + 18 * math.sin(phase * 0.9),
          child: Transform.scale(
            scale: 1.0 + 0.05 * math.cos(phase * 0.85),
            child: _PastelBlob(
              size: 260,
              color: const Color(0xFF1B2C49).withValues(alpha: 0.65),
            ),
          ),
        ),
        // 별빛 — 항공 야간 운항의 도시 야경/별 메타포.
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              size: Size.infinite,
              painter: _StarfieldPainter(phase: phase),
            ),
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

/// 다크 모드 배경 위의 별·도시 야경 효과.
///
/// 각 별은 (xFraction, yFraction, phaseOffset, baseAlpha) 로 정의되고,
/// 부모의 공통 [phase] 에서 파생한 비대칭 sin 으로 alpha 가 0.4~1.0 사이를
/// 호흡하도록 한다. 외곽 glow + 안쪽 코어 2 layer 로 *진짜 별처럼* 보이게.
class _StarfieldPainter extends CustomPainter {
  _StarfieldPainter({required this.phase});

  final double phase;

  // [xFraction, yFraction, phaseOffset, baseAlpha]
  static const List<List<double>> _stars = [
    [0.08, 0.12, 0.0, 0.55],
    [0.22, 0.34, 1.2, 0.62],
    [0.43, 0.18, 0.5, 0.42],
    [0.55, 0.62, 2.1, 0.55],
    [0.71, 0.28, 1.5, 0.50],
    [0.84, 0.45, 0.8, 0.60],
    [0.15, 0.78, 2.8, 0.45],
    [0.36, 0.86, 1.9, 0.50],
    [0.62, 0.92, 0.4, 0.42],
    [0.78, 0.74, 2.5, 0.55],
    [0.92, 0.16, 1.7, 0.50],
    [0.05, 0.55, 2.2, 0.45],
    [0.48, 0.05, 0.9, 0.52],
    [0.31, 0.50, 2.6, 0.48],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in _stars) {
      final x = star[0] * size.width;
      final y = star[1] * size.height;
      // 별마다 2배속으로 호흡 — 부드러운 트윙클.
      final localPhase = phase * 2 + star[2];
      final twinkle = 0.4 + 0.6 * (math.sin(localPhase) * 0.5 + 0.5);
      final alpha = (star[3] * twinkle).clamp(0.0, 1.0);

      // 외곽 글로우 (blurred halo)
      canvas.drawCircle(
        Offset(x, y),
        2.6,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha * 0.20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
      );
      // 코어
      canvas.drawCircle(
        Offset(x, y),
        0.95,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.phase != phase;
}
