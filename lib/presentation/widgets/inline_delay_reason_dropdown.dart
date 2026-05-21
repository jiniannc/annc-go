import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';
import '../../data/models/delay_reason_model.dart';

/// Announcements·Situational 본문에 `{delay_reason}` 센티넬이 있을 때
/// 동일하게 쓰이는 인라인 지연사유 선택기.
class InlineDelayReasonDropdown extends StatelessWidget {
  const InlineDelayReasonDropdown({
    super.key,
    required this.reasons,
    required this.value,
    required this.delayReasonLabel,
    required this.onChanged,
    required this.textStyle,
  });

  final List<DelayReasonModel> reasons;
  final DelayReasonModel value;
  final String Function(DelayReasonModel r) delayReasonLabel;
  final ValueChanged<DelayReasonModel> onChanged;
  final TextStyle textStyle;

  static const double _menuHorizontalExtra = 36;

  double _measureLabelWidth(
    BuildContext context,
    String label,
    TextStyle style,
  ) {
    final tp = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return tp.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 본문과 구분되는 인라인 칩 — primary 소량 블렌드.
    final chipFill = Color.alphaBlend(
      cs.primary.withValues(alpha: isDark ? 0.24 : 0.14),
      cs.surfaceContainerHighest,
    );
    final iconColor = cs.onSurface.withValues(alpha: isDark ? 0.88 : 0.72);

    final menuStyle = textStyle.copyWith(fontWeight: FontWeight.w600);

    final labels = [for (final r in reasons) delayReasonLabel(r)];
    final widths = [
      for (final label in labels) _measureLabelWidth(context, label, menuStyle),
    ];
    final maxLabelW = widths.reduce(math.max);
    final selectedLabel = delayReasonLabel(value);
    final selectedW = _measureLabelWidth(context, selectedLabel, menuStyle);
    const iconAndInlinePadding = 40.0; // 아이콘 크기↑에 맞춰 닫힌 상태 필요 너비(텍스트+아이콘 간격).
    final closedBarW = selectedW + iconAndInlinePadding;

    final screenW = MediaQuery.sizeOf(context).width;
    final widthCap = math.max(
      120.0,
      screenW - UiConstants.pagePadding * 2 - 52,
    );

    final menuW = math.min(
      math.max(maxLabelW + _menuHorizontalExtra, closedBarW),
      widthCap,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chipFill,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.06),
                blurRadius: isDark ? 14 : 10,
                spreadRadius: isDark ? 0 : -0.5,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: const Color(
                  0xFF64748B,
                ).withValues(alpha: isDark ? 0.12 : 0.09),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Theme(
            data: Theme.of(
              context,
            ).copyWith(visualDensity: VisualDensity.compact),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widthCap),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<DelayReasonModel>(
                  value: value,
                  isDense: true,
                  isExpanded: false,
                  menuWidth: menuW,
                  padding: const EdgeInsetsDirectional.only(start: 8, end: 2),
                  borderRadius: BorderRadius.circular(10),
                  icon: Icon(
                    Icons.arrow_drop_down_rounded,
                    size: 26,
                    color: iconColor,
                  ),
                  style: menuStyle,
                  selectedItemBuilder: (ctx) {
                    return reasons.map((r) {
                      return Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(
                          width: selectedW,
                          child: Text(
                            delayReasonLabel(r),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  items: reasons.map((r) {
                    final label = delayReasonLabel(r);
                    return DropdownMenuItem<DelayReasonModel>(
                      value: r,
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (next) {
                    if (next != null) {
                      onChanged(next);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
