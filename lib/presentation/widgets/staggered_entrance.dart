import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';

/// 리스트·그리드 항목의 첫 등장을 index 기준으로 살짝 지연(stagger)시키는
/// fade + slide-up 래퍼.
///
/// [index] × [delayPerItem] 만큼 늦게 시작해, 항목이 위에서 아래로 순차적으로
/// 나타나는 인상을 준다. [MediaQuery.disableAnimations] 가 켜져 있으면 즉시
/// [child] 만 표시한다.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
    this.delayPerItem = const Duration(milliseconds: 40),
    this.duration = UiConstants.softAnimation,
    this.slideOffset = 12.0,
    this.curve = Curves.easeOutCubic,
    this.maxStaggerIndex = 12,
  });

  final int index;
  final Widget child;

  /// 항목마다 추가되는 시작 지연.
  final Duration delayPerItem;

  /// fade/slide 애니메이션 길이.
  final Duration duration;

  /// 등장 시 아래에서 올라오는 Y 오프셋(px).
  final double slideOffset;

  final Curve curve;

  /// 지연 상한 index. 긴 리스트에서 마지막 항목 delay 가 과도해지지 않게 한다.
  final int maxStaggerIndex;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant StaggeredEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index ||
        oldWidget.duration != widget.duration ||
        oldWidget.slideOffset != widget.slideOffset ||
        oldWidget.curve != widget.curve) {
      _controller?.dispose();
      _controller = null;
      _opacity = null;
      _setupAnimation();
    }
  }

  void _setupAnimation() {
    final disableAnimations =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations;

    if (disableAnimations) {
      return;
    }

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(
      parent: _controller!,
      curve: widget.curve,
    );

    final delay = Duration(
      milliseconds:
          widget.index.clamp(0, widget.maxStaggerIndex) *
          widget.delayPerItem.inMilliseconds,
    );
    if (delay <= Duration.zero) {
      _controller!.forward();
    } else {
      Future<void>.delayed(delay, () {
        if (mounted && _controller != null) {
          _controller!.forward();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _opacity == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller!,
      builder: (context, child) {
        final t = _opacity!.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.slideOffset * (1 - t)),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
