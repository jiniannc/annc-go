import 'package:flutter/material.dart';

/// Announcements·Situational 시트 등 본문에서 `^`는 띄어읽기(숨 쉼) 시각 표시.
const String kPauseBreathCaretMarker = '^';

void appendPauseBreathSpans({
  required List<InlineSpan> out,
  required String text,
  required TextStyle style,
  bool keepWordBoundaryOnly = false,
}) {
  if (text.isEmpty) {
    return;
  }
  var start = 0;
  while (start < text.length) {
    final markerIndex = text.indexOf(kPauseBreathCaretMarker, start);
    if (markerIndex < 0) {
      final chunk = text.substring(start);
      if (chunk.isNotEmpty) {
        out.add(
          TextSpan(
            text: keepWordBoundaryOnly
                ? _preventMidWordWrap(chunk)
                : chunk,
            style: style,
          ),
        );
      }
      break;
    }
    if (markerIndex > start) {
      final chunk = text.substring(start, markerIndex);
      out.add(
        TextSpan(
          text: keepWordBoundaryOnly
              ? _preventMidWordWrap(chunk)
              : chunk,
          style: style,
        ),
      );
    }
    out.add(
      const WidgetSpan(
        alignment: PlaceholderAlignment.aboveBaseline,
        baseline: TextBaseline.alphabetic,
        child: PauseBreathMarker(),
      ),
    );
    start = markerIndex + kPauseBreathCaretMarker.length;
  }
}

List<InlineSpan> pauseBreathInlineSpans(
  String text,
  TextStyle style, {
  bool keepWordBoundaryOnly = false,
}) {
  if (text.isEmpty) {
    return const <InlineSpan>[];
  }
  final out = <InlineSpan>[];
  appendPauseBreathSpans(
    out: out,
    text: text,
    style: style,
    keepWordBoundaryOnly: keepWordBoundaryOnly,
  );
  return out;
}

String _preventMidWordWrap(String text) {
  if (text.isEmpty) {
    return text;
  }
  const wordJoiner = '\u2060';
  final out = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final current = text[i];
    out.write(current);
    if (i == text.length - 1) {
      continue;
    }
    final next = text[i + 1];
    if (_isWrapBoundary(current) || _isWrapBoundary(next)) {
      continue;
    }
    out.write(wordJoiner);
  }
  return '${out.toString()}\u200A';
}

bool _isWrapBoundary(String ch) {
  const breakChars =
      ' \n\r\t,.;:!?()[]{}<>"\'~`/\\|-_=+*&^%#@…·、。，．：；！？）】〉》」』’”‘“';
  if (breakChars.contains(ch)) {
    return true;
  }
  switch (ch) {
    case '\u200b':
    case '\u2060':
      return true;
    default:
      return false;
  }
}

class PauseBreathMarker extends StatelessWidget {
  const PauseBreathMarker({super.key});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFE53935);
    return Transform.translate(
      offset: const Offset(0, -8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: CustomPaint(
          size: const Size(11, 7),
          painter: ThickBreathCaretPainter(color: color),
        ),
      ),
    );
  }
}

class ThickBreathCaretPainter extends CustomPainter {
  const ThickBreathCaretPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(0.8, 1)
      ..lineTo(size.width / 2, size.height - 0.8)
      ..lineTo(size.width - 0.8, 1);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ThickBreathCaretPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
