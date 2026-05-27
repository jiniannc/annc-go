import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// 스플래시 인트로 Lottie → 홈 헤더 [StaticAnncLogo] 로 향하는 Hero 의
/// 공통 `flightShuttleBuilder`.
///
/// flight 동안 항상 [StaticAnncLogo] 를 [FittedBox] 안에서 렌더링한다. 인트로
/// Lottie 의 마지막 프레임과 StaticAnncLogo 첫 프레임이 동일한 브랜드마크라
/// flight 시작 시 swap 이 인지되지 않고, FittedBox.contain 이 240×240 →
/// 128×40 의 종횡비 차이를 흡수해 부드럽게 morphing 된다.
Widget anncLogoFlightShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  return const FittedBox(
    fit: BoxFit.contain,
    child: StaticAnncLogo(height: 40),
  );
}

/// [StaticLogo.json] 로고 — 파일명은 Static이나 화면에서는 **무한 루프** 재생 (스플래시 풀 애니메이션과 분리).
///
/// 캔버스가 가로로 길어 [height]만 지정하고 폭은 Lottie 비율(450:140)에 맞춥니다.
class StaticAnncLogo extends StatefulWidget {
  const StaticAnncLogo({super.key, required this.height});

  static const String assetPath = 'lottie/StaticLogo.json';

  /// `StaticLogo.json` composition 크기 (w/h) — 레이아웃 비율용.
  static const double designWidth = 450;
  static const double designHeight = 140;

  final double height;

  @override
  State<StaticAnncLogo> createState() => _StaticAnncLogoState();
}

class _StaticAnncLogoState extends State<StaticAnncLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    _controller
      ..duration = composition.duration
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final w =
        widget.height *
        (StaticAnncLogo.designWidth / StaticAnncLogo.designHeight);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: w,
      height: widget.height,
      child: Lottie.asset(
        StaticAnncLogo.assetPath,
        controller: _controller,
        delegates: isDark
            ? LottieDelegates(
                values: [
                  ValueDelegate.color(
                    const ['**', 'Fill'],
                    callback: (frameInfo) {
                      final original =
                          frameInfo.startValue ??
                          frameInfo.endValue ??
                          Colors.white;
                      if (_isLogoCharcoal(original)) {
                        return Colors.white;
                      }
                      return original;
                    },
                  ),
                ],
              )
            : null,
        fit: BoxFit.contain,
        alignment: Alignment.centerLeft,
        onLoaded: _onLoaded,
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }

  bool _isLogoCharcoal(Color color) {
    final r = color.red / 255.0;
    final g = color.green / 255.0;
    final b = color.blue / 255.0;
    final rgbClose = (r - g).abs() < 0.03 && (g - b).abs() < 0.03;
    return rgbClose && r <= 0.28 && g <= 0.28 && b <= 0.28;
  }
}
