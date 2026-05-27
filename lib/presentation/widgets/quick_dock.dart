import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';
import '../providers/situational_provider.dart';
import 'liquid_glass_card.dart';
import 'pressable_scale.dart';

/// 홈 화면 하단 도크.
///
/// 6개의 상황별 카테고리 + 'Quick Access' (즉시 4x4 미니 팝업) + 'Emergency'
/// (풀스크린, 레드 템플릿) 까지 총 8개 탭을 한 줄로 배치한다.
///
/// 톤은 navy ink + 단일 accent(goOrange)로 통일하고, Quick Access 만
/// situational orange 를 중심에서 바깥으로 페이드되는 소프트 하이라이트로
/// "빠르게 가는 길" 임을 자연스럽게 드러낸다.
/// Emergency 는 다른 6개와 명확히 구분되는 강한 red accent.
class QuickDock extends StatelessWidget {
  const QuickDock({
    super.key,
    required this.onCategoryTap,
    required this.onQuickAccessTap,
    required this.onEmergencyTap,
    this.onCategoryLongPress,
    this.quickAccessAnchorKey,
    this.highlightCategory,
  });

  final void Function(SituationalCategoryDef def) onCategoryTap;

  /// 카테고리 탭 long-press — 미리보기 peek 시트.
  final void Function(SituationalCategoryDef def)? onCategoryLongPress;

  /// Quick Access 미니 팝업을 띄울 때 호출 — anchor 위치 계산은 호출부에서
  /// [quickAccessAnchorKey] 로 GlobalKey 의 RenderBox 를 읽어 직접 처리.
  final VoidCallback onQuickAccessTap;

  /// Emergency 풀스크린 라우트로 이동할 때 호출.
  final VoidCallback onEmergencyTap;

  /// Quick Access 도크 버튼의 위치를 알아내기 위한 GlobalKey. null이면 anchor
  /// 없이 동작하고, 호출부가 화면 중앙 등 fallback 위치를 결정한다.
  final GlobalKey? quickAccessAnchorKey;

  final SituationalCategoryKind? highlightCategory;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final ink = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : UiConstants.navyInk;
    final muted = onSurface.withValues(alpha: isDark ? 0.62 : 0.58);
    final quickAccessColor = isDark
        ? const Color(0xFFFFBE8A)
        : UiConstants.situationalOrange;
    final emergencyColor = isDark
        ? const Color(0xFFFF8A8D)
        : const Color(0xFFC9353B);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: LiquidGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          borderRadius: 22,
          child: Row(
            children: [
              for (final def in situationalCategoryOrder)
                _DockTab(
                  icon: def.icon,
                  label: def.shortLabel,
                  iconColor: highlightCategory == def.id
                      ? UiConstants.goOrange
                      : ink,
                  labelColor: highlightCategory == def.id
                      ? UiConstants.goOrange
                      : muted,
                  indicatorColor: UiConstants.goOrange,
                  showIndicator: highlightCategory == def.id,
                  onTap: () => onCategoryTap(def),
                  onLongPress: onCategoryLongPress == null
                      ? null
                      : () => onCategoryLongPress!(def),
                ),
              _DockTab(
                key: quickAccessAnchorKey,
                icon: Icons.bolt_rounded,
                label: 'Quick',
                iconColor: quickAccessColor,
                labelColor: quickAccessColor,
                indicatorColor: quickAccessColor,
                emphasizeBackground: true,
                onTap: onQuickAccessTap,
              ),
              _DockTab(
                icon: Icons.sos_rounded,
                label: '비상',
                iconColor: emergencyColor,
                labelColor: emergencyColor,
                labelBold: true,
                indicatorColor: emergencyColor,
                onTap: onEmergencyTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockTab extends StatelessWidget {
  const _DockTab({
    super.key,
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.labelColor,
    required this.indicatorColor,
    required this.onTap,
    this.onLongPress,
    this.showIndicator = false,
    this.labelBold = false,
    this.emphasizeBackground = false,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color labelColor;
  final Color indicatorColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool showIndicator;
  final bool labelBold;

  /// Quick Access 탭처럼 다른 항목과 살짝 구분할 때 — 테두리 없이 중앙만
  /// 은은한 색이 있고 가장자리로 투명하게 사라지는 방사형 그라데이션을 쓴다.
  final bool emphasizeBackground;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: PressableScale(
        // Dock 카테고리/Quick/Emergency 의 햅틱은 호출부(home_screen)에서 이미
        // light/medium/heavy 로 분기해서 호출하므로 여기서는 중복 처리하지 않는다.
        onTap: onTap,
        onLongPress: onLongPress,
        scaleDown: 0.94,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: DecoratedBox(
              // Quick Access 후광은 ripple/hover 영역과 동일한 사각형을 채워야
              // 시각적으로 "눌리는 범위 = 빛나는 범위" 가 일치한다. 따라서
              // 그라데이션은 InkWell 의 직접 자식으로 두고, 내부 패딩은
              // 안쪽 Column 쪽으로 옮긴다.
              decoration: emphasizeBackground
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.2),
                        radius: 1.25,
                        colors: [
                          indicatorColor.withValues(
                            alpha: isDark ? 0.26 : 0.20,
                          ),
                          indicatorColor.withValues(
                            alpha: isDark ? 0.10 : 0.07,
                          ),
                          indicatorColor.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    )
                  : const BoxDecoration(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20, color: iconColor),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: labelBold
                              ? FontWeight.w800
                              : FontWeight.w700,
                          letterSpacing: labelBold ? 0.4 : -0.2,
                          color: labelColor,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: showIndicator ? 14 : 0,
                      height: 2.5,
                      decoration: BoxDecoration(
                        color: indicatorColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
