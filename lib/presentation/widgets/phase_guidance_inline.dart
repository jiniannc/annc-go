import 'package:flutter/material.dart';

import '../providers/announcement_provider.dart';

/// Splits pipe-separated guidance values from a list of [TeleprompterScript]s
/// into a deduplicated list, in order of first occurrence.
/// CSV 한 칸에 `값1|값2` 처럼 파이프로 묶인 안내(타이밍, 비고 등)를 분리한다.
List<String> splitGuidanceList(String raw) {
  if (raw.trim().isEmpty) return const [];
  final out = <String>[];
  for (final part in raw.split('|')) {
    final t = part.trim();
    if (t.isEmpty) continue;
    if (!out.contains(t)) out.add(t);
  }
  return out;
}

List<String> collectGuidanceValues(
  List<TeleprompterScript> scripts,
  String Function(TeleprompterScript script) selector,
) {
  final values = <String>[];
  for (final script in scripts) {
    final raw = selector(script);
    if (raw.trim().isEmpty) {
      continue;
    }
    final items = raw
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty);
    for (final item in items) {
      if (!values.contains(item)) {
        values.add(item);
      }
    }
  }
  return values;
}

/// Inline guidance row showing announcer / timing / etc chips for a phase.
class PhaseGuidanceInline extends StatelessWidget {
  const PhaseGuidanceInline({
    super.key,
    required this.announcers,
    required this.timings,
    required this.etcNotes,
  });

  final List<String> announcers;
  final List<String> timings;
  final List<String> etcNotes;

  bool get isEmpty =>
      announcers.isEmpty && timings.isEmpty && etcNotes.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final value in announcers)
          GuidanceValuePill(
            icon: Icons.record_voice_over_rounded,
            value: value,
            tint: GuidanceTint.announcer,
          ),
        for (final value in timings)
          GuidanceValuePill(
            icon: Icons.schedule_rounded,
            value: value,
            tint: GuidanceTint.timing,
          ),
        for (final value in etcNotes)
          GuidanceValuePill(
            icon: Icons.lightbulb_outline_rounded,
            value: value,
            tint: GuidanceTint.etc,
          ),
      ],
    );
  }
}

enum GuidanceTint { announcer, timing, etc }

/// Announcer 캡슐 — [value] 텍스트에 따라 색 구분.
enum _AnnouncerCapsuleKind { purserRed, broadcastNavy, otherGreen }

_AnnouncerCapsuleKind _announcerCapsuleKind(String raw) {
  final t = raw.trim();
  if (t == '객실사무장') {
    return _AnnouncerCapsuleKind.purserRed;
  }
  if (t == '방송담당승무원') {
    return _AnnouncerCapsuleKind.broadcastNavy;
  }
  return _AnnouncerCapsuleKind.otherGreen;
}

class GuidanceValuePill extends StatelessWidget {
  const GuidanceValuePill({
    super.key,
    required this.icon,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String value;
  final GuidanceTint tint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (tint) {
      case GuidanceTint.announcer:
        return _buildAnnouncerCapsule(context, isDark);
      case GuidanceTint.timing:
        return _buildTimingTicket(context, isDark);
      case GuidanceTint.etc:
        return _buildEtcNote(context, isDark);
    }
  }

  /// Announcer — 역할별 그라데이션 (객실사무장=레드, 방송담당=네이비 유지, 그 외=그린).
  Widget _buildAnnouncerCapsule(BuildContext context, bool isDark) {
    final kind = _announcerCapsuleKind(value);
    late final Color start;
    late final Color end;
    switch (kind) {
      case _AnnouncerCapsuleKind.broadcastNavy:
        start = isDark ? const Color(0xFF3A5AA8) : const Color(0xFF3B6DD4);
        end = isDark ? const Color(0xFF2B4482) : const Color(0xFF1E4FB5);
      case _AnnouncerCapsuleKind.purserRed:
        start = isDark ? const Color(0xFF9B3D45) : const Color(0xFFE0505C);
        end = isDark ? const Color(0xFF6E252C) : const Color(0xFFB91C2E);
      case _AnnouncerCapsuleKind.otherGreen:
        start = isDark ? const Color(0xFF2A7A5E) : const Color(0xFF1FA971);
        end = isDark ? const Color(0xFF1A5844) : const Color(0xFF0F7A52);
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: end.withValues(alpha: 0.28),
            blurRadius: 8,
            spreadRadius: 0.2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.92)),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.05,
            ),
          ),
        ],
      ),
    );
  }

  /// Timing — ticket stub w/ dashed left edge + warm amber.
  Widget _buildTimingTicket(BuildContext context, bool isDark) {
    final bg = isDark ? const Color(0xFF3A2E14) : const Color(0xFFFFF4D9);
    final fg = isDark ? const Color(0xFFFFD489) : const Color(0xFF8A5A10);
    final stub = isDark ? const Color(0xFFFFB547) : const Color(0xFFF59E0B);
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: stub.withValues(alpha: 0.14),
            blurRadius: 6,
            spreadRadius: 0.1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: stub,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12.5, color: fg),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fg,
                    letterSpacing: -0.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Etc — "sticky note" feel with soft lavender + subtle tilt.
  Widget _buildEtcNote(BuildContext context, bool isDark) {
    final bg = isDark ? const Color(0xFF2B1F4A) : const Color(0xFFF3ECFF);
    final fg = isDark ? const Color(0xFFD4BDFF) : const Color(0xFF5A3D9F);
    final accent = isDark
        ? const Color(0xFF9D7BE8)
        : const Color(0xFFB197E8);
    return Transform.rotate(
      angle: -0.018,
      child: Container(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(3),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.18),
              blurRadius: 6,
              spreadRadius: 0.1,
              offset: const Offset(1, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12.5, color: fg),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 11.3,
                fontWeight: FontWeight.w700,
                color: fg,
                letterSpacing: -0.05,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
