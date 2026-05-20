import 'package:flutter/material.dart';

/// 택1 「또는」 구간: 상단 스트립 규선과 동일한 두께(1.0)의 점선.
class PickOneOrDashedBridge extends StatelessWidget {
  const PickOneOrDashedBridge({
    super.key,
    required this.ruleColor,
    required this.label,
    required this.labelStyle,
  });

  final Color ruleColor;
  final String label;
  final TextStyle? labelStyle;

  static const double strokeWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _PickOneDashedRule(color: ruleColor),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(label, style: labelStyle),
          ),
          Expanded(
            child: _PickOneDashedRule(color: ruleColor),
          ),
        ],
      ),
    );
  }
}

class _PickOneDashedRule extends StatelessWidget {
  const _PickOneDashedRule({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, PickOneOrDashedBridge.strokeWidth),
          painter: _PickOneDashedRulePainter(
            color: color,
            strokeWidth: PickOneOrDashedBridge.strokeWidth,
          ),
        );
      },
    );
  }
}

class _PickOneDashedRulePainter extends CustomPainter {
  _PickOneDashedRulePainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const dashLen = 5.0;
    const gap = 4.0;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + dashLen).clamp(0.0, size.width);
      if (end > x) {
        canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      }
      x += dashLen + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _PickOneDashedRulePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
