import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';

/// 스플래시·헤더 등에서 쓰는 얇은 동기화/준비 상태 게이지.
///
/// Splash 의 150×2 바에서 Home 헤더의 48×2 인디케이터로 [Hero] morph 할 때
/// [heroTag] / [syncProgressHeroShuttle] 을 함께 사용한다.
class SyncMicroProgressBar extends StatelessWidget {
  const SyncMicroProgressBar({
    super.key,
    required this.progress,
    this.width = 150,
    this.height = 2,
    this.showGlow = true,
  });

  static const String heroTag = 'sync-ready-indicator';

  final double progress;
  final double width;
  final double height;

  /// 끝점 glow dot 표시 여부. 헤더 인디케이터는 false 로 두면 더 절제된다.
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: width,
              height: height,
              color: Colors.white.withValues(alpha: 0.42),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: p),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return SizedBox(
                    width: width * value,
                    height: height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  UiConstants.goOrange.withValues(alpha: 0.72),
                                  UiConstants.goOrange,
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (showGlow && value > 0.02)
                          Positioned(
                            right: -4,
                            top: -5,
                            child: IgnorePointer(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: UiConstants.goOrange.withValues(
                                        alpha: 0.65,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 0.2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Splash 게이지 → Home 헤더 인디케이터 Hero flight.
Widget syncProgressHeroShuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  return FittedBox(
    fit: BoxFit.contain,
    child: SyncMicroProgressBar(
      progress: 1.0,
      width: direction == HeroFlightDirection.push ? 150 : 48,
      height: 2,
      showGlow: direction == HeroFlightDirection.push,
    ),
  );
}
