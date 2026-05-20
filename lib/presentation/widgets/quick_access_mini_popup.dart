import 'dart:math' as math;
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

const int _kGridCols = 4;
const int _kGridRows = 4;
const int _kPageCells = _kGridCols * _kGridRows;

const double _kCrossSpacing = 7;
const double _kMainSpacing = 7;
const double _kGridPadH = 3;
const double _kGridPadV = 2;

const double _popupMaxWidth = 384;
const double _popupHorizontalMargin = 12;
const double _gapToAnchor = 10;

/// 셀이 넓지·낮게 느껴질 때(기본값이 클수록 세로 높이↓).
const double _comfortAspectRatio = 1.06;

/// 도크의 Quick Access 탭 위에 떠오르는 4×4 미니 팝업.
Future<void> showQuickAccessMiniPopup({
  required BuildContext context,
  required WidgetRef ref,
  GlobalKey? anchorKey,
  required Future<void> Function(SituationalScript script) onNavigateToScript,
}) async {
  await Navigator.of(context).push<void>(
    _QuickAccessOverlayRoute(
      anchorKey: anchorKey,
      onNavigateToScript: onNavigateToScript,
    ),
  );
}

class _QuickAccessOverlayRoute extends PopupRoute<void> {
  _QuickAccessOverlayRoute({
    required this.anchorKey,
    required this.onNavigateToScript,
  });

  final GlobalKey? anchorKey;
  final Future<void> Function(SituationalScript script) onNavigateToScript;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.2);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Quick Access 닫기';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 210);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return _QuickAccessAnchoredPopup(
      anchorKey: anchorKey,
      routeAnimation: animation,
      onNavigateToScript: onNavigateToScript,
      onDismiss: () {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final glide = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(glide),
        child: ScaleTransition(
          alignment: Alignment.bottomCenter,
          scale: Tween<double>(
            begin: 0.925,
            end: 1,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
              reverseCurve: Curves.easeInCubic,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _QuickGridSpec {
  const _QuickGridSpec({required this.height, required this.aspectRatio});

  final double height;
  final double aspectRatio;
}

_QuickGridSpec _computeQuickGrid({
  required double innerWidth,
  required double maxPageHeight,
}) {
  var aspect = _comfortAspectRatio;

  double heightFor(double asp) {
    final gw = innerWidth - _kGridPadH * 2;
    final tileW = (gw - _kCrossSpacing * (_kGridCols - 1)) / _kGridCols;
    final tileH = tileW / asp;
    return tileH * _kGridRows + _kMainSpacing * (_kGridRows - 1) + _kGridPadV * 2;
  }

  double h = heightFor(aspect);

  while (maxPageHeight.isFinite && h > maxPageHeight + 0.25 && aspect < 1.7) {
    aspect += maxPageHeight < 260 ? 0.06 : 0.04;
    h = heightFor(aspect);
  }

  return _QuickGridSpec(height: h, aspectRatio: aspect);
}

class _PopupPosition {
  const _PopupPosition({
    required this.left,
    required this.bottom,
    required this.maxWidth,
    required this.availableAboveViewport,
  });

  final double left;
  final double bottom;
  final double maxWidth;

  /// 앵커 윗쪽으로 쓸 수 있는 대략적 세로 여유(px).
  final double availableAboveViewport;
}

class _QuickAccessAnchoredPopup extends ConsumerStatefulWidget {
  const _QuickAccessAnchoredPopup({
    required this.anchorKey,
    required this.routeAnimation,
    required this.onNavigateToScript,
    required this.onDismiss,
  });

  final GlobalKey? anchorKey;
  final Animation<double> routeAnimation;
  final Future<void> Function(SituationalScript script) onNavigateToScript;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_QuickAccessAnchoredPopup> createState() =>
      _QuickAccessAnchoredPopupState();
}

class _QuickAccessAnchoredPopupState
    extends ConsumerState<_QuickAccessAnchoredPopup> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<SituationalQuickAccessRowModel> _allRowsSorted(
    List<SituationalQuickAccessRowModel> source,
  ) {
    final rows = source.where((r) => !r.isEmpty).toList();
    rows.sort((a, b) {
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      return source.indexOf(a).compareTo(source.indexOf(b));
    });
    return rows;
  }

  Future<void> _onPickRow(SituationalQuickAccessRowModel row) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);

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
    widget.onDismiss();
    await widget.onNavigateToScript(script);
  }

  _PopupPosition _resolvePosition(Size screenSize, EdgeInsets viewPadding) {
    final media = MediaQuery.of(context);

    final maxWidth = math.min(
      _popupMaxWidth,
      screenSize.width - _popupHorizontalMargin * 2,
    );

    final box = widget.anchorKey?.currentContext?.findRenderObject();
    late double anchorTopY;
    if (box is RenderBox && box.attached) {
      anchorTopY = box.localToGlobal(Offset.zero).dy;
    } else {
      anchorTopY = screenSize.height * 0.55;
    }

    var left = (screenSize.width - maxWidth) / 2;
    if (box is RenderBox && box.attached) {
      final topLeft = box.localToGlobal(Offset.zero);
      left = topLeft.dx + box.size.width / 2 - maxWidth / 2;
    }
    left = left.clamp(
      _popupHorizontalMargin,
      screenSize.width - maxWidth - _popupHorizontalMargin,
    );

    final bottom = box is RenderBox && box.attached
        ? screenSize.height - anchorTopY + _gapToAnchor
        : media.padding.bottom + 28;

    final availableAbove =
        (anchorTopY - viewPadding.top - 14).clamp(112.0, screenSize.height);

    return _PopupPosition(
      left: left,
      bottom: bottom,
      maxWidth: maxWidth,
      availableAboveViewport: availableAbove,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _allRowsSorted(ref.watch(situationalQuickAccessRowsProvider));
    final pageCount =
        math.max(1, (rows.length / _kPageCells).ceil());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    final media = MediaQuery.of(context);
    final screen = media.size;
    final pos = _resolvePosition(screen, media.padding);

    const outerPad = 12.0;
    final innerContentW = math.max(
      120.0,
      pos.maxWidth - outerPad * 2,
    );

    const headerH = 36.0;
    final dotsH = pageCount > 1 ? 20.0 : 0.0;
    final chromeBelowHeader = dotsH + 18;

    final natural = _computeQuickGrid(
      innerWidth: innerContentW,
      maxPageHeight: double.infinity,
    );

    final maxGridBudget =
        (pos.availableAboveViewport - headerH - chromeBelowHeader - outerPad).clamp(
          140.0,
          screen.height * 0.65,
        );

    final gridSpec = maxGridBudget + 40 < natural.height
        ? _computeQuickGrid(
            innerWidth: innerContentW,
            maxPageHeight: maxGridBudget,
          )
        : natural;

    final navyGlow = UiConstants.situationalNavy.withValues(
      alpha: isDark ? 0.45 : 0.14,
    );
    final orangeEdge = UiConstants.situationalOrange.withValues(
      alpha: isDark ? 0.38 : 0.26,
    );

    return Stack(
      children: [
        Positioned(
          left: pos.left,
          bottom: pos.bottom,
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: pos.maxWidth),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF1E2938).withValues(alpha: 0.94),
                                const Color(0xFF171F2E).withValues(alpha: 0.92),
                              ]
                            : [
                                UiConstants.warmSurface.withValues(alpha: 0.94),
                                const Color(
                                  0xFFEAF0FA,
                                ).withValues(alpha: 0.9),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: navyGlow),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.52)
                              : navyGlow.withValues(alpha: 0.42),
                          blurRadius: 32,
                          spreadRadius: -10,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: orangeEdge.withValues(alpha: 0.38),
                          blurRadius: 18,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        outerPad,
                        11,
                        outerPad,
                        13,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            onSurface: onSurface,
                            onClose: widget.onDismiss,
                          ),
                          const SizedBox(height: 11),
                          if (rows.isEmpty)
                            _Empty(onSurface: onSurface)
                          else
                            _PagedGrid(
                              rows: rows,
                              pageCount: pageCount,
                              pageController: _pageController,
                              pageHeight: gridSpec.height,
                              aspectRatio: gridSpec.aspectRatio,
                              onPageChanged: (i) =>
                                  setState(() => _currentPage = i),
                              onPick: _onPickRow,
                              routeAnimation: widget.routeAnimation,
                            ),
                          if (pageCount > 1) ...[
                            const SizedBox(height: 8),
                            _PageDots(
                              count: pageCount,
                              index: _currentPage,
                              color: UiConstants.situationalOrange,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onSurface,
    required this.onClose,
  });

  final Color onSurface;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final accent = UiConstants.situationalOrange;
    final ink = onSurface.withValues(alpha: 0.92);
    return Row(
      children: [
        Icon(Icons.flash_on_rounded, size: 18, color: accent),
        const SizedBox(width: 8),
        Text(
          'Quick Access',
          style: TextStyle(
            fontSize: 13.75,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.22,
            color: ink,
          ),
        ),
        const Spacer(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onClose();
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.close_rounded,
                size: 22,
                color: ink.withValues(alpha: 0.72),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSurface});
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 22),
      child: Text(
        '등록된 바로가기가 없습니다.\n\n'
        '스프레드시트에 **Situational_Quick_Access** 탭을 추가하고 동기화해 주세요.',
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

class _PagedGrid extends StatelessWidget {
  const _PagedGrid({
    required this.rows,
    required this.pageCount,
    required this.pageController,
    required this.pageHeight,
    required this.aspectRatio,
    required this.onPageChanged,
    required this.onPick,
    required this.routeAnimation,
  });

  final List<SituationalQuickAccessRowModel> rows;
  final int pageCount;
  final PageController pageController;
  final double pageHeight;
  final double aspectRatio;
  final ValueChanged<int> onPageChanged;
  final void Function(SituationalQuickAccessRowModel row) onPick;
  final Animation<double> routeAnimation;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: pageHeight,
      child: PageView.builder(
        controller: pageController,
        onPageChanged: onPageChanged,
        physics: const BouncingScrollPhysics(),
        itemCount: pageCount,
        itemBuilder: (context, page) {
          final start = page * _kPageCells;
          final end = math.min(start + _kPageCells, rows.length);
          final slice = rows.sublist(start, end);
          return _SinglePageGrid(
            rows: slice,
            aspectRatio: aspectRatio,
            routeAnimation: routeAnimation,
            onPick: onPick,
          );
        },
      ),
    );
  }
}

class _SinglePageGrid extends StatelessWidget {
  const _SinglePageGrid({
    required this.rows,
    required this.aspectRatio,
    required this.routeAnimation,
    required this.onPick,
  });

  final List<SituationalQuickAccessRowModel> rows;
  final double aspectRatio;
  final Animation<double> routeAnimation;
  final void Function(SituationalQuickAccessRowModel row) onPick;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: _kGridPadH, vertical: _kGridPadV),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kGridCols,
        mainAxisSpacing: _kMainSpacing,
        crossAxisSpacing: _kCrossSpacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final stagger = Interval(
          (i * 0.026).clamp(0.0, 0.45),
          1.0,
          curve: Curves.easeOutCubic,
        );
        final anim = CurvedAnimation(
          parent: routeAnimation,
          curve: stagger,
          reverseCurve: Curves.easeInCubic,
        );
        return _QuickAccessTile(
          row: rows[i],
          openAnimation: anim,
          onTap: () => onPick(rows[i]),
        );
      },
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  const _QuickAccessTile({
    required this.row,
    required this.openAnimation,
    required this.onTap,
  });

  final SituationalQuickAccessRowModel row;
  final Animation<double> openAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final navy = UiConstants.situationalNavy;
    final orange = UiConstants.situationalOrange;

    return AnimatedBuilder(
      animation: openAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 5 * (1 - openAnimation.value)),
          child: Opacity(opacity: openAnimation.value, child: child),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          splashColor: orange.withValues(alpha: 0.17),
          highlightColor: navy.withValues(alpha: 0.06),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        onSurface.withValues(alpha: 0.06),
                        onSurface.withValues(alpha: 0.028),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.93),
                        UiConstants.warmSurface.withValues(alpha: 0.86),
                      ],
              ),
              border: Border.all(
                color: isDark ? navy.withValues(alpha: 0.32) : navy.withValues(alpha: 0.1),
              ),
              boxShadow: [
                BoxShadow(
                  color: navy.withValues(alpha: isDark ? 0.2 : 0.05),
                  blurRadius: 9,
                  offset: const Offset(0, 3),
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              child: LayoutBuilder(
                builder: (context, c) {
                  final iconSize = math.min(22, c.maxHeight * 0.34).toDouble();
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Icon(
                            quickAccessResolvedIcon(row),
                            size: iconSize,
                            color: orange.withValues(alpha: isDark ? 1 : 0.9),
                          ),
                        ),
                      ),
                      Text(
                        row.gridCellLabel,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isDark ? 10.1 : 10.25,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color:
                              onSurface.withValues(alpha: isDark ? 0.92 : 0.84),
                          letterSpacing: -0.17,
                        ),
                      ),
                      const SizedBox(height: 2),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.index,
    required this.color,
  });

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                width: i == index ? 14 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: i == index ? 0.95 : 0.34),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: i == index
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: 6,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
