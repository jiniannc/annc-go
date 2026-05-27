import 'package:flutter/material.dart';

/// 바텀시트 상단 잡아끌기 가로 막대.
class ModalSheetDragHandle extends StatelessWidget {
  const ModalSheetDragHandle({
    super.key,
    this.padding = const EdgeInsets.only(top: 10, bottom: 8),
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: padding,
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withValues(
              alpha: isDark ? 0.28 : 0.20,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
