import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pressable_scale.dart';

/// 마일스톤 바 — 스톤 간격은 원래대로 촘촘히, Phase 라벨만 선택 스톤 위 오버레이.
class MilestoneBar extends StatefulWidget {
  const MilestoneBar({
    super.key,
    required this.milestones,
    required this.selected,
    required this.audioReadyMilestones,
    required this.onSelect,
    this.onLongPress,
    this.originIata,
    this.destinationIata,
  });

  final List<String> milestones;
  final String? selected;
  final Set<String> audioReadyMilestones;
  final void Function(String phase, {required bool isScrubbing}) onSelect;
  final VoidCallback? onLongPress;

  /// 출발지 IATA (예: `ICN`). 비어 있으면 좌측 캡을 그리지 않는다.
  final String? originIata;

  /// 도착지 IATA (예: `NRT`). 비어 있으면 우측 캡을 그리지 않는다.
  final String? destinationIata;

  @override
  State<MilestoneBar> createState() => _MilestoneBarState();
}

const double _kStoneSize = 9.0;
const double _kConnectorWidth = 14.0;
const double _kLabelAreaHeight = 26.0;
const double _kLabelStoneGap = 0.0;
const double _kStoneRowHeight = 18.0;
const double _kActiveStoneScale = 1.5;
const double _kEndpointIconSize = 18.0;
const double _kEndpointIataGap = 4.0;
const double _kEndpointTagGap = 2.0;
const double _kEndpointTagHeight = 11.0;
const double _kSpeechTailHeight = 9.0;

/// 마일스톤바 전체 높이 (라벨 + 간격 + 스톤 + DEP/ARR 태그).
const double kMilestoneBarHeight =
    _kLabelAreaHeight +
    _kLabelStoneGap +
    _kStoneRowHeight +
    _kEndpointTagGap +
    _kEndpointTagHeight;

class _MilestoneBarState extends State<MilestoneBar> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _itemKeys = [];
  int? _trackingPointer;
  Offset? _pointerDownPosition;
  bool _isScrubbing = false;
  String? _dragPreviewPhase;
  int _lastActiveIndex = 0;

  static const _scrubAnimDuration = Duration(milliseconds: 140);
  static const _tapAnimDuration = Duration(milliseconds: 220);

  Duration get _animDuration =>
      _isScrubbing ? _scrubAnimDuration : _tapAnimDuration;

  @override
  void initState() {
    super.initState();
    _syncKeys();
    final idx = widget.milestones.indexOf(widget.selected ?? '');
    if (idx >= 0) {
      _lastActiveIndex = idx;
    }
  }

  @override
  void didUpdateWidget(covariant MilestoneBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.milestones.length != widget.milestones.length) {
      _syncKeys();
    }
    if (oldWidget.selected != widget.selected && !_isScrubbing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  void _syncKeys() {
    _itemKeys.clear();
    for (var i = 0; i < widget.milestones.length; i++) {
      _itemKeys.add(GlobalKey());
    }
  }

  double _stoneCenterX(int index, {required double leadingWidth}) {
    return leadingWidth +
        index * (_kStoneSize + _kConnectorWidth) +
        _kStoneSize / 2;
  }

  double _contentWidth(int count) {
    if (count <= 0) {
      return 0;
    }
    return count * _kStoneSize + (count - 1) * _kConnectorWidth;
  }

  double _measureIataWidth(String code, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: code, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = tp.width;
    tp.dispose();
    return width;
  }

  double _endpointColumnWidth(String iataCode) {
    const iataStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.35,
      height: 1.0,
    );
    return _measureIataWidth(iataCode, iataStyle) +
        _kEndpointIataGap +
        _kEndpointIconSize;
  }

  double _trackWidth({
    required int milestoneCount,
    required bool hasOrigin,
    required bool hasDestination,
    required double originWidth,
    required double destinationWidth,
  }) {
    var width = _contentWidth(milestoneCount);
    if (hasOrigin) {
      width += originWidth + _kConnectorWidth;
    }
    if (hasDestination) {
      width += _kConnectorWidth + destinationWidth;
    }
    return width;
  }

  void _scrollToActive() {
    if (!mounted || _isScrubbing) {
      return;
    }
    final idx = widget.milestones.indexOf(widget.selected ?? '');
    if (idx < 0 || !_scrollController.hasClients) {
      return;
    }
    final viewportWidth = _scrollController.position.viewportDimension;
    if (viewportWidth <= 0) {
      return;
    }

    final originCap = widget.originIata?.trim().toUpperCase();
    final destinationCap = widget.destinationIata?.trim().toUpperCase();
    final hasOriginCap = originCap != null && originCap.isNotEmpty;
    final hasDestinationCap =
        destinationCap != null && destinationCap.isNotEmpty;
    final originWidth =
        hasOriginCap ? _endpointColumnWidth(originCap) : 0.0;
    final destinationWidth =
        hasDestinationCap ? _endpointColumnWidth(destinationCap) : 0.0;

    final contentWidth = _trackWidth(
      milestoneCount: widget.milestones.length,
      hasOrigin: hasOriginCap,
      hasDestination: hasDestinationCap,
      originWidth: originWidth,
      destinationWidth: destinationWidth,
    );
    final maxScroll = math.max(0.0, contentWidth - viewportWidth);
    final target = maxScroll <= 0
        ? 0.0
        : (_stoneCenterX(idx, leadingWidth: hasOriginCap
                ? originWidth + _kConnectorWidth
                : 0) -
                viewportWidth /
                    2)
            .clamp(0.0, maxScroll);

    if ((target - _scrollController.offset).abs() < 0.5) {
      return;
    }

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
    widget.onSelect(hoverPhase, isScrubbing: true);
  }

  void _handlePointerEnd(int pointer) {
    if (_trackingPointer != pointer) {
      return;
    }
    _trackingPointer = null;
    _pointerDownPosition = null;
    final wasScrubbing = _isScrubbing;
    _isScrubbing = false;

    if (mounted) {
      setState(() {
        _dragPreviewPhase = null;
      });
      if (wasScrubbing) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
      }
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
    final activeIndex = visualSelected == null
        ? -1
        : widget.milestones.indexOf(visualSelected);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final animDuration = _animDuration;
    final originCap = widget.originIata?.trim().toUpperCase();
    final destinationCap = widget.destinationIata?.trim().toUpperCase();
    final hasOriginCap = originCap != null && originCap.isNotEmpty;
    final hasDestinationCap =
        destinationCap != null && destinationCap.isNotEmpty;
    final originWidth =
        hasOriginCap ? _endpointColumnWidth(originCap) : 0.0;
    final destinationWidth =
        hasDestinationCap ? _endpointColumnWidth(destinationCap) : 0.0;
    final leadingWidth =
        hasOriginCap ? originWidth + _kConnectorWidth : 0.0;
    final trackWidth = _trackWidth(
      milestoneCount: widget.milestones.length,
      hasOrigin: hasOriginCap,
      hasDestination: hasDestinationCap,
      originWidth: originWidth,
      destinationWidth: destinationWidth,
    );

    final slideDirection = activeIndex >= 0
        ? (activeIndex - _lastActiveIndex).sign
        : 0;
    if (activeIndex >= 0 && activeIndex != _lastActiveIndex) {
      _lastActiveIndex = activeIndex;
    }

    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: (event) => _handlePointerEnd(event.pointer),
      onPointerCancel: (event) => _handlePointerEnd(event.pointer),
      child: SizedBox(
        height: kMilestoneBarHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: _kLabelAreaHeight,
                        width: trackWidth,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.centerLeft,
                          children: [
                            if (activeIndex >= 0)
                              _FloatingPhaseLabel(
                                centerX: _stoneCenterX(
                                  activeIndex,
                                  leadingWidth: leadingWidth,
                                ),
                                label: widget.milestones[activeIndex],
                                slideDirection: slideDirection,
                                animDuration: animDuration,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: _kLabelStoneGap),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasOriginCap) ...[
                            _RouteEndpointStoneColumn(
                              iataCode: originCap,
                              tag: 'DEP',
                              isOrigin: true,
                              isDark: isDark,
                            ),
                            _AlignedConnector(isDark: isDark),
                          ],
                          for (var i = 0;
                              i < widget.milestones.length;
                              i++) ...[
                            if (i > 0) _AlignedConnector(isDark: isDark),
                            PressableScale(
                              key: _itemKeys[i],
                              onTap: () => widget.onSelect(
                                widget.milestones[i],
                                isScrubbing: false,
                              ),
                              onLongPress: widget.onLongPress,
                              hapticOnLongPress: widget.onLongPress != null
                                  ? HapticFeedbackType.medium
                                  : null,
                              scaleDown: i == activeIndex ? 0.985 : 0.9,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: _kStoneRowHeight,
                                    child: Center(
                                      child: _MilestoneStone(
                                        isActive: i == activeIndex,
                                        isDark: isDark,
                                        hasAudio: widget
                                            .audioReadyMilestones
                                            .contains(widget.milestones[i]),
                                        animDuration: animDuration,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height:
                                        _kEndpointTagGap + _kEndpointTagHeight,
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (hasDestinationCap) ...[
                            _AlignedConnector(isDark: isDark),
                            _RouteEndpointStoneColumn(
                              iataCode: destinationCap,
                              tag: 'ARR',
                              isOrigin: false,
                              isDark: isDark,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 스톤 중심을 따라 수평 이동하는 Phase 칩 — 스톤 간격에는 영향 없음.
class _FloatingPhaseLabel extends StatelessWidget {
  const _FloatingPhaseLabel({
    required this.centerX,
    required this.label,
    required this.slideDirection,
    required this.animDuration,
    required this.isDark,
  });

  final double centerX;
  final String label;
  final int slideDirection;
  final Duration animDuration;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textStyle = TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.05,
      height: 1.15,
      color: isDark ? Colors.white.withValues(alpha: 0.96) : const Color(0xFF2A4058),
    );

    final enterOffset = slideDirection == 0
        ? const Offset(0, 0.18)
        : Offset(slideDirection * 0.18, 0.06);

    return AnimatedPositioned(
      duration: animDuration,
      curve: Curves.easeOutCubic,
      left: centerX,
      bottom: 0,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: AnimatedSwitcher(
          duration: animDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final fade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            );
            return FadeTransition(
              opacity: fade,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: enterOffset,
                  end: Offset.zero,
                ).animate(fade),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(fade),
                  child: child,
                ),
              ),
            );
          },
          child: _PhaseSpeechBubble(
            key: ValueKey(label),
            label: label,
            textStyle: textStyle,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _PhaseSpeechBubble extends StatelessWidget {
  const _PhaseSpeechBubble({
    super.key,
    required this.label,
    required this.textStyle,
    required this.isDark,
  });

  final String label;
  final TextStyle textStyle;
  final bool isDark;

  static const _bodyHPadding = 12.0;
  static const _bodyVPadding = 6.0;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _UnifiedSpeechBubblePainter(isDark: isDark),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _bodyHPadding,
          _bodyVPadding,
          _bodyHPadding,
          _bodyVPadding + _kSpeechTailHeight,
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: textStyle,
        ),
      ),
    );
  }
}

/// 본체+꼬리를 하나의 경로로 그리는 말풍선 — iOS 툴팁 톤의 부드러운 곡선.
class _UnifiedSpeechBubblePainter extends CustomPainter {
  const _UnifiedSpeechBubblePainter({required this.isDark});

  final bool isDark;

  static const _accentPastel = Color(0xFF67C88F);
  static const _radius = 12.0;
  static const _tailHalfWidth = 7.0;

  Path _bubblePath(Size size) {
    final bodyBottom = size.height - _kSpeechTailHeight;
    final cx = size.width / 2;
    final r = _radius.clamp(0.0, bodyBottom / 2);

    return Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: Radius.circular(r))
      ..lineTo(size.width, bodyBottom - r)
      ..arcToPoint(
        Offset(size.width - r, bodyBottom),
        radius: Radius.circular(r),
      )
      ..lineTo(cx + _tailHalfWidth, bodyBottom)
      ..cubicTo(
        cx + _tailHalfWidth * 0.42,
        bodyBottom + _kSpeechTailHeight * 0.38,
        cx + _tailHalfWidth * 0.14,
        bodyBottom + _kSpeechTailHeight,
        cx,
        bodyBottom + _kSpeechTailHeight,
      )
      ..cubicTo(
        cx - _tailHalfWidth * 0.14,
        bodyBottom + _kSpeechTailHeight,
        cx - _tailHalfWidth * 0.42,
        bodyBottom + _kSpeechTailHeight * 0.38,
        cx - _tailHalfWidth,
        bodyBottom,
      )
      ..lineTo(r, bodyBottom)
      ..arcToPoint(
        Offset(0, bodyBottom - r),
        radius: Radius.circular(r),
      )
      ..lineTo(0, r)
      ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _bubblePath(size);

    final fillTop = isDark
        ? const Color(0xFF2A3848).withValues(alpha: 0.97)
        : Colors.white;
    final fillBottom = isDark
        ? const Color(0xFF1E2A38).withValues(alpha: 0.95)
        : const Color(0xFFF7FCFA);
    final borderColor = isDark
        ? const Color(0xFF9AD4B6).withValues(alpha: 0.52)
        : const Color(0xFF8DD8B1).withValues(alpha: 0.72);
    final glowColor = _accentPastel.withValues(alpha: isDark ? 0.22 : 0.18);

    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: isDark ? 0.34 : 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.translate(0, 1.5);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillTop, fillBottom],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipPath(path);
    final shine = Rect.fromLTWH(0, 0, size.width, size.height * 0.42);
    canvas.drawRect(
      shine,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.10 : 0.55),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(shine),
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = borderColor,
    );

    final cx = size.width / 2;
    final tipY = size.height;
    canvas.drawCircle(
      Offset(cx, tipY),
      1.6,
      Paint()..color = _accentPastel.withValues(alpha: isDark ? 0.55 : 0.45),
    );
  }

  @override
  bool shouldRepaint(covariant _UnifiedSpeechBubblePainter oldDelegate) {
    return oldDelegate.isDark != isDark;
  }
}

class _MilestoneStone extends StatelessWidget {
  const _MilestoneStone({
    required this.isActive,
    required this.isDark,
    required this.hasAudio,
    required this.animDuration,
  });

  final bool isActive;
  final bool isDark;
  final bool hasAudio;
  final Duration animDuration;

  static const _accentPastel = Color(0xFF67C88F);

  @override
  Widget build(BuildContext context) {
    if (isActive) {
      return AnimatedScale(
        scale: _kActiveStoneScale,
        duration: animDuration,
        curve: Curves.easeOutCubic,
        child: Container(
          width: _kStoneSize,
          height: _kStoneSize,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF5DAF8A) : _accentPastel,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? const Color(0xFFB8E4CC).withValues(alpha: 0.7)
                  : const Color(0xFF8DD8B1).withValues(alpha: 0.75),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: (isDark ? _accentPastel : const Color(0xFF67C88F))
                    .withValues(alpha: 0.38),
                blurRadius: 8,
                spreadRadius: 0.4,
              ),
              BoxShadow(
                color: (isDark ? _accentPastel : const Color(0xFF67C88F))
                    .withValues(alpha: 0.14),
                blurRadius: 14,
                spreadRadius: 0.2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Container(
            width: 3.0,
            height: 3.0,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: _kStoneSize,
          height: _kStoneSize,
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
    );
  }
}

class _MilestoneConnector extends StatelessWidget {
  const _MilestoneConnector({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kConnectorWidth,
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
    );
  }
}

/// 스톤 행 중앙에 맞춘 연결선.
class _AlignedConnector extends StatelessWidget {
  const _AlignedConnector({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: (_kStoneRowHeight - 1.4) / 2),
      child: _MilestoneConnector(isDark: isDark),
    );
  }
}

/// 출발/도착 아이콘이 스톤 역할 — IATA는 옆, DEP/ARR은 하단.
class _RouteEndpointStoneColumn extends StatelessWidget {
  const _RouteEndpointStoneColumn({
    required this.iataCode,
    required this.tag,
    required this.isOrigin,
    required this.isDark,
  });

  final String iataCode;
  final String tag;
  final bool isOrigin;
  final bool isDark;

  static const _departureAccent = Color(0xFF67C88F);
  static const _arrivalAccent = Color(0xFF5C88FF);

  @override
  Widget build(BuildContext context) {
    final accent = isOrigin ? _departureAccent : _arrivalAccent;
    final icon = isOrigin
        ? Icons.flight_takeoff_rounded
        : Icons.flight_land_rounded;

    final iataStyle = TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.35,
      height: 1.0,
      color: isDark
          ? Colors.white.withValues(alpha: 0.88)
          : const Color(0xFF2A4058),
    );
    final tagStyle = TextStyle(
      fontSize: 7.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.1,
      height: 1.0,
      color: accent.withValues(alpha: isDark ? 0.82 : 0.78),
    );

    final iconStone = Container(
      width: _kEndpointIconSize,
      height: _kEndpointIconSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: isDark ? 0.42 : 0.28),
            accent.withValues(alpha: isDark ? 0.24 : 0.14),
          ],
        ),
        border: Border.all(
          color: accent.withValues(alpha: 0.62),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 12,
        color: isDark
            ? Colors.white.withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.98),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isOrigin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _kStoneRowHeight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: isOrigin
                ? [
                    Text(iataCode, style: iataStyle),
                    const SizedBox(width: _kEndpointIataGap),
                    iconStone,
                  ]
                : [
                    iconStone,
                    const SizedBox(width: _kEndpointIataGap),
                    Text(iataCode, style: iataStyle),
                  ],
          ),
        ),
        const SizedBox(height: _kEndpointTagGap),
        Text(
          tag,
          maxLines: 1,
          softWrap: false,
          textAlign: TextAlign.center,
          style: tagStyle,
        ),
      ],
    );
  }
}
