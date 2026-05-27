import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ui_constants.dart';
import '../../providers/announcement_provider.dart';
import '../../widgets/announcement_script_block.dart';
import '../../widgets/quick_modal_sheet_shell.dart';
import '../../widgets/staggered_entrance.dart';

/// 승무원 비상 안내 바텀시트 (`Emergency` 시트 기반).
///
/// 시츄에이셔널 바로가기·터뷸런스와 동일하게 [showModalBottomSheet] + 글래스 패널.
class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      sheetAnimationStyle: UiConstants.quickModalSheetAnimationStyle,
      builder: (sheetContext) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        final screenH = MediaQuery.sizeOf(sheetContext).height;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: QuickModalSheetShell(
            sheetContext: sheetContext,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(UiConstants.quickModalSheetTopCornerRadius),
              ),
              child: SizedBox(
                height:
                    screenH * UiConstants.quickModalSheetBodyHeightFraction,
                child: const EmergencyScreen(),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

bool _segmentIsCrosscheckCue(AnnouncementPhaseSegment segment) {
  if (segment is! AnnouncementPhaseSingle) return false;
  final s = segment.script;
  final koLen = s.ko.trim().length;
  final enLen = s.en.trim().length;
  // 장문 본문(충격방지 자세 등)이 들어있는 행은 타이틀/머리줄 오탐이라도 카드로 남긴다.
  if (math.max(koLen, enLen) >= 160) return false;

  String norm(String x) =>
      x.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  bool isShortCue(String raw) {
    final n = norm(raw);
    if (n.isEmpty || !n.contains('crosscheck')) return false;
    return n.length <= 40;
  }

  if (isShortCue(s.title)) return true;
  if (isShortCue(s.ko)) return true;
  if (isShortCue(s.en)) return true;
  return false;
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen> {
  final Map<String, int?> _inlineSelectionByScript = {};

  static const Color _emergencyDeep = Color(0xFFB31E26);
  static const Color _emergencyPrimary = Color(0xFFD93540);
  static const Color _emergencyMuted = Color(0xFFE57B82);

  @override
  Widget build(BuildContext context) {
    final phases = ref.watch(emergencyPhasesProvider);
    final selectedPhase = ref.watch(selectedEmergencyPhaseProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectivePhase =
        selectedPhase ?? (phases.isNotEmpty ? phases.first : null);
    final scripts = effectivePhase == null
        ? const <TeleprompterScript>[]
        : ref.watch(formattedEmergencyScriptsByPhaseProvider(effectivePhase));

    final delayReasons = ref.watch(delayReasonsProvider);
    final selectedDelayReason = ref.watch(selectedDelayReasonProvider);
    final specialFarewellLabels = ref.watch(specialFarewellOptionsProvider);

    final segments = buildAnnouncementPhaseSegments(scripts);

    final surfaceTop = isDark
        ? const Color(0xFF1E2735).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.9);
    final surfaceBottom = isDark
        ? const Color(0xFF18212F).withValues(alpha: 0.88)
        : const Color(0xFFF5F9FF).withValues(alpha: 0.78);

    return Material(
      color: Colors.transparent,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [surfaceTop, surfaceBottom],
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildHeaderRow(context, isDark),
                const SizedBox(height: 10),
                if (phases.isEmpty)
                  Expanded(child: _buildEmptyState(context, isDark))
                else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: UiConstants.pagePadding - 6,
                    ),
                    child: _PhaseSplitToggle(
                      phases: phases,
                      selected: effectivePhase ?? phases.first,
                      emergencyDeep: _emergencyDeep,
                      emergencyPrimary: _emergencyPrimary,
                      isDark: isDark,
                      onPick: (phase) {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(selectedEmergencyPhaseProvider.notifier)
                            .state = phase;
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        UiConstants.pagePadding - 4,
                        2,
                        UiConstants.pagePadding - 4,
                        22,
                      ),
                      itemCount: segments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final seg = segments[i];
                        final Widget segment;
                        if (_segmentIsCrosscheckCue(seg)) {
                          segment = _EmergencyCrosscheckBand(
                            script: (seg as AnnouncementPhaseSingle).script,
                          );
                        } else {
                          segment = _EmergencySegmentGlassCard(
                          isDark: isDark,
                          child: buildAnnouncementSegmentWidget(
                            seg,
                            showEnglish: false,
                            delayReasons: delayReasons,
                            selectedDelayReason: selectedDelayReason,
                            specialFarewellLabels: specialFarewellLabels,
                            inlineSelectionByScript: _inlineSelectionByScript,
                            onDelayReasonChanged: (reason) {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(
                                    selectedDelayReasonProvider.notifier,
                                  )
                                  .state = reason;
                            },
                            onInlineOptionChangedForScript: (script, idx) {
                              HapticFeedback.selectionClick();
                              final k = '${script.id}:${script.inlineKey}';
                              setState(
                                () => _inlineSelectionByScript[k] = idx,
                              );
                            },
                            onSpecialFarewellChangedForScript: (script, idx) {
                              HapticFeedback.selectionClick();
                              final k = '${script.id}:special_farewell';
                              setState(
                                () => _inlineSelectionByScript[k] = idx,
                              );
                            },
                            onTimeRefresh: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(
                                    routineScriptRefreshTickProvider.notifier,
                                  )
                                  .state++;
                            },
                            presentTitleInRequired: true,
                            requiredTitleAccent: _emergencyPrimary,
                            emergencyPhaseLabel:
                                effectivePhase ?? phases.first,
                          ),
                        );
                        }
                        return StaggeredEntrance(
                          index: i,
                          child: segment,
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    final ink =
        scheme.onSurface.withValues(alpha: isDark ? 0.95 : 0.88);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).maybePop();
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.close_rounded, size: 22, color: ink),
              ),
            ),
          ),
          const SizedBox(width: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_emergencyDeep, _emergencyPrimary],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: _emergencyPrimary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              'EMERGENCY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '비상상황 기내방송',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.35,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurface.withValues(alpha: 0.78);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
        child: _EmergencyGlassPanel(
          isDark: isDark,
          tintRed: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 52,
                  color:
                      Color.alphaBlend(_emergencyMuted.withValues(alpha: 0.5), color),
                ),
                const SizedBox(height: 16),
                Text(
                  '아직 Emergency 시트가 비어 있습니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '스프레드시트에 `Emergency` 탭을 추가하고\n'
                  'Announcements와 동일한 컬럼(Phase, PhaseID, Order, Title, '
                  'Content_KO, Content_EN, Option, Condition_Tag, Inline_*) 으로 '
                  '문안을 채운 뒤 동기화해 주세요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.75,
                    fontWeight: FontWeight.w500,
                    color: color.withValues(alpha: 0.82),
                    height: 1.52,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 카드 없이 크로스체크 구간만 눈에 띄게 — 양옆 점선 + 가운데 정렬·볼드.
class _EmergencyCrosscheckBand extends StatelessWidget {
  const _EmergencyCrosscheckBand({
    required this.script,
  });

  final TeleprompterScript script;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final cue = script.ko.trim().isNotEmpty
        ? script.ko.trim()
        : script.en.trim();
    final display = cue.isNotEmpty ? cue : 'Crosscheck!';
    final dashColor = onSurface.withValues(alpha: isDark ? 0.26 : 0.22);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _CrosscheckDashedLine(color: dashColor),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              display,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                height: 1.22,
                color: onSurface.withValues(alpha: isDark ? 0.96 : 0.9),
              ),
            ),
          ),
          Expanded(
            child: _CrosscheckDashedLine(color: dashColor),
          ),
        ],
      ),
    );
  }
}

class _CrosscheckDashedLine extends StatelessWidget {
  const _CrosscheckDashedLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: CustomPaint(
        painter: _HorizontalDashPainter(color: color),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HorizontalDashPainter extends CustomPainter {
  const _HorizontalDashPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.5;
    const dash = 4.5;
    const gap = 3.5;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.15
      ..strokeCap = StrokeCap.round;
    var x = 0.0;
    while (x < size.width) {
      final end = math.min(x + dash, size.width);
      if (end > x) {
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalDashPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// 세그먼트 — 시츄에이셔널 시트와 맞춘 무테두리 소프트 글래스.
class _EmergencySegmentGlassCard extends StatelessWidget {
  const _EmergencySegmentGlassCard({
    required this.child,
    required this.isDark,
  });

  final Widget child;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _EmergencyGlassPanel(
      isDark: isDark,
      tintRed: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(UiConstants.pagePadding - 10, 16, UiConstants.pagePadding - 10, 16),
        child: child,
      ),
    );
  }
}

/// 앱 공통 글래스와 맞춘 패널(테두리 없이 블러·그림자).
class _EmergencyGlassPanel extends StatelessWidget {
  const _EmergencyGlassPanel({
    required this.child,
    required this.isDark,
    this.tintRed = false,
  });

  final Widget child;
  final bool isDark;
  final bool tintRed;

  @override
  Widget build(BuildContext context) {
    final surfaceTop = isDark
        ? (tintRed
            ? const Color(0xFF252028).withValues(alpha: 0.82)
            : const Color(0xFF1E2735).withValues(alpha: 0.78))
        : (tintRed
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.72));

    final surfaceBottom = isDark
        ? (tintRed
            ? const Color(0xFF1C1518).withValues(alpha: 0.8)
            : const Color(0xFF18212F).withValues(alpha: 0.74))
        : (tintRed
              ? const Color(0xFFFFF8F9).withValues(alpha: 0.86)
              : const Color(0xFFF5F9FF).withValues(alpha: 0.62));

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(UiConstants.cardRadius),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x66000000)
                : const Color(0xFF93A8C2).withValues(alpha: 0.13),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 16),
          ),
          if (tintRed)
            BoxShadow(
              color: Color(0xFFD93540).withValues(alpha: isDark ? 0.06 : 0.08),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(UiConstants.cardRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [surfaceTop, surfaceBottom],
              ),
              borderRadius: BorderRadius.circular(UiConstants.cardRadius),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _PhaseSplitToggle extends StatelessWidget {
  const _PhaseSplitToggle({
    required this.phases,
    required this.selected,
    required this.emergencyDeep,
    required this.emergencyPrimary,
    required this.isDark,
    required this.onPick,
  });

  final List<String> phases;
  final String selected;
  final Color emergencyDeep;
  final Color emergencyPrimary;
  final bool isDark;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    if (phases.length == 2) {
      return _twoSplit(phases[0], phases[1]);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final p in phases)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _PhaseChip(
                label: p,
                isSelected: p == selected,
                emergencyDeep: emergencyDeep,
                emergencyPrimary: emergencyPrimary,
                isDark: isDark,
                onTap: () => onPick(p),
              ),
            ),
        ],
      ),
    );
  }

  Widget _twoSplit(String left, String right) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color:
                UiConstants.navyInk.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color:
                emergencyPrimary.withValues(alpha: isDark ? 0.06 : 0.05),
            blurRadius: 20,
            spreadRadius: -4,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF1E2735).withValues(alpha: 0.9),
                        const Color(0xFF18212F).withValues(alpha: 0.88),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.85),
                        const Color(0xFFF5F9FF).withValues(alpha: 0.78),
                      ],
              ),
            ),
            child: SizedBox(
              height: 50,
              child: Row(
                children: [
                  Expanded(
                    child: _SplitSide(
                      label: left,
                      isSelected: left == selected,
                      isDark: isDark,
                      emergencyDeep: emergencyDeep,
                      emergencyPrimary: emergencyPrimary,
                      onTap: () => onPick(left),
                    ),
                  ),
                  SizedBox(
                    height: 28,
                    width: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(
                          alpha: isDark ? 0.08 : 0.42,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _SplitSide(
                      label: right,
                      isSelected: right == selected,
                      isDark: isDark,
                      emergencyDeep: emergencyDeep,
                      emergencyPrimary: emergencyPrimary,
                      onTap: () => onPick(right),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplitSide extends StatelessWidget {
  const _SplitSide({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.emergencyDeep,
    required this.emergencyPrimary,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final Color emergencyDeep;
  final Color emergencyPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedBg = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [emergencyDeep, emergencyPrimary],
    );

    final idleTop = isDark
        ? const Color(0xFF2E343F).withValues(alpha: 0.38)
        : Colors.white.withValues(alpha: 0.72);

    final idleBottom = isDark
        ? const Color(0xFF252A34).withValues(alpha: 0.28)
        : const Color(0xFFF0F6FF).withValues(alpha: 0.65);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: UiConstants.softAnimation,
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isSelected
                ? selectedBg
                : LinearGradient(colors: [idleTop, idleBottom]),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.crisis_alert_rounded,
                size: 17,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.95)
                    : emergencyPrimary.withValues(alpha: isDark ? 0.65 : 0.78),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.26,
                    height: 1.1,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface.withValues(
                              alpha: isDark ? 0.88 : 0.84,
                            ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.label,
    required this.isSelected,
    required this.emergencyDeep,
    required this.emergencyPrimary,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color emergencyDeep;
  final Color emergencyPrimary;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: UiConstants.softAnimation,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(colors: [emergencyDeep, emergencyPrimary])
                : null,
            color: isSelected
                ? null
                : (isDark
                      ? const Color(0xFF252830).withValues(alpha: 0.65)
                      : Colors.white.withValues(alpha: 0.62)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: emergencyPrimary.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: UiConstants.navyInk.withValues(
                        alpha: isDark ? 0.12 : 0.06,
                      ),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface.withValues(
                        alpha: 0.85,
                      ),
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
