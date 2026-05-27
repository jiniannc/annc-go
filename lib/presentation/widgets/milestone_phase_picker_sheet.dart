import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/ui_constants.dart';

/// 마일스톤바 long-press 시 전체 phase 를 그리드로 보여주는 점프 시트.
Future<void> showMilestonePhasePickerSheet(
  BuildContext context, {
  required List<String> milestones,
  required String? selected,
  required Set<String> audioReadyMilestones,
  required ValueChanged<String> onSelect,
}) {
  if (milestones.isEmpty) {
    return Future<void>.value();
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.24),
    sheetAnimationStyle: UiConstants.quickModalSheetAnimationStyle,
    builder: (sheetContext) {
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final surface = isDark
          ? const Color(0xFF1E2735).withValues(alpha: 0.96)
          : Colors.white.withValues(alpha: 0.97);
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.52;

      return Align(
        alignment: Alignment.bottomCenter,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(UiConstants.quickModalSheetTopCornerRadius),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Material(
              color: surface,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(sheetContext)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '방송 단계 바로가기',
                        style: Theme.of(sheetContext).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '루틴 방송 순서 중 원하는 단계로 즉시 이동합니다.',
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.62),
                            ),
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < milestones.length; i++)
                                _PhaseChip(
                                  label: milestones[i],
                                  index: i + 1,
                                  isSelected: milestones[i] == selected,
                                  hasAudio: audioReadyMilestones.contains(
                                    milestones[i],
                                  ),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    Navigator.of(sheetContext).pop();
                                    onSelect(milestones[i]);
                                  },
                                ),
                            ],
                          ),
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
    },
  );
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({
    required this.label,
    required this.index,
    required this.isSelected,
    required this.hasAudio,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool isSelected;
  final bool hasAudio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isSelected
        ? (isDark ? const Color(0xFF5DAF8A) : const Color(0xFF67C88F))
        : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
            alpha: isDark ? 0.55 : 0.85,
          );
    final border = isSelected
        ? (isDark ? const Color(0xFF92D0B2) : const Color(0xFF8DD8B1))
        : Theme.of(context).colorScheme.outline.withValues(alpha: 0.18);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border, width: isSelected ? 1.1 : 0.8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.88)
                        : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface.withValues(
                              alpha: 0.86,
                            ),
                    ),
                  ),
                ),
                if (hasAudio) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.volume_up_rounded,
                    size: 14,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.92)
                        : const Color(0xFF5C88FF),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
