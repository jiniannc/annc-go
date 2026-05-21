import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ui_constants.dart';
import '../../core/utils/situational_quick_access_icons.dart';
import '../../data/models/situational_quick_access_row_model.dart';
import '../../domain/entities/situational_script.dart';
import '../../domain/services/situational_quick_access_resolver.dart';
import '../providers/situational_provider.dart';
import '../providers/situational_quick_access_provider.dart';
import 'quick_modal_sheet_shell.dart';

/// 시나리오 바로가기: 키워드 그리드 → 시나리오 목록 → Situational 허브로 점프.
Future<void> showSituationalQuickAccessSheet(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function(SituationalScript script) onNavigateToScript,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.35),
    isDismissible: true,
    enableDrag: true,
    useSafeArea: false,
    showDragHandle: false,
    sheetAnimationStyle: UiConstants.quickModalSheetAnimationStyle,
    builder: (sheetContext) {
      return _SituationalQuickAccessSheetBody(
        onNavigateToScript: onNavigateToScript,
        sheetContext: sheetContext,
      );
    },
  );
}

class _SituationalQuickAccessSheetBody extends ConsumerStatefulWidget {
  const _SituationalQuickAccessSheetBody({
    required this.onNavigateToScript,
    required this.sheetContext,
  });

  final Future<void> Function(SituationalScript script) onNavigateToScript;
  final BuildContext sheetContext;

  @override
  ConsumerState<_SituationalQuickAccessSheetBody> createState() =>
      _SituationalQuickAccessSheetBodyState();
}

class _KeywordGroup {
  _KeywordGroup({
    required this.keyword,
    required this.icon,
    required this.rows,
  });

  final String keyword;
  final IconData icon;
  final List<SituationalQuickAccessRowModel> rows;
}

class _SituationalQuickAccessSheetBodyState
    extends ConsumerState<_SituationalQuickAccessSheetBody> {
  String? _pickedKeyword;

  List<_KeywordGroup> _groupsFromRows(
    List<SituationalQuickAccessRowModel> raw,
  ) {
    final byKey = <String, List<SituationalQuickAccessRowModel>>{};
    for (final r in raw) {
      if (r.isEmpty) continue;
      byKey.putIfAbsent(r.keyword, () => []).add(r);
    }
    final keys = byKey.keys.toList()..sort((a, b) => a.compareTo(b));
    return [
      for (final k in keys)
        _KeywordGroup(
          keyword: k,
          icon: _iconForRows(byKey[k]!),
          rows: [...byKey[k]!]
            ..sort((a, b) {
              final o = a.order.compareTo(b.order);
              if (o != 0) return o;
              return a.effectiveListTitle.compareTo(b.effectiveListTitle);
            }),
        ),
    ];
  }

  IconData _iconForRows(List<SituationalQuickAccessRowModel> rows) {
    if (rows.isEmpty) {
      return situationalQuickAccessIcon('');
    }
    for (final r in rows) {
      if (r.iconName.trim().isNotEmpty || r.keyword.trim().isNotEmpty) {
        return quickAccessResolvedIcon(r);
      }
    }
    return quickAccessResolvedIcon(rows.first);
  }

  Future<void> _onSelectRow(SituationalQuickAccessRowModel row) async {
    final navigator = Navigator.of(widget.sheetContext);
    final scaffoldMessenger = ScaffoldMessenger.of(widget.sheetContext);

    final List<SituationalScript> scripts;
    try {
      scripts = await ref.read(situationalScriptsProvider.future);
    } catch (_) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Situational 데이터를 불러오지 못했습니다. 네트워크·동기화 후 다시 시도해 주세요.',
          ),
          duration: Duration(milliseconds: 2200),
        ),
      );
      return;
    }
    if (scripts.isEmpty) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Situational 방송문이 없습니다. 시트 동기화를 확인해 주세요.',
          ),
          duration: Duration(milliseconds: 2000),
        ),
      );
      return;
    }
    final script = resolveQuickAccessTarget(scripts, row);
    if (script == null) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            '「${row.scenario}」에 해당하는 방송문을 찾을 수 없습니다.\n'
            'Quick_Access 시트의 Category/SubCategory/Scenario를 Situational 시트와 맞춰 주세요.',
          ),
          duration: const Duration(milliseconds: 2200),
        ),
      );
      return;
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    navigator.pop();
    await widget.onNavigateToScript(script);
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(situationalQuickAccessRowsProvider);
    final groups = _groupsFromRows(rows);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final surfaceTop = isDark
        ? const Color(0xFF1E2735).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.88);
    final surfaceBottom = isDark
        ? const Color(0xFF18212F).withValues(alpha: 0.88)
        : const Color(0xFFF5F9FF).withValues(alpha: 0.8);

    return QuickModalSheetShell(
      sheetContext: widget.sheetContext,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(UiConstants.quickModalSheetTopCornerRadius),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [surfaceTop, surfaceBottom],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(UiConstants.quickModalSheetTopCornerRadius),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height:
                    MediaQuery.sizeOf(context).height *
                    UiConstants.quickModalSheetBodyHeightFraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                          padding: const EdgeInsets.fromLTRB(
                            UiConstants.pagePadding,
                            8,
                            8,
                            4,
                          ),
                          child: Row(
                            children: [
                              if (_pickedKeyword != null)
                                IconButton(
                                  tooltip: '키워드로 돌아가기',
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _pickedKeyword = null);
                                  },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                              Expanded(
                                child: Text(
                                  _pickedKeyword == null
                                      ? '방송문 바로가기'
                                      : _pickedKeyword!,
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '닫기',
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(widget.sheetContext).pop();
                                },
                                icon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                              ),
                            ],
                          ),
                    ),
                    if (groups.isEmpty)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(
                                UiConstants.pagePadding,
                              ),
                              child: Text(
                                '등록된 바로가기가 없습니다.\n\n'
                                '스프레드시트에 **Situational_Quick_Access** 탭을 추가하고 '
                                '동기화해 주세요.\n'
                                '(단일 스프레드시트 모드에서는 탭 이름이 정확히 일치해야 합니다.)',
                                style: TextStyle(
                                  fontSize: 15,
                                  height: 1.45,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withValues(alpha: 0.72),
                                ),
                              ),
                            ),
                          )
                    else
                      Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 240),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              child: _pickedKeyword == null
                                  ? _KeywordGrid(
                                      key: const ValueKey('grid'),
                                      groups: groups,
                                      onPick: (k) {
                                        HapticFeedback.selectionClick();
                                        setState(() => _pickedKeyword = k);
                                      },
                                    )
                                  : _ScenarioList(
                                      key: ValueKey('list-$_pickedKeyword'),
                                      rows: groups
                                          .firstWhere(
                                            (g) => g.keyword == _pickedKeyword,
                                          )
                                          .rows,
                                      onTapRow: _onSelectRow,
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
  }
}

class _KeywordGrid extends StatelessWidget {
  const _KeywordGrid({super.key, required this.groups, required this.onPick});

  final List<_KeywordGroup> groups;
  final void Function(String keyword) onPick;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.15,
      ),
      itemCount: groups.length,
      itemBuilder: (context, i) {
        final g = groups[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => onPick(g.keyword),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: onSurface.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.08
                      : 0.06,
                ),
                border: Border.all(color: onSurface.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    g.icon,
                    size: 40,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB4C8F0)
                        : UiConstants.situationalNavy,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      g.keyword,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: onSurface,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ScenarioList extends StatelessWidget {
  const _ScenarioList({super.key, required this.rows, required this.onTapRow});

  final List<SituationalQuickAccessRowModel> rows;
  final void Function(SituationalQuickAccessRowModel row) onTapRow;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final row = rows[i];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onTapRow(row),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: onSurface.withValues(
                  alpha: Theme.of(context).brightness == Brightness.dark
                      ? 0.07
                      : 0.05,
                ),
                border: Border.all(color: onSurface.withValues(alpha: 0.09)),
              ),
              child: Row(
                children: [
                  Icon(
                    quickAccessResolvedIcon(row),
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFB4C8F0)
                        : UiConstants.situationalNavy,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.gridCellLabel,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: onSurface,
                            height: 1.25,
                          ),
                        ),
                        if (row.subCategory.trim().isNotEmpty)
                          Text(
                            '${row.situationalCategory} · ${row.subCategory}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: onSurface.withValues(alpha: 0.55),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: onSurface.withValues(alpha: 0.35),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
