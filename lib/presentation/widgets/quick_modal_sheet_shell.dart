import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/ui_constants.dart';

/// Situational 허브·터뷸런스·비상 등 동일 기하의 빠른 모달 셸.
///
/// 상단 [UiConstants.quickModalSheetTopReserveGap] 만큼은 탭 시 시트가 닫힌다.
/// 그 아래 [child]가 화면 하단까지 채우며, 드래그 핸들·모서리는 [child] 내부에서 맞춘다.
class QuickModalSheetShell extends StatelessWidget {
  const QuickModalSheetShell({
    super.key,
    required this.sheetContext,
    required this.child,
  });

  final BuildContext sheetContext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final reservedTop = topInset + UiConstants.quickModalSheetTopReserveGap;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: reservedTop,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(sheetContext).maybePop();
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: reservedTop,
          bottom: 0,
          child: child,
        ),
      ],
    );
  }
}
