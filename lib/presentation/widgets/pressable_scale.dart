import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// 눌렀을 때 살짝 줄어들었다가 spring으로 튕겨 돌아오는 통합 press 피드백.
///
/// iOS/visionOS 톤의 "탄성 있는" 마이크로 인터랙션을 앱 전체에 통일적으로
/// 적용하기 위한 래퍼. Ripple([InkWell])과 함께 쓰는 것도 가능하고, 단독
/// 사용도 가능하다.
///
/// - 누르는 동안: 110ms `easeOutCubic` 으로 [scaleDown] 까지 수축.
/// - 떼는 순간: [SpringSimulation] (stiffness 380 / damping 22) 으로 1.0으로
///   복귀하며 살짝 오버슈트. iOS 버튼의 "탁 튕김" 톤을 재현한다.
/// - 길게 눌렀을 때: [onLongPress] 호출 + [hapticOnLongPress].
///
/// [hapticOnTap] / [hapticOnLongPress] 기본값은 `null`. 호출부가 이미 햅틱을
/// 처리하는 경우(대다수의 dock/CTA 핸들러) 중복 햅틱을 피하기 위함.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.965,
    this.enabled = true,
    this.hapticOnTap,
    this.hapticOnLongPress,
    this.behavior = HitTestBehavior.opaque,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// 눌렸을 때의 최소 스케일. 기본 0.965 — 너무 작으면 카드 면적이 줄어들어
  /// 누르는 손가락이 가려진다는 인상을 줘서, 0.95 이하는 권장하지 않는다.
  final double scaleDown;

  /// `false` 면 인터랙션 비활성(시각 변화도 없고 콜백도 호출되지 않음).
  final bool enabled;

  /// 탭 직후 발생시킬 햅틱. `null` 이면 햅틱 없음.
  final HapticFeedbackType? hapticOnTap;

  /// 롱프레스 발화 시 햅틱. `null` 이면 햅틱 없음.
  final HapticFeedbackType? hapticOnLongPress;

  /// 자식 영역 밖에서 들어오는 포인터 처리 방식.
  final HitTestBehavior behavior;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

/// PressableScale 의 햅틱 변형. [HapticFeedback] 의 표준 4종을 enum 화.
enum HapticFeedbackType { selection, light, medium, heavy }

class _PressableScaleState extends State<PressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  /// 손 끝에서 "탁" 튀는 release 감각. mass·stiffness·damping 은 iOS
  /// system spring 기본값에 가깝게 조정.
  static const SpringDescription _releaseSpring = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 22.0,
  );

  static const Duration _pressDuration = Duration(milliseconds: 110);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled) {
      return;
    }
    _controller.animateTo(
      widget.scaleDown,
      duration: _pressDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _handleTapUp(TapUpDetails _) {
    _springBack();
  }

  void _handleTapCancel() {
    _springBack();
  }

  void _springBack() {
    if (!widget.enabled) {
      return;
    }
    _controller.animateWith(
      SpringSimulation(
        _releaseSpring,
        _controller.value,
        1.0,
        _controller.velocity,
      ),
    );
  }

  void _handleTap() {
    if (!widget.enabled) {
      return;
    }
    _fireHaptic(widget.hapticOnTap);
    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (!widget.enabled || widget.onLongPress == null) {
      return;
    }
    _fireHaptic(widget.hapticOnLongPress);
    widget.onLongPress!.call();
  }

  void _fireHaptic(HapticFeedbackType? type) {
    switch (type) {
      case HapticFeedbackType.selection:
        HapticFeedback.selectionClick();
      case HapticFeedbackType.light:
        HapticFeedback.lightImpact();
      case HapticFeedbackType.medium:
        HapticFeedback.mediumImpact();
      case HapticFeedbackType.heavy:
        HapticFeedback.heavyImpact();
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: widget.enabled ? _handleTapDown : null,
      onTapUp: widget.enabled ? _handleTapUp : null,
      onTapCancel: widget.enabled ? _handleTapCancel : null,
      onTap: widget.enabled && widget.onTap != null ? _handleTap : null,
      onLongPress: widget.enabled && widget.onLongPress != null
          ? _handleLongPress
          : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _controller.value,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
