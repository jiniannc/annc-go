import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ui_constants.dart';
import '../providers/situational_provider.dart';

/// 도크 카테고리 long-press 시 뜨는 1/3 높이 미리보기 시트.
Future<void> showDockCategoryPeekSheet(
  BuildContext context,
  WidgetRef ref,
  SituationalCategoryDef def, {
  required VoidCallback onOpenFull,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.22),
    sheetAnimationStyle: UiConstants.quickModalSheetAnimationStyle,
    builder: (sheetContext) {
      final count = ref.watch(situationalScriptsByCategoryProvider(def.id)).length;
      final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
      final surface = isDark
          ? const Color(0xFF1E2735).withValues(alpha: 0.94)
          : Colors.white.withValues(alpha: 0.96);
      final height = MediaQuery.sizeOf(sheetContext).height * 0.34;

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
              child: SizedBox(
                height: height,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
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
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: UiConstants.goOrange.withValues(
                                alpha: isDark ? 0.22 : 0.12,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(def.icon, color: UiConstants.goOrange),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  def.label,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  def.caption,
                                  style: Theme.of(sheetContext)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        letterSpacing: 0.8,
                                        color: Theme.of(sheetContext)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.58),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        count > 0
                            ? '등록된 방송문 $count개 · 길게 눌러 빠르게 미리보기'
                            : '이 카테고리의 방송문을 불러오는 중이거나 비어 있습니다.',
                        style: Theme.of(sheetContext).textTheme.bodySmall
                            ?.copyWith(
                              color: Theme.of(sheetContext)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.68),
                              height: 1.4,
                            ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                Navigator.of(sheetContext).pop();
                              },
                              child: const Text('닫기'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                Navigator.of(sheetContext).pop();
                                onOpenFull();
                              },
                              icon: const Icon(Icons.open_in_new_rounded, size: 18),
                              label: const Text('카테고리 열기'),
                            ),
                          ),
                        ],
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
