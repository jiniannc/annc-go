import 'package:flutter/material.dart';

/// Expanding‑Pill 마일스톤 바.
///
/// 현재 Phase만 알약(Pill)으로 확장되고, 나머지는 작은 점(Dot)으로 표시.
/// 점 사이에 가느다란 연결선, 활성 Pill에 네온 글로우.
class MilestoneBar extends StatefulWidget {
  const MilestoneBar({
    super.key,
    required this.milestones,
    required this.selected,
    required this.audioReadyMilestones,
    required this.onSelect,
  });

  final List<String> milestones;
  final String? selected;
  final Set<String> audioReadyMilestones;
  final ValueChanged<String> onSelect;

  @override
  State<MilestoneBar> createState() => _MilestoneBarState();
}

class _MilestoneBarState extends State<MilestoneBar> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];
  int? _trackingPointer;
  Offset? _pointerDownPosition;
  bool _isScrubbing = false;
  String? _dragPreviewPhase;

  @override
  void initState() {
    super.initState();
    _syncKeys();
  }

  @override
  void didUpdateWidget(covariant MilestoneBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.milestones.length != widget.milestones.length) {
      _syncKeys();
    }
    if (oldWidget.selected != widget.selected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _syncKeys() {
    _itemKeys.clear();
    for (var i = 0; i < widget.milestones.length; i++) {
      _itemKeys.add(GlobalKey());
    }
  }

  void _scrollToActive() {
    final idx = widget.milestones.indexOf(widget.selected ?? '');
    if (idx < 0 || idx >= _itemKeys.length) {
      return;
    }
    final keyContext = _itemKeys[idx].currentContext;
    if (keyContext == null || !_scrollController.hasClients) {
      return;
    }
    final box = keyContext.findRenderObject() as RenderBox?;
    if (box == null) {
      return;
    }
    final scrollBox =
        _scrollController.position.context.storageContext.findRenderObject()
            as RenderBox?;
    if (scrollBox == null) {
      return;
    }
    final itemOffset = box.localToGlobal(Offset.zero, ancestor: scrollBox);
    final itemCenter = itemOffset.dx + box.size.width / 2;
    final viewportCenter = scrollBox.size.width / 2;
    final delta = itemCenter - viewportCenter;
    final target = (_scrollController.offset + delta).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  String? _phaseAtGlobalPosition(Offset globalPosition) {
    if (_itemKeys.isEmpty || widget.milestones.isEmpty) {
      return null;
    }

    String? nearestPhase;
    var nearestDistance = double.infinity;

    for (var i = 0; i < _itemKeys.length; i++) {
      final context = _itemKeys[i].currentContext;
      if (context == null) {
        continue;
      }
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) {
        continue;
      }
      final topLeft = box.localToGlobal(Offset.zero);
      final rect = topLeft & box.size;
      final centerX = rect.center.dx;
      final distance = (centerX - globalPosition.dx).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestPhase = widget.milestones[i];
      }
      if (rect.contains(globalPosition)) {
        return widget.milestones[i];
      }
    }
    return nearestPhase;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_trackingPointer != null) {
      return;
    }
    _trackingPointer = event.pointer;
    _pointerDownPosition = event.position;
    _isScrubbing = false;
    _dragPreviewPhase = null;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_trackingPointer != event.pointer) {
      return;
    }
    final down = _pointerDownPosition;
    if (down == null) {
      return;
    }
    if (!_isScrubbing) {
      final moved = (event.position - down).distance;
      if (moved < 6) {
        return;
      }
      _isScrubbing = true;
    }

    final hoverPhase = _phaseAtGlobalPosition(event.position);
    if (hoverPhase == null || hoverPhase == _dragPreviewPhase) {
      return;
    }
    setState(() {
      _dragPreviewPhase = hoverPhase;
    });
    // 손을 뗄 때까지 기다리지 않고, 스크럽 중 즉시 상위에서 본문/페이지를 맞춘다.
    widget.onSelect(hoverPhase);
  }

  void _handlePointerEnd(int pointer) {
    if (_trackingPointer != pointer) {
      return;
    }
    _trackingPointer = null;
    _pointerDownPosition = null;
    _isScrubbing = false;

    if (mounted) {
      setState(() {
        _dragPreviewPhase = null;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visualSelected = _dragPreviewPhase ?? widget.selected;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: (event) => _handlePointerEnd(event.pointer),
      onPointerCancel: (event) => _handlePointerEnd(event.pointer),
      child: SizedBox(
        height: 36,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.milestones.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 14,
                          height: 1.4,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                isDark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : const Color(0xFFC9D4E2),
                                isDark
                                    ? Colors.white.withValues(alpha: 0.42)
                                    : const Color(0xFFB3C2D5),
                                isDark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : const Color(0xFFC9D4E2),
                              ],
                            ),
                          ),
                        ),
                      _MilestonePill(
                        key: _itemKeys[i],
                        label: widget.milestones[i],
                        isActive: widget.milestones[i] == visualSelected,
                        isDark: isDark,
                        hasAudio: widget.audioReadyMilestones.contains(
                          widget.milestones[i],
                        ),
                        onTap: () => widget.onSelect(widget.milestones[i]),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MilestonePill extends StatelessWidget {
  const _MilestonePill({
    super.key,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.hasAudio,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final bool isDark;
  final bool hasAudio;
  final VoidCallback onTap;

  static const _accentPastel = Color(0xFF67C88F);
  static const _dotSize = 9.0;
  static const _pillHeight = 26.0;
  static const _duration = Duration(milliseconds: 300);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        height: _pillHeight,
        constraints: BoxConstraints(minWidth: isActive ? 78 : _dotSize),
        padding: EdgeInsets.symmetric(horizontal: isActive ? 14 : 0),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0xFF5DAF8A) : _accentPastel)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(_pillHeight / 2),
          border: isActive
              ? Border.all(
                  color: isDark
                      ? const Color(0xFF92D0B2).withValues(alpha: 0.55)
                      : const Color(0xFF8DD8B1).withValues(alpha: 0.65),
                  width: 0.85,
                )
              : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: (isDark ? _accentPastel : const Color(0xFF67C88F))
                        .withValues(alpha: 0.22),
                    blurRadius: 7,
                    spreadRadius: 0.2,
                  ),
                  BoxShadow(
                    color: (isDark ? _accentPastel : const Color(0xFF67C88F))
                        .withValues(alpha: 0.08),
                    blurRadius: 12,
                    spreadRadius: 0.2,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: _duration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: isActive
              ? Text(
                  label,
                  key: const ValueKey('active'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    height: 1.1,
                  ),
                )
              : Stack(
                  key: const ValueKey('dot'),
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: _dotSize,
                      height: _dotSize,
                      decoration: BoxDecoration(
                        color: hasAudio
                            ? const Color(0xB88EB8FF)
                            : (isDark
                                  ? const Color(0xFFD8E5FB)
                                  : const Color(0xFF9FB2C9)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: hasAudio
                              ? const Color(0xFF5C88FF)
                              : (isDark
                                    ? const Color(0x99FFFFFF)
                                    : const Color(0xFF6F88A5)),
                          width: 1.1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: hasAudio
                                ? const Color(0x665C88FF)
                                : (isDark
                                      ? const Color(0x88A9C7FF)
                                      : const Color(0x4D9FB2C8)),
                            blurRadius: isDark ? 11 : 6,
                            spreadRadius: isDark ? 0.8 : 0.1,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 3.2,
                      height: 3.2,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.96)
                            : const Color(0xFFEFF4FA),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
