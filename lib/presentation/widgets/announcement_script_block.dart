// ============================================================================
// Announcement script block — Announcements / Emergency 등 동일한 시트
// 스키마(Phase / Order / Title / Content_KO / Content_EN / Option / Condition_Tag
// / Inline_*) 를 그리는 공용 UI.
//
// 처음에는 `home_screen.dart` 안의 `_RoutineScriptBlock` / `_RoutineSelectPickOne
// Group` 와 친구들이었던 것을, EmergencyScreen 에서도 100% 동일한 UX 로 재사용
// 하기 위해 분리·public 화 한 모듈이다. 외부 노출 API:
//
//   - [AnnouncementScriptBlock]
//   - [AnnouncementSelectPickOneGroup]
//   - [AnnouncementPhaseSegment] / [AnnouncementPhaseSelectGroup] /
//     [AnnouncementPhaseSingle]
//   - [buildAnnouncementPhaseSegments]
//   - [buildAnnouncementSegmentWidget]
//   - [announcementScriptIsSelectPickCandidate]
//   - [KoEnMixedSegment], [buildEmergencyKoEnMixedSegments], [buildKoEnMixedSegmentRule]
//
// 내부 헬퍼 (인라인 sentinel 매핑, 변수 강조, 펑·숨쉬기, optional 배지 등)는
// 모두 private 으로 유지한다.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ui_constants.dart';
import '../../core/utils/emergency_required_title_icon.dart';
import '../../data/models/delay_reason_model.dart';
import '../../domain/services/announcement_formatter.dart';
import '../providers/announcement_provider.dart';
import '../providers/flight_setup_provider.dart';
import 'inline_delay_reason_dropdown.dart';
import 'pause_breath_inline.dart';
import 'pick_one_dashed_bridge.dart';

// ---------------------------------------------------------------------------
// Emergency: Content_KO 한 필드에 한글·영어가 연달아 붙은 문안 처리
// ---------------------------------------------------------------------------

/// 본문 `{{WAITING_REASON}}` 등 — 영어처럼 보이지만 한·영 전환 구분선 용도로는 무시한다.
final RegExp _koEnDetectIgnoreCurlyTokens =
    RegExp(r'\{\{[A-Za-z][A-Za-z0-9_]*\}\}');

/// 토큰 제거 후 남은 텍스트로만 한글/라틴 판별.
String _koEnDetectionCore(String line) =>
    line.replaceAll(_koEnDetectIgnoreCurlyTokens, '').trim();

bool _emergencyLineIsLatinPrefer(
  String line, {
  bool? preferLatinFallback,
}) {
  final core = _koEnDetectionCore(line);
  if (core.isEmpty) {
    return preferLatinFallback ?? false;
  }
  var lat = 0;
  var hang = 0;
  for (final r in core.runes) {
    final ch = String.fromCharCode(r);
    if (RegExp('[A-Za-z]').hasMatch(ch)) {
      lat++;
    } else if (RegExp(r'[\u3131-\u3163\uAC00-\uD7AF]').hasMatch(ch)) {
      hang++;
    }
  }
  if (lat >= 8 && hang == 0) return true;
  if (hang >= 4 && lat <= 3) return false;
  if (lat >= hang + 10) return true;
  if (hang >= lat + 4) return false;
  return preferLatinFallback ?? false;
}

/// 단일 `\n` 으로 이어진 연속 줄은 같은 조각으로 합치되, **중간에 빈 줄**(Enter 두 번 등)로
/// 끼면 조각을 끊고 이어 붙지만, 구분선(`needsDividerBefore`)은 **직전 줄과 문자 체계가
/// 바뀔 때**(한글↔라틴)에만 허용한다.
List<({String text, bool isLatin, bool needsDividerBefore})>
_emergencyLineRunsAlternate(String body) {
  final rawLines = body.split(RegExp(r'\r?\n'));
  final out = <({String text, bool isLatin, bool needsDividerBefore})>[];

  final buf = StringBuffer();
  bool? bufLatin;
  var pendingBlankLines = 0;
  var deferDividerBeforeNextEmit = false;

  void emitBuffered() {
    final raw = buf.toString().trimRight();
    buf.clear();
    final savedLatin = bufLatin;
    bufLatin = null;
    if (raw.isEmpty || savedLatin == null) return;

    final needsDividerBefore =
        deferDividerBeforeNextEmit && out.isNotEmpty;

    if (needsDividerBefore) {
      deferDividerBeforeNextEmit = false;
    }

    out.add((
      text: raw,
      isLatin: savedLatin,
      needsDividerBefore: needsDividerBefore,
    ));
  }

  for (final raw in rawLines) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      pendingBlankLines++;
      continue;
    }

    final lineLatin =
        _emergencyLineIsLatinPrefer(trimmed, preferLatinFallback: bufLatin);

    if (bufLatin != null &&
        buf.isNotEmpty &&
        (pendingBlankLines >= 1 || bufLatin != lineLatin)) {
      deferDividerBeforeNextEmit = bufLatin != lineLatin;
      emitBuffered();
      pendingBlankLines = 0;
    }

    if (buf.isEmpty) {
      bufLatin = lineLatin;
      buf.write(trimmed);
    } else {
      buf.writeln();
      buf.write(trimmed);
    }
  }

  if (buf.isNotEmpty && bufLatin != null) {
    emitBuffered();
  }

  return out;
}

List<String> _splitParagraphBlocksKeepEmpty(String trimmed) {
  final out = <String>[];
  final sep = RegExp(r'\r?\n\s*\r?\n');
  var start = 0;
  for (final m in sep.allMatches(trimmed)) {
    out.add(trimmed.substring(start, m.start));
    start = m.end;
  }
  out.add(trimmed.substring(start));
  return out;
}

/// 한·영 병기 본문에서 **언어 전환**(한글↔라틴) 구간 구분선(그라데이션 1줄 묶음).
Widget buildKoEnMixedSegmentRule({required bool isDark}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 11),
      Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 1),
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              UiConstants.navyMuted.withValues(
                alpha: isDark ? 0.22 : 0.17,
              ),
              Colors.transparent,
            ],
          ),
        ),
      ),
      const SizedBox(height: 11),
    ],
  );
}

/// 한 칸(Content_KO 등) 안의 KO/EN 혼합 세그먼트 + 앞쪽 구분선 개수.
///
/// [leadingStructuralDividers]: 바로 직전에 내보낸 조각과 문자 체계(한글/라틴)가 바뀌어
/// 새 조각이 시작할 때만 1(문단 안에서는 `needsDividerBefore`로도 동일하게 판별).
typedef KoEnMixedSegment = ({
  String text,
  bool isLatin,
  int leadingStructuralDividers,
});

/// 빈 줄(`\n\n`)로 나뉜 문단 + 줄 단위 교대로 KO/EN 조각 목록을 만든다.
List<KoEnMixedSegment>? buildEmergencyKoEnMixedSegments(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return null;

  final paragraphs = _splitParagraphBlocksKeepEmpty(trimmed);

  final pieces = <KoEnMixedSegment>[];
  var anyEmitted = false;

  for (final para in paragraphs) {
    final chunks = _emergencyLineRunsAlternate(para);
    for (final c in chunks) {
      if (c.text.trim().isEmpty) continue;

      var leadingStructuralDividers = 0;
      if (anyEmitted) {
        final scriptChange =
            pieces.isNotEmpty && pieces.last.isLatin != c.isLatin;
        if (c.needsDividerBefore || scriptChange) {
          leadingStructuralDividers = 1;
        }
      }

      pieces.add((
        text: c.text,
        isLatin: c.isLatin,
        leadingStructuralDividers: leadingStructuralDividers,
      ));

      anyEmitted = true;
    }
  }

  if (pieces.isEmpty) return null;

  final hasHangulPiece = pieces.any((e) => !e.isLatin);
  final hasLatinPiece = pieces.any((e) => e.isLatin);
  if (!hasHangulPiece || !hasLatinPiece) return null;

  return List<KoEnMixedSegment>.from(pieces);
}

// ---------------------------------------------------------------------------
// Phase 세그먼트: 연속 `select` 그룹을 한 묶음으로, 나머지를 단일로 분류.
// ---------------------------------------------------------------------------

/// CSV `Option = select` 행 중 hide-style 로 시작하는 것은 택1 그룹 후보.
bool announcementScriptIsSelectPickCandidate(TeleprompterScript s) =>
    s.isOptional && s.optionalStartsCollapsed && s.optionalIsSelect;

/// 한 Phase 안의 한 단위 세그먼트.
sealed class AnnouncementPhaseSegment {}

/// 연속된 `select` 행 묶음 → 택1 그룹 UI.
class AnnouncementPhaseSelectGroup extends AnnouncementPhaseSegment {
  AnnouncementPhaseSelectGroup(this.scripts);

  final List<TeleprompterScript> scripts;
}

/// 일반 단일 행.
class AnnouncementPhaseSingle extends AnnouncementPhaseSegment {
  AnnouncementPhaseSingle(this.script);

  final TeleprompterScript script;
}

/// `select` 가 연속으로 나오는 구간만 [AnnouncementPhaseSelectGroup] 으로 묶고,
/// 나머지는 [AnnouncementPhaseSingle] 로 흘려 보내는 정렬된 세그먼트 리스트.
List<AnnouncementPhaseSegment> buildAnnouncementPhaseSegments(
  List<TeleprompterScript> scripts,
) {
  final out = <AnnouncementPhaseSegment>[];
  var i = 0;
  while (i < scripts.length) {
    final s = scripts[i];
    if (announcementScriptIsSelectPickCandidate(s)) {
      final group = <TeleprompterScript>[];
      while (i < scripts.length &&
          announcementScriptIsSelectPickCandidate(scripts[i])) {
        group.add(scripts[i]);
        i++;
      }
      out.add(AnnouncementPhaseSelectGroup(group));
    } else {
      out.add(AnnouncementPhaseSingle(s));
      i++;
    }
  }
  return out;
}

/// 세그먼트 하나를 위젯으로 그린다.
///
/// home / emergency 양쪽에서 동일하게 호출되며, 세그먼트가 `select` 그룹이면
/// 그룹 컴포넌트, 단일이면 [AnnouncementScriptBlock] 으로 위임.
Widget buildAnnouncementSegmentWidget(
  AnnouncementPhaseSegment segment, {
  required bool showEnglish,
  required List<DelayReasonModel> delayReasons,
  required DelayReasonModel? selectedDelayReason,
  required List<String> specialFarewellLabels,
  required Map<String, int?> inlineSelectionByScript,
  required ValueChanged<DelayReasonModel> onDelayReasonChanged,
  required void Function(TeleprompterScript script, int index)
      onInlineOptionChangedForScript,
  required void Function(TeleprompterScript script, int index)
      onSpecialFarewellChangedForScript,
  required VoidCallback onTimeRefresh,
  bool presentTitleInRequired = false,
  Color? requiredTitleAccent,
  String? emergencyPhaseLabel,
}) {
  if (segment is AnnouncementPhaseSelectGroup) {
    final group = segment.scripts;
    if (group.length >= 2) {
      return AnnouncementSelectPickOneGroup(
        scripts: group,
        showEnglish: showEnglish,
        delayReasons: delayReasons,
        selectedDelayReason: selectedDelayReason,
        inlineSelectionByScript: inlineSelectionByScript,
        onDelayReasonChanged: onDelayReasonChanged,
        onInlineOptionChanged: onInlineOptionChangedForScript,
        specialFarewellLabels: specialFarewellLabels,
        onSpecialFarewellChanged: onSpecialFarewellChangedForScript,
        onTimeRefresh: onTimeRefresh,
        presentTitleInRequired: presentTitleInRequired,
        requiredTitleAccent: requiredTitleAccent,
        emergencyPhaseLabel: emergencyPhaseLabel,
      );
    }
    final single = group.single;
    return AnnouncementScriptBlock(
      script: single,
      showEnglish: showEnglish,
      delayReasons: delayReasons,
      selectedDelayReason: selectedDelayReason,
      inlineSelectedIndex:
          inlineSelectionByScript['${single.id}:${single.inlineKey}'],
      onDelayReasonChanged: onDelayReasonChanged,
      onInlineOptionChanged: (index) =>
          onInlineOptionChangedForScript(single, index),
      specialFarewellLabels: specialFarewellLabels,
      specialFarewellSelectedIndex:
          inlineSelectionByScript['${single.id}:special_farewell'],
      onSpecialFarewellChanged: (index) =>
          onSpecialFarewellChangedForScript(single, index),
      onTimeRefresh: onTimeRefresh,
      pickOneEmbedded: false,
      presentSelectAsRequired: true,
      presentTitleInRequired: presentTitleInRequired,
      requiredTitleAccent: requiredTitleAccent,
      emergencyPhaseLabel: emergencyPhaseLabel,
    );
  }
  final single = (segment as AnnouncementPhaseSingle).script;
  return AnnouncementScriptBlock(
    script: single,
    showEnglish: showEnglish,
    delayReasons: delayReasons,
    selectedDelayReason: selectedDelayReason,
    inlineSelectedIndex:
        inlineSelectionByScript['${single.id}:${single.inlineKey}'],
    onDelayReasonChanged: onDelayReasonChanged,
    onInlineOptionChanged: (index) =>
        onInlineOptionChangedForScript(single, index),
    specialFarewellLabels: specialFarewellLabels,
    specialFarewellSelectedIndex:
        inlineSelectionByScript['${single.id}:special_farewell'],
    onSpecialFarewellChanged: (index) =>
        onSpecialFarewellChangedForScript(single, index),
    onTimeRefresh: onTimeRefresh,
    pickOneEmbedded: false,
    presentTitleInRequired: presentTitleInRequired,
    requiredTitleAccent: requiredTitleAccent,
    emergencyPhaseLabel: emergencyPhaseLabel,
  );
}

// ---------------------------------------------------------------------------
// Select 택1 그룹 — 연속 select 행 묶음을 한 카드로.
// ---------------------------------------------------------------------------

/// CSV `select` 연속 구간을 택1 UI 로 묶어 보여주는 카드.
///
/// 단일 후보만 살아남으면 일반 optional 카드와 동일하게 그대로 그린다.
class AnnouncementSelectPickOneGroup extends StatefulWidget {
  const AnnouncementSelectPickOneGroup({
    super.key,
    required this.scripts,
    required this.showEnglish,
    required this.delayReasons,
    required this.selectedDelayReason,
    required this.inlineSelectionByScript,
    required this.onDelayReasonChanged,
    required this.onInlineOptionChanged,
    required this.specialFarewellLabels,
    required this.onSpecialFarewellChanged,
    required this.onTimeRefresh,
    this.presentTitleInRequired = false,
    this.requiredTitleAccent,
    this.emergencyPhaseLabel,
  });

  final List<TeleprompterScript> scripts;
  final bool showEnglish;
  final List<DelayReasonModel> delayReasons;
  final DelayReasonModel? selectedDelayReason;
  final Map<String, int?> inlineSelectionByScript;
  final ValueChanged<DelayReasonModel> onDelayReasonChanged;
  final void Function(TeleprompterScript script, int index)
      onInlineOptionChanged;
  final List<String> specialFarewellLabels;
  final void Function(TeleprompterScript script, int index)
      onSpecialFarewellChanged;
  final VoidCallback onTimeRefresh;

  /// Required(필수) 카드에서 Title 을 본문 위에 굵은 헤더로 표시한다.
  /// (Emergency 시트 한정 옵션 — Announcements 는 false 유지.)
  final bool presentTitleInRequired;
  final Color? requiredTitleAccent;
  final String? emergencyPhaseLabel;

  @override
  State<AnnouncementSelectPickOneGroup> createState() =>
      _AnnouncementSelectPickOneGroupState();
}

class _AnnouncementSelectPickOneGroupState
    extends State<AnnouncementSelectPickOneGroup> {
  String? _expandedScriptId;

  List<TeleprompterScript> _filteredScripts() {
    return widget.scripts.where((s) {
      final body = widget.showEnglish ? s.en : s.ko;
      return body.trim().isNotEmpty;
    }).toList();
  }

  static String? _firstTitledId(List<TeleprompterScript> scripts) {
    for (final s in scripts) {
      if (s.title.trim().isNotEmpty) {
        return s.id;
      }
    }
    return null;
  }

  void _syncExpandedToTitled(List<TeleprompterScript> filtered) {
    final titledIds = filtered
        .where((s) => s.title.trim().isNotEmpty)
        .map((s) => s.id)
        .toSet();
    if (titledIds.isEmpty) {
      _expandedScriptId = null;
      return;
    }
    if (_expandedScriptId == null || !titledIds.contains(_expandedScriptId)) {
      _expandedScriptId = _firstTitledId(filtered);
    }
  }

  @override
  void initState() {
    super.initState();
    _syncExpandedToTitled(_filteredScripts());
  }

  @override
  void didUpdateWidget(covariant AnnouncementSelectPickOneGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final f = _filteredScripts();
    if (f.isEmpty) {
      _expandedScriptId = null;
      return;
    }
    _syncExpandedToTitled(f);
  }

  void _onAccordionHeaderTap(String scriptId) {
    setState(() {
      if (_expandedScriptId == scriptId) {
        _expandedScriptId = null;
      } else {
        _expandedScriptId = scriptId;
      }
    });
  }

  /// 같은 택1 묶음에서 CSV 순서 기준 첫 번째 Title — 공통 Emergency 헤더.
  ///
  /// 본문이 비어 있어 [_filteredScripts] 에서 빠지는 "그룹 상단 제목" 행도 여기서는
  /// 포함한다. (그렇지 않으면 첫 select 행 Title(예: 기종명)이 헤더로 올라간다.)
  String _emergencyBannerTitle(List<TeleprompterScript> scripts) {
    for (final s in scripts) {
      final t = s.title.trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  TeleprompterScript _emergencyBannerScript(List<TeleprompterScript> scripts) {
    for (final s in scripts) {
      if (s.title.trim().isNotEmpty) return s;
    }
    return scripts.first;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredScripts();

    if (filtered.isEmpty) {
      return const SizedBox.shrink();
    }

    if (filtered.length == 1) {
      final single = filtered.single;
      return AnnouncementScriptBlock(
        script: single,
        showEnglish: widget.showEnglish,
        delayReasons: widget.delayReasons,
        selectedDelayReason: widget.selectedDelayReason,
        inlineSelectedIndex: widget
            .inlineSelectionByScript['${single.id}:${single.inlineKey}'],
        onDelayReasonChanged: widget.onDelayReasonChanged,
        onInlineOptionChanged: (index) =>
            widget.onInlineOptionChanged(single, index),
        specialFarewellLabels: widget.specialFarewellLabels,
        specialFarewellSelectedIndex:
            widget.inlineSelectionByScript['${single.id}:special_farewell'],
        onSpecialFarewellChanged: (index) =>
            widget.onSpecialFarewellChanged(single, index),
        onTimeRefresh: widget.onTimeRefresh,
        pickOneEmbedded: false,
        presentSelectAsRequired: true,
        presentTitleInRequired: widget.presentTitleInRequired,
        requiredTitleAccent: widget.requiredTitleAccent,
        emergencyPhaseLabel: widget.emergencyPhaseLabel,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final mainReadable = isDark
        ? onSurface.withValues(alpha: 0.96)
        : const Color(0xFF111111);

    final emergencyBoost =
        widget.emergencyPhaseLabel?.trim().isNotEmpty == true;

    final optionalFillMid = emergencyBoost
        ? Colors.transparent
        : (isDark
              ? Colors.white.withValues(alpha: 0.038)
              : UiConstants.navyInk.withValues(alpha: 0.038));
    final optionalRuleColor = emergencyBoost
        ? onSurface.withValues(alpha: isDark ? 0.26 : 0.22)
        : (isDark
              ? Colors.white.withValues(alpha: 0.09)
              : UiConstants.navyMuted.withValues(alpha: 0.14));

    final pickOneLabel = widget.showEnglish ? 'Pick 1' : '택 1';
    final bridgeLabel = widget.showEnglish ? 'or' : '또는';

    final badgeFill = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Color.alphaBlend(
            UiConstants.navyInk.withValues(alpha: 0.065),
            Colors.white.withValues(alpha: 0.97),
          );
    final badgeGradientTop = isDark
        ? const Color(0xFF232D3C)
        : UiConstants.warmSurface;
    final badgeGradientBottom = Color.alphaBlend(
      optionalFillMid,
      badgeFill,
    );

    final optionalFillEdge = optionalFillMid.withValues(alpha: 0);

    Widget pickOneBadge() {
      if (emergencyBoost) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(
              color: onSurface.withValues(alpha: isDark ? 0.38 : 0.3),
              width: 1.15,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Text(
              pickOneLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.06,
                height: 1.12,
                color: mainReadable.withValues(alpha: isDark ? 0.94 : 0.9),
              ),
            ),
          ),
        );
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              badgeGradientTop,
              badgeGradientBottom,
            ],
            stops: const [0.15, 1.0],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.12)
                  : UiConstants.navyInk.withValues(alpha: 0.038),
              blurRadius: 10,
              spreadRadius: -2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            pickOneLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.12,
                  height: 1.15,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.78)
                      : UiConstants.navyMuted.withValues(alpha: 0.92),
                ),
          ),
        ),
      );
    }

    final stripDecoration = emergencyBoost
        ? const BoxDecoration()
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                optionalFillEdge,
                optionalFillMid,
                optionalFillMid,
                optionalFillEdge,
              ],
              stops: const [0.0, 0.08, 0.92, 1.0],
            ),
            border: Border(
              top: BorderSide(color: optionalRuleColor),
              bottom: BorderSide(color: optionalRuleColor),
            ),
          );

    final bridgeLabelAlpha = emergencyBoost ? 0.74 : 0.48;

    final outerTopPad = emergencyBoost ? 4.0 : 13.0;
    final outerInnerPad =
        EdgeInsets.fromLTRB(0, emergencyBoost ? 10 : 14, 0, emergencyBoost ? 14 : 16);

    final bannerTitle = _emergencyBannerTitle(widget.scripts).trim();
    final useSharedEmergencyBanner = emergencyBoost &&
        widget.presentTitleInRequired &&
        bannerTitle.isNotEmpty;

    final pickOneStripBody = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < filtered.length; i++) ...[
          if (i > 0)
            PickOneOrDashedBridge(
              ruleColor: optionalRuleColor,
              label: bridgeLabel,
              labelStyle: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.06,
                    color: mainReadable.withValues(alpha: bridgeLabelAlpha),
                  ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 10),
                  child: _RoutinePickOneOrdinalOrb(
                    ordinal: i + 1,
                    isDark: isDark,
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final hasTitle =
                          filtered[i].title.trim().isNotEmpty;
                      return AnnouncementScriptBlock(
                        script: filtered[i],
                        showEnglish: widget.showEnglish,
                        delayReasons: widget.delayReasons,
                        selectedDelayReason:
                            widget.selectedDelayReason,
                        inlineSelectedIndex: widget
                                .inlineSelectionByScript[
                            '${filtered[i].id}:${filtered[i].inlineKey}'],
                        onDelayReasonChanged:
                            widget.onDelayReasonChanged,
                        onInlineOptionChanged: (index) =>
                            widget.onInlineOptionChanged(
                                filtered[i], index),
                        specialFarewellLabels:
                            widget.specialFarewellLabels,
                        specialFarewellSelectedIndex: widget
                                .inlineSelectionByScript[
                            '${filtered[i].id}:special_farewell'],
                        onSpecialFarewellChanged: (index) =>
                            widget.onSpecialFarewellChanged(
                                filtered[i], index),
                        onTimeRefresh: widget.onTimeRefresh,
                        pickOneEmbedded: true,
                        pickOneAccordionExpanded: hasTitle
                            ? filtered[i].id == _expandedScriptId
                            : true,
                        pickOneAccordionHeaderTap: hasTitle
                            ? () => _onAccordionHeaderTap(
                                  filtered[i].id,
                                )
                            : null,
                        presentTitleInRequired:
                            widget.presentTitleInRequired,
                        requiredTitleAccent:
                            widget.requiredTitleAccent,
                        emergencyPhaseLabel:
                            widget.emergencyPhaseLabel,
                        pickOneUsesSharedEmergencyBanner:
                            useSharedEmergencyBanner,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );

    if (useSharedEmergencyBanner) {
      final bannerScript = _emergencyBannerScript(widget.scripts);
      final accent = widget.requiredTitleAccent ?? _emergencyDefaultAccent;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _RequiredSectionTitleBar(
              title: bannerTitle,
              accent: accent,
              isDark: isDark,
              script: bannerScript,
              emergencyPhaseLabel: widget.emergencyPhaseLabel,
            ),
          ),
          const SizedBox(height: 6),
          Center(child: pickOneBadge()),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: stripDecoration,
            child: Padding(
              padding: outerInnerPad,
              child: pickOneStripBody,
            ),
          ),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: outerTopPad),
          child: DecoratedBox(
            decoration: stripDecoration,
            child: Padding(
              padding: outerInnerPad,
              child: pickOneStripBody,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 1,
          child: Center(child: pickOneBadge()),
        ),
      ],
    );
  }
}

class _RoutinePickOneOrdinalOrb extends StatelessWidget {
  const _RoutinePickOneOrdinalOrb({
    required this.ordinal,
    required this.isDark,
  });

  final int ordinal;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: 22,
      child: Text(
        '$ordinal.',
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontSize: 11.25,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: -0.02,
              color: ink.withValues(alpha: isDark ? 0.38 : 0.42),
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 본문 인라인 매핑 — `{opt_KEY}` / delay reason sentinel / special farewell
// sentinel / 항공편 번호 hint / 변수 강조까지.
// ---------------------------------------------------------------------------

StrutStyle _teleprompterStrutStyle(TextStyle bodyStyle) {
  return StrutStyle(
    fontSize: bodyStyle.fontSize,
    height: bodyStyle.height,
    fontWeight: bodyStyle.fontWeight,
    leadingDistribution: TextLeadingDistribution.even,
    fontStyle: bodyStyle.fontStyle,
  );
}

List<InlineSpan> _spansWithResolvedVariableEmphasis(
  String text,
  TextStyle base, {
  bool keepWordBoundaryOnly = false,
}) {
  const emphasisStart = AnnouncementFormatter.kVariableEmphasisStart;
  const emphasisEnd = AnnouncementFormatter.kVariableEmphasisEnd;
  const flightStart = AnnouncementFormatter.kInlineFlightNumberStart;
  const flightDivider = AnnouncementFormatter.kInlineFlightNumberDivider;
  const flightEnd = AnnouncementFormatter.kInlineFlightNumberEnd;

  final out = <InlineSpan>[];
  var i = 0;

  while (i < text.length) {
    final nextEmphasis = text.indexOf(emphasisStart, i);
    final nextFlight = text.indexOf(flightStart, i);
    final candidates =
        [nextEmphasis, nextFlight].where((v) => v >= 0).toList();
    if (candidates.isEmpty) {
      appendPauseBreathSpans(
        out: out,
        text: text.substring(i),
        style: base,
        keepWordBoundaryOnly: keepWordBoundaryOnly,
      );
      break;
    }
    final next = candidates.reduce(math.min);
    if (next > i) {
      appendPauseBreathSpans(
        out: out,
        text: text.substring(i, next),
        style: base,
        keepWordBoundaryOnly: keepWordBoundaryOnly,
      );
    }

    if (next == nextEmphasis) {
      final e = text.indexOf(emphasisEnd, next + emphasisStart.length);
      if (e < 0) {
        appendPauseBreathSpans(
          out: out,
          text: text.substring(next),
          style: base,
          keepWordBoundaryOnly: keepWordBoundaryOnly,
        );
        break;
      }
      appendPauseBreathSpans(
        out: out,
        text: text.substring(next + emphasisStart.length, e),
        style: base.copyWith(fontWeight: FontWeight.w700),
        keepWordBoundaryOnly: keepWordBoundaryOnly,
      );
      i = e + emphasisEnd.length;
      continue;
    }

    final d = text.indexOf(flightDivider, next + flightStart.length);
    final e = d < 0 ? -1 : text.indexOf(flightEnd, d + flightDivider.length);
    if (d < 0 || e < 0) {
      appendPauseBreathSpans(
        out: out,
        text: text.substring(next),
        style: base,
        keepWordBoundaryOnly: keepWordBoundaryOnly,
      );
      break;
    }
    final number = text.substring(next + flightStart.length, d);
    final pronunciation = text.substring(d + flightDivider.length, e);
    out.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: _InlineFlightNumberHint(
          number: number,
          pronunciation: pronunciation,
          baseStyle: base,
        ),
      ),
    );
    i = e + flightEnd.length;
  }
  return out;
}

class _InlineFlightNumberHint extends StatelessWidget {
  const _InlineFlightNumberHint({
    required this.number,
    required this.pronunciation,
    required this.baseStyle,
  });

  final String number;
  final String pronunciation;
  final TextStyle baseStyle;

  @override
  Widget build(BuildContext context) {
    final numberStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.normal,
      height: 1.0,
    );
    final pronunciationStyle = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 20) * 0.44,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.normal,
      height: 1.0,
      color: baseStyle.color?.withValues(alpha: 0.82),
      letterSpacing: 0.1,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        reverseDuration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.12),
            end: Offset.zero,
          ).animate(animation);
          final scale = Tween<double>(begin: 0.985, end: 1).animate(animation);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(scale: scale, child: child),
            ),
          );
        },
        child: Column(
          key: ValueKey('$number|$pronunciation'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(number, style: numberStyle),
            if (pronunciation.trim().isNotEmpty) ...[
              const SizedBox(height: 1),
              Text(pronunciation, style: pronunciationStyle),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineScriptOptionDropdown extends StatelessWidget {
  const _InlineScriptOptionDropdown({
    required this.labels,
    required this.selectedIndex,
    required this.textStyle,
    required this.onChanged,
  });

  final List<String> labels;
  final int selectedIndex;
  final TextStyle textStyle;
  final ValueChanged<int> onChanged;

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
    if (labels.isEmpty) {
      return Text('…', style: textStyle);
    }
    final menuStyle = textStyle.copyWith(fontWeight: FontWeight.w600);
    final widths = [
      for (final label in labels) _measureLabelWidth(context, label, menuStyle),
    ];
    final maxLabelW = widths.reduce(math.max);
    final safeIndex = selectedIndex.clamp(0, labels.length - 1);
    final selectedLabel = labels[safeIndex];
    final selectedW = _measureLabelWidth(context, selectedLabel, menuStyle);
    const iconAndInlinePadding = 30.0;
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
        child: Theme(
          data: Theme.of(
            context,
          ).copyWith(visualDensity: VisualDensity.compact),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widthCap),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: safeIndex,
                isDense: true,
                isExpanded: false,
                menuWidth: menuW,
                padding: const EdgeInsetsDirectional.only(start: 6, end: 0),
                borderRadius: BorderRadius.circular(10),
                icon: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: textStyle.color?.withValues(alpha: 0.85),
                ),
                style: menuStyle,
                selectedItemBuilder: (ctx) {
                  return List.generate(labels.length, (idx) {
                    return Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: selectedW,
                        child: Text(
                          labels[idx],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  });
                },
                items: List.generate(labels.length, (idx) {
                  return DropdownMenuItem<int>(
                    value: idx,
                    child: Text(
                      labels[idx],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
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
    );
  }
}

// ---------------------------------------------------------------------------
// Script block — 한 행(`TeleprompterScript`) 의 카드/본문 UI.
// ---------------------------------------------------------------------------

class AnnouncementScriptBlock extends ConsumerStatefulWidget {
  const AnnouncementScriptBlock({
    super.key,
    required this.script,
    required this.showEnglish,
    required this.delayReasons,
    required this.selectedDelayReason,
    required this.inlineSelectedIndex,
    required this.onDelayReasonChanged,
    required this.onInlineOptionChanged,
    required this.specialFarewellLabels,
    required this.specialFarewellSelectedIndex,
    required this.onSpecialFarewellChanged,
    required this.onTimeRefresh,
    this.pickOneEmbedded = false,
    this.pickOneAccordionExpanded = false,
    this.pickOneAccordionHeaderTap,
    this.presentSelectAsRequired = false,
    this.presentTitleInRequired = false,
    this.requiredTitleAccent,
    this.emergencyPhaseLabel,
    this.pickOneUsesSharedEmergencyBanner = false,
  });

  final TeleprompterScript script;
  final bool showEnglish;
  final List<DelayReasonModel> delayReasons;
  final DelayReasonModel? selectedDelayReason;
  final int? inlineSelectedIndex;
  final ValueChanged<DelayReasonModel> onDelayReasonChanged;
  final ValueChanged<int> onInlineOptionChanged;
  final List<String> specialFarewellLabels;
  final int? specialFarewellSelectedIndex;
  final ValueChanged<int> onSpecialFarewellChanged;
  final VoidCallback onTimeRefresh;

  /// 택1 그룹 내부 행: 상위에서 「택 1」을 보여 주므로 여기서는 배지를 겹쳐 쓰지 않음.
  final bool pickOneEmbedded;

  /// [pickOneAccordionHeaderTap]이 있으면 부모가 단일 펼침만 허용하는 모드.
  final bool pickOneAccordionExpanded;
  final VoidCallback? pickOneAccordionHeaderTap;

  /// 연속 select 가 한 줄뿐일 때: hide 스트립이 아닌 필수 문안 레이아웃.
  final bool presentSelectAsRequired;

  /// Required(필수) 카드에서 Title 을 본문 위에 굵은 헤더로 표시.
  ///
  /// Emergency 시트 한정으로 켜진다. (Announcements 는 false 유지하여 기존 UX
  /// 그대로.)
  final bool presentTitleInRequired;

  /// [presentTitleInRequired] 일 때 좌측 액센트 바·헤더 글자에 쓰일 색. null
  /// 이면 카테고리 기본(현재는 Emergency 빨강 톤)로 처리된다.
  final Color? requiredTitleAccent;

  /// Emergency Phase 라벨 (예: 비상착륙). 설정 시 Order 기반 헤더 아이콘.
  final String? emergencyPhaseLabel;

  /// Emergency 택1 다중 그룹: 부모가 첫 행 타이틀로 [_RequiredSectionTitleBar] 를 이미 그린 경우.
  /// 옵션 행에서는 동일 바를 반복하지 않고 간결한 제목 줄만 사용한다.
  final bool pickOneUsesSharedEmergencyBanner;

  @override
  ConsumerState<AnnouncementScriptBlock> createState() =>
      _AnnouncementScriptBlockState();
}

class _AnnouncementScriptBlockState
    extends ConsumerState<AnnouncementScriptBlock> {
  late bool _optionalExpanded;

  bool get _accordionControlled => widget.pickOneAccordionHeaderTap != null;

  bool get _effectiveOptionalExpanded =>
      _accordionControlled ? widget.pickOneAccordionExpanded : _optionalExpanded;

  @override
  void initState() {
    super.initState();
    _optionalExpanded = !widget.script.optionalStartsCollapsed;
  }

  @override
  void didUpdateWidget(covariant AnnouncementScriptBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_accordionControlled) {
      return;
    }
    if (oldWidget.script.id != widget.script.id ||
        oldWidget.script.optionalStartsCollapsed !=
            widget.script.optionalStartsCollapsed) {
      _optionalExpanded = !widget.script.optionalStartsCollapsed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final script = widget.script;
    final showEnglish = widget.showEnglish;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final mainReadable = isDark
        ? onSurface.withValues(alpha: 0.96)
        : const Color(0xFF111111);
    final secondaryReadable = isDark
        ? onSurface.withValues(alpha: 0.86)
        : const Color(0xFF262626);

    String formattedDelayReason(DelayReasonModel r, {required bool english}) {
      final raw = english ? r.reasonEn : r.reasonKo;
      if (raw.trim().isEmpty) {
        return r.id;
      }
      final setup = ref.watch(flightSetupProvider);
      if (setup == null) {
        return raw.trim();
      }
      final formatter = ref.watch(announcementFormatterProvider);
      return formatter.formatDelayReasonSnippet(
        template: raw,
        setup: setup,
        originAirport: ref.watch(originAirportProvider),
        destinationAirport: ref.watch(destinationAirportProvider),
        aircraft: ref.watch(currentAircraftProvider),
      );
    }

    // 선택 언어만 채워진 행 지원(KO 또는 EN 하나만 적은 시트). Emergency 는 기본 KO.
    late final String body;
    final koRaw = script.ko;
    final enRaw = script.en;
    if (showEnglish) {
      body =
          enRaw.trim().isNotEmpty ? enRaw : koRaw;
    } else {
      body =
          koRaw.trim().isNotEmpty ? koRaw : enRaw;
    }
    if (body.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final optionalLabel = showEnglish ? 'As needed' : '필요 시';

    // 한글 표시 모드: 본문이 한·영 혼합이면 분석 가능할 때만 Emergency 와 같은
    // 세그먼트 스타일을 쓴다. ( Etc 토큰 없이도 `buildEmergencyKoEnMixedSegments` 가
    // null 이 아니면 자동 적용 — 단락/줄 교대 규칙은 해당 함수와 동일.)
    final koEnMixedSegments =
        !showEnglish ? buildEmergencyKoEnMixedSegments(body) : null;

    final bodyStyleKo = TextStyle(
      fontSize: 20,
      height: 1.65,
      fontWeight: isDark ? FontWeight.w600 : FontWeight.w500,
      letterSpacing: -0.06,
      color: mainReadable,
      fontStyle: FontStyle.normal,
    );

    final enInk = isDark
        ? Color.lerp(mainReadable, const Color(0xFFC5D6F8), 0.32)!
            .withValues(alpha: 0.96)
        : const Color(0xFF1A3358).withValues(alpha: 0.94);

    final bodyStyleEn = TextStyle(
      fontSize: 20,
      height: 1.58,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.05,
      color: enInk,
      fontStyle: FontStyle.normal,
    );

    final bodyStyle = TextStyle(
      fontSize: 20,
      height: 1.65,
      fontWeight: showEnglish
          ? FontWeight.w500
          : (isDark ? FontWeight.w600 : FontWeight.w500),
      letterSpacing: showEnglish ? -0.28 : -0.06,
      color: showEnglish ? secondaryReadable : mainReadable,
      fontStyle: showEnglish ? FontStyle.italic : FontStyle.normal,
    );

    final Widget scriptWidget;
    if (koEnMixedSegments != null) {
      scriptWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final seg in koEnMixedSegments) ...[
            for (var d = 0; d < seg.leadingStructuralDividers; d++)
              buildKoEnMixedSegmentRule(isDark: isDark),
            _buildScriptBody(
              context,
              seg.text,
              seg.isLatin ? bodyStyleEn : bodyStyleKo,
              (r) => formattedDelayReason(r, english: seg.isLatin),
              keepWordBoundaryOnlyOverride:
                  !seg.isLatin,
              preferInlineEnglishLabels: seg.isLatin,
            ),
          ],
        ],
      );
    } else {
      scriptWidget = _buildScriptBody(
        context,
        body,
        bodyStyle,
        (r) => formattedDelayReason(r, english: showEnglish),
      );
    }

    final showTimeRefresh = script.hasTimeToken == true;

    final embeddedTitleTrim =
        widget.pickOneEmbedded ? script.title.trim() : '';
    if (widget.pickOneEmbedded &&
        embeddedTitleTrim.isEmpty &&
        script.isOptional &&
        !widget.presentSelectAsRequired) {
      if (!showTimeRefresh) {
        return scriptWidget;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: _timeRefreshAction(context),
          ),
          const SizedBox(height: 8),
          scriptWidget,
        ],
      );
    }

    final emergencyPhaseActive =
        widget.emergencyPhaseLabel?.trim().isNotEmpty == true;

    /// 택1 임베디드 + Emergency: 필요 시 배지 없이. 공통 헤더는 부모 또는 동일 바.
    if (widget.pickOneEmbedded &&
        emergencyPhaseActive &&
        script.optionalIsSelect &&
        script.isOptional &&
        !widget.presentSelectAsRequired) {
      final accent = widget.requiredTitleAccent ?? _emergencyDefaultAccent;
      final requiredTitleText = script.title.trim();
      final sharedBanner = widget.pickOneUsesSharedEmergencyBanner;

      final showGradientRequiredHeader =
          widget.presentTitleInRequired &&
              requiredTitleText.isNotEmpty &&
              !sharedBanner;

      void accordionTap() {
        HapticFeedback.selectionClick();
        if (_accordionControlled) {
          widget.pickOneAccordionHeaderTap!();
        } else {
          setState(() => _optionalExpanded = !_optionalExpanded);
        }
      }

      final accordionChevronColor =
          Theme.of(context).colorScheme.onSurface.withValues(
                alpha: isDark ? 0.82 : 0.76,
              );

      final Widget? gradientHeader = showGradientRequiredHeader
          ? _RequiredSectionTitleBar(
              title: requiredTitleText,
              accent: accent,
              isDark: isDark,
              script: script,
              emergencyPhaseLabel: widget.emergencyPhaseLabel,
              accordionMode: script.optionalStartsCollapsed,
              accordionExpanded: _effectiveOptionalExpanded,
              onAccordionTap:
                  script.optionalStartsCollapsed ? accordionTap : null,
              accordionChevronColor: accordionChevronColor,
            )
          : null;

      Widget? compactTitleBand;
      Widget? fallbackCollapsedTapStrip;

      if (sharedBanner) {
        final titleStyle = TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          height: 1.35,
          letterSpacing: showEnglish ? -0.28 : -0.06,
          color: mainReadable.withValues(alpha: isDark ? 0.92 : 0.88),
          fontStyle: showEnglish ? FontStyle.italic : FontStyle.normal,
        );
        if (script.optionalStartsCollapsed) {
          compactTitleBand = Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: accordionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        requiredTitleText.isNotEmpty
                            ? requiredTitleText
                            : (showEnglish
                                ? 'Tap to show script'
                                : '탭하여 방송문 보기'),
                        style: titleStyle.copyWith(
                          fontWeight: requiredTitleText.isNotEmpty
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize:
                              requiredTitleText.isNotEmpty ? 17 : 13.5,
                          fontStyle: requiredTitleText.isNotEmpty
                              ? titleStyle.fontStyle
                              : FontStyle.normal,
                          color: requiredTitleText.isNotEmpty
                              ? titleStyle.color
                              : onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _effectiveOptionalExpanded ? 0.5 : 0,
                      duration: UiConstants.softAnimation,
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 22,
                        color: accordionChevronColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else if (requiredTitleText.isNotEmpty) {
          compactTitleBand = Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(requiredTitleText, style: titleStyle),
          );
        }
      } else if (!showGradientRequiredHeader &&
          script.optionalStartsCollapsed) {
        fallbackCollapsedTapStrip = Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: accordionTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      showEnglish ? 'Tap to show script' : '탭하여 방송문 보기',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color:
                                Theme.of(context).colorScheme.onSurface.withValues(
                                      alpha: 0.54,
                                    ),
                          ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _effectiveOptionalExpanded ? 0.5 : 0,
                    duration: UiConstants.softAnimation,
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 22,
                      color: accordionChevronColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final Widget expansionBody = script.optionalStartsCollapsed
          ? AnimatedSize(
              duration: UiConstants.softAnimation,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _effectiveOptionalExpanded
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 9),
                        scriptWidget,
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 9),
                scriptWidget,
              ],
            );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (gradientHeader != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: gradientHeader,
            ),
          if (compactTitleBand != null) compactTitleBand,
          if (!sharedBanner && fallbackCollapsedTapStrip != null)
            fallbackCollapsedTapStrip,
          if (showTimeRefresh) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _timeRefreshAction(context),
            ),
            const SizedBox(height: 8),
          ],
          expansionBody,
        ],
      );
    }

    if (!script.isOptional || widget.presentSelectAsRequired) {
      final requiredTitleText = script.title.trim();
      final shouldShowRequiredTitle =
          widget.presentTitleInRequired && requiredTitleText.isNotEmpty;
      final accent = widget.requiredTitleAccent ?? _emergencyDefaultAccent;
      final requiredHeader = shouldShowRequiredTitle
          ? Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RequiredSectionTitleBar(
                title: requiredTitleText,
                accent: accent,
                isDark: isDark,
                script: script,
                emergencyPhaseLabel: widget.emergencyPhaseLabel,
              ),
            )
          : const SizedBox.shrink();

      if (!showTimeRefresh && !shouldShowRequiredTitle) {
        return scriptWidget;
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (shouldShowRequiredTitle) requiredHeader,
          if (showTimeRefresh) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _timeRefreshAction(context),
            ),
            const SizedBox(height: 8),
          ],
          scriptWidget,
        ],
      );
    }

    final titleText = script.title.trim();
    final emergencyBoost =
        widget.emergencyPhaseLabel?.trim().isNotEmpty == true;

    final optionalFillMid = emergencyBoost
        ? Colors.transparent
        : (isDark
              ? Colors.white.withValues(alpha: 0.038)
              : UiConstants.navyInk.withValues(alpha: 0.038));
    final optionalFillEdge = optionalFillMid.withValues(alpha: 0);
    final optionalRuleColor = emergencyBoost
        ? onSurface.withValues(alpha: isDark ? 0.26 : 0.22)
        : (isDark
              ? Colors.white.withValues(alpha: 0.09)
              : UiConstants.navyMuted.withValues(alpha: 0.14));

    final optLeadAlpha = emergencyBoost ? (isDark ? 0.78 : 0.72) : 0.38;
    final optTitleAlpha =
        emergencyBoost ? (isDark ? 0.92 : 0.88) : (isDark ? 0.62 : 0.52);
    final optPlaceholderAlpha =
        emergencyBoost ? (isDark ? 0.84 : 0.8) : 0.46;
    final optChevronAlpha =
        emergencyBoost ? (isDark ? 0.82 : 0.76) : 0.4;

    /// 배지가 카드 상단 규선에 걸치도록 카드를 아래로 내린 만큼 + 배지가 위로 살짝 나옴.
    final optionalCardTopInset = widget.pickOneEmbedded ? 0.0 : 13.0;
    const optionalBadgeTop = 1.0;

    final optShellOuterTop = emergencyBoost ? 4.0 : optionalCardTopInset;
    final optShellInnerPad = EdgeInsets.fromLTRB(
      emergencyBoost ? 10 : 0,
      emergencyBoost ? 12 : 14,
      emergencyBoost ? 10 : 0,
      emergencyBoost ? 14 : 16,
    );
    final emergencyTitleEndPad = emergencyBoost ? 88.0 : 0.0;

    final badgeFill = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Color.alphaBlend(
            UiConstants.navyInk.withValues(alpha: 0.065),
            Colors.white.withValues(alpha: 0.97),
          );
    final badgeGradientTop = isDark
        ? const Color(0xFF232D3C)
        : UiConstants.warmSurface;
    final badgeGradientBottom = Color.alphaBlend(
      optionalFillMid,
      badgeFill,
    );

    Widget optionalBadge() {
      if (emergencyBoost) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Text(
            optionalLabel,
            style: TextStyle(
              fontSize: 12.75,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.02,
              height: 1.1,
              color: onSurface.withValues(alpha: isDark ? 0.5 : 0.44),
            ),
          ),
        );
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              badgeGradientTop,
              badgeGradientBottom,
            ],
            stops: const [0.15, 1.0],
          ),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.08)
                  : UiConstants.navyInk.withValues(alpha: 0.028),
              blurRadius: 8,
              spreadRadius: -2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            optionalLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.06,
                  height: 1.15,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.62)
                      : UiConstants.navyMuted.withValues(alpha: 0.72),
                ),
          ),
        ),
      );
    }

    final optionalStripDecoration = emergencyBoost
        ? const BoxDecoration()
        : BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                optionalFillEdge,
                optionalFillMid,
                optionalFillMid,
                optionalFillEdge,
              ],
              stops: const [0.0, 0.08, 0.92, 1.0],
            ),
            border: Border(
              top: BorderSide(color: optionalRuleColor),
              bottom: BorderSide(color: optionalRuleColor),
            ),
          );

    final showOptionalHeader = titleText.isNotEmpty ||
        showTimeRefresh ||
        script.optionalStartsCollapsed;

    final TextStyle? optionalTitleStyle = emergencyBoost
        ? TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.35,
            letterSpacing: showEnglish ? -0.28 : -0.06,
            color: mainReadable.withValues(alpha: optTitleAlpha),
            fontStyle:
                showEnglish ? FontStyle.italic : FontStyle.normal,
          )
        : Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
              letterSpacing: -0.28,
              color: mainReadable.withValues(alpha: optTitleAlpha),
            );

    final TextStyle? optionalPlaceholderStyle = emergencyBoost
        ? TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: mainReadable.withValues(alpha: optPlaceholderAlpha),
          )
        : Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: mainReadable.withValues(alpha: optPlaceholderAlpha),
            );

    final headerRowCore = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((!widget.pickOneEmbedded || emergencyBoost) &&
            (titleText.isNotEmpty || script.optionalStartsCollapsed)) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _OptionalTitleLeadingIcon(
              useCollapsedCue: script.optionalStartsCollapsed,
              color: mainReadable.withValues(alpha: optLeadAlpha),
              emergencyPhaseLabel:
                  emergencyBoost ? widget.emergencyPhaseLabel : null,
              emergencyOrderForIcon:
                  emergencyBoost ? script.order : null,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (titleText.isNotEmpty)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: emergencyTitleEndPad),
              child: Text(
                titleText,
                style: optionalTitleStyle,
              ),
            ),
          )
        else if (script.optionalStartsCollapsed)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: emergencyTitleEndPad),
              child: Text(
                showEnglish ? 'Tap to show script' : '탭하여 방송문 보기',
                style: optionalPlaceholderStyle,
              ),
            ),
          )
        else
          const Spacer(),
        if (showTimeRefresh) ...[
          const SizedBox(width: 8),
          _timeRefreshAction(context),
        ],
        if (script.optionalStartsCollapsed) ...[
          const SizedBox(width: 2),
          AnimatedRotation(
            turns: _effectiveOptionalExpanded ? 0.5 : 0,
            duration: UiConstants.softAnimation,
            curve: Curves.easeOutCubic,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.expand_more_rounded,
                size: 22,
                color: mainReadable.withValues(alpha: optChevronAlpha),
              ),
            ),
          ),
        ],
      ],
    );

    final Widget headerRow = !showOptionalHeader
        ? const SizedBox.shrink()
        : script.optionalStartsCollapsed
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_accordionControlled) {
                      widget.pickOneAccordionHeaderTap!();
                    } else {
                      setState(() => _optionalExpanded = !_optionalExpanded);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: headerRowCore,
                  ),
                ),
              )
            : headerRowCore;

    final optionalInnerColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        headerRow,
        if (script.optionalStartsCollapsed)
          AnimatedSize(
            duration: UiConstants.softAnimation,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _effectiveOptionalExpanded
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 9),
                      scriptWidget,
                    ],
                  )
                : const SizedBox(width: double.infinity),
          )
        else ...[
          const SizedBox(height: 9),
          scriptWidget,
        ],
      ],
    );

    final Widget optionalShell = widget.pickOneEmbedded
        ? optionalInnerColumn
        : Padding(
            padding: EdgeInsets.only(top: optShellOuterTop),
            child: DecoratedBox(
              decoration: optionalStripDecoration,
              child: Padding(
                padding: optShellInnerPad,
                child: optionalInnerColumn,
              ),
            ),
          );

    Widget emergencyOptionalTopRightBadge(Widget child) {
      // 헤더 줄의 ▼ 카바와 겹치지 않게 위로 올리고, 접힘 시 우측 여백 확보.
      final topPad = optShellOuterTop + optShellInnerPad.top - 14;
      final baseRight = optShellInnerPad.right;
      final chevronClear =
          script.optionalStartsCollapsed ? 28.0 : 0.0;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: topPad,
            right: math.max(0.0, baseRight) + chevronClear,
            child: optionalBadge(),
          ),
        ],
      );
    }

    if (widget.pickOneEmbedded) {
      return optionalShell;
    }

    if (emergencyBoost) {
      return emergencyOptionalTopRightBadge(optionalShell);
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        optionalShell,
        Positioned(
          left: 0,
          right: 0,
          top: optionalBadgeTop,
          child: Center(child: optionalBadge()),
        ),
      ],
    );
  }

  Widget _timeRefreshAction(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        );
    return TextButton.icon(
      onPressed: widget.onTimeRefresh,
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: Text('시간 갱신', style: style),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _buildScriptBody(
    BuildContext context,
    String body,
    TextStyle bodyStyle,
    String Function(DelayReasonModel) delayReasonLabel, {
    bool? keepWordBoundaryOnlyOverride,
    bool preferInlineEnglishLabels = false,
  }) {
    const delaySentinel = AnnouncementFormatter.kInlineDelayReasonSentinel;
    const inlineSentinel = '\uE010';
    const specialFarewellSentinel =
        AnnouncementFormatter.kInlineSpecialFarewellSentinel;
    final keepWordBoundaryOnly =
        keepWordBoundaryOnlyOverride ?? !widget.showEnglish;
    final inlineToken = widget.script.inlineKey.trim().isEmpty
        ? ''
        : '{opt_${widget.script.inlineKey.trim()}}';
    final inlineLabels = () {
      final ko = widget.script.inlineItemsKo;
      final en = widget.script.inlineItemsEn;
      if (widget.showEnglish || preferInlineEnglishLabels) {
        return en.isNotEmpty ? en : ko;
      }
      return ko.isNotEmpty ? ko : en;
    }();
    final hasInline = inlineToken.isNotEmpty && inlineLabels.isNotEmpty;
    final withInline = hasInline
        ? body.replaceAll(inlineToken, inlineSentinel)
        : body;
    final workBody = withInline.replaceAll(specialFarewellSentinel, '\uE011');
    const specialFarewellInlineSentinel = '\uE011';

    if (!workBody.contains(delaySentinel) &&
        !workBody.contains(inlineSentinel) &&
        !workBody.contains(specialFarewellInlineSentinel)) {
      return Padding(
        padding: EdgeInsets.zero,
        child: Text.rich(
          TextSpan(
            children: [
              ..._spansWithResolvedVariableEmphasis(
                workBody,
                bodyStyle,
                keepWordBoundaryOnly: keepWordBoundaryOnly,
              ),
              const TextSpan(text: '\u200A'),
            ],
          ),
          strutStyle: _teleprompterStrutStyle(bodyStyle),
          overflow: TextOverflow.visible,
        ),
      );
    }

    DelayReasonModel? effectiveValue;
    if (widget.delayReasons.isNotEmpty) {
      effectiveValue = widget.selectedDelayReason != null &&
              widget.delayReasons.contains(widget.selectedDelayReason)
          ? widget.selectedDelayReason!
          : widget.delayReasons.first;
    }

    final spanChildren = <InlineSpan>[];
    var selectedInline =
        widget.inlineSelectedIndex ?? (widget.script.inlineDefaultIndex - 1);
    if (selectedInline < 0 || selectedInline >= inlineLabels.length) {
      selectedInline = 0;
    }
    var selectedSpecialFarewell = widget.specialFarewellSelectedIndex ?? 0;
    if (selectedSpecialFarewell < 0 ||
        selectedSpecialFarewell >= widget.specialFarewellLabels.length) {
      selectedSpecialFarewell = 0;
    }
    var cursor = 0;

    while (cursor < workBody.length) {
      final nextDelay = workBody.indexOf(delaySentinel, cursor);
      final nextInline = workBody.indexOf(inlineSentinel, cursor);
      final nextSpecialFarewell = workBody.indexOf(
        specialFarewellInlineSentinel,
        cursor,
      );
      final candidates = [
        nextDelay,
        nextInline,
        nextSpecialFarewell,
      ].where((v) => v >= 0).toList();
      if (candidates.isEmpty) {
        final rest = workBody.substring(cursor);
        if (rest.isNotEmpty) {
          spanChildren.addAll(
            _spansWithResolvedVariableEmphasis(
              rest,
              bodyStyle,
              keepWordBoundaryOnly: keepWordBoundaryOnly,
            ),
          );
        }
        break;
      }
      final next = candidates.reduce(math.min);
      if (next > cursor) {
        final chunk = workBody.substring(cursor, next);
        spanChildren.addAll(
          _spansWithResolvedVariableEmphasis(
            chunk,
            bodyStyle,
            keepWordBoundaryOnly: keepWordBoundaryOnly,
          ),
        );
      }
      if (next == nextDelay) {
        spanChildren.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: widget.delayReasons.isNotEmpty && effectiveValue != null
                ? InlineDelayReasonDropdown(
                    reasons: widget.delayReasons,
                    value: effectiveValue,
                    delayReasonLabel: delayReasonLabel,
                    onChanged: widget.onDelayReasonChanged,
                    textStyle: bodyStyle,
                  )
                : Text('…', style: bodyStyle),
          ),
        );
        cursor = next + delaySentinel.length;
      } else if (next == nextInline) {
        spanChildren.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _InlineScriptOptionDropdown(
              labels: inlineLabels,
              selectedIndex: selectedInline,
              textStyle: bodyStyle,
              onChanged: widget.onInlineOptionChanged,
            ),
          ),
        );
        cursor = next + inlineSentinel.length;
      } else {
        spanChildren.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: widget.specialFarewellLabels.isNotEmpty
                ? _InlineScriptOptionDropdown(
                    labels: widget.specialFarewellLabels,
                    selectedIndex: selectedSpecialFarewell,
                    textStyle: bodyStyle,
                    onChanged: widget.onSpecialFarewellChanged,
                  )
                : Text('', style: bodyStyle),
          ),
        );
        cursor = next + specialFarewellInlineSentinel.length;
      }
    }

    return Padding(
      padding: EdgeInsets.zero,
      child: Text.rich(
        TextSpan(
          children: [
            ...spanChildren,
            const TextSpan(text: '\u200A'),
          ],
        ),
        strutStyle: _teleprompterStrutStyle(bodyStyle),
        overflow: TextOverflow.visible,
      ),
    );
  }
}

/// 필요 시 카드 타이틀 왼쪽: 일반 optional 은 info, 접힘(hide) 은 unfold.
/// Emergency 페이즈가 지정되어 있으면 CSV Order 기준 [emergencyRequiredTitleIcon] 우선.
class _OptionalTitleLeadingIcon extends StatelessWidget {
  const _OptionalTitleLeadingIcon({
    required this.useCollapsedCue,
    required this.color,
    this.emergencyPhaseLabel,
    this.emergencyOrderForIcon,
  });

  final bool useCollapsedCue;
  final Color color;
  final String? emergencyPhaseLabel;
  final int? emergencyOrderForIcon;

  @override
  Widget build(BuildContext context) {
    final phase = emergencyPhaseLabel?.trim() ?? '';
    if (phase.isNotEmpty && emergencyOrderForIcon != null) {
      return Icon(
        emergencyRequiredTitleIcon(phase, emergencyOrderForIcon!),
        size: 20,
        color: color,
      );
    }
    return Icon(
      useCollapsedCue
          ? Icons.unfold_more_rounded
          : Icons.info_outline_rounded,
      size: 18,
      color: color,
    );
  }
}

/// Emergency 전용 필수 구간 헤더 — 전폭 소프트 그라데이션 + Order 기반 아이콘.
///
/// `presentTitleInRequired: true` 일 때만 쓰이며 현재 호출처는 Emergency 뿐이다.
class _RequiredSectionTitleBar extends StatelessWidget {
  const _RequiredSectionTitleBar({
    required this.title,
    required this.accent,
    required this.isDark,
    required this.script,
    this.emergencyPhaseLabel,
    this.accordionMode = false,
    this.accordionExpanded = false,
    this.onAccordionTap,
    this.accordionChevronColor,
  });

  final String title;
  final Color accent;
  final bool isDark;
  final TeleprompterScript script;
  final String? emergencyPhaseLabel;

  /// 택1 접힘 행: 헤더 바 전체를 탭 타겟으로 쓰고 우측에 ▼ 회전.
  final bool accordionMode;
  final bool accordionExpanded;
  final VoidCallback? onAccordionTap;
  final Color? accordionChevronColor;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final phase = emergencyPhaseLabel?.trim() ?? '';
    final headerIcon = phase.isNotEmpty
        ? emergencyRequiredTitleIcon(phase, script.order)
        : Icons.campaign_rounded;
    final demoBadge = scriptEtcShowsDemoBadge(script.etcNote);
    final hasAccordion =
        accordionMode && onAccordionTap != null;
    final chevronInk = accordionChevronColor ??
        ink.withValues(alpha: isDark ? 0.78 : 0.72);

    final Widget bar = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.34 : 0.22),
              isDark ? const Color(0xFF16191E) : const Color(0xFFFFFBFB),
            ),
            Color.alphaBlend(
              accent.withValues(alpha: isDark ? 0.12 : 0.06),
              isDark ? const Color(0xFF121418) : Colors.white,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.14 : 0.09),
            blurRadius: 18,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  Color.alphaBlend(
                    Colors.black.withValues(alpha: 0.12),
                    accent,
                  ),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Icon(
                headerIcon,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.22,
                      letterSpacing: -0.22,
                      color: ink.withValues(alpha: isDark ? 0.96 : 0.91),
                    ),
                  ),
                ),
                if (demoBadge)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, top: 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            accent.withValues(alpha: isDark ? 0.38 : 0.2),
                            accent.withValues(alpha: isDark ? 0.22 : 0.11),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          '시연 필요',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.05,
                            color: Colors.white.withValues(alpha: 0.96),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasAccordion) ...[
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: accordionExpanded ? 0.5 : 0,
              duration: UiConstants.softAnimation,
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.expand_more_rounded,
                size: 22,
                color: chevronInk,
              ),
            ),
          ],
        ],
      ),
    );

    if (hasAccordion) {
      return Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAccordionTap,
          child: bar,
        ),
      );
    }
    return bar;
  }
}

/// [_RequiredSectionTitleBar] 의 기본 accent — 호출부가 색을 명시하지 않을 때
/// fallback. Emergency 가 가장 일반적인 호출처라 빨강 톤으로 둔다.
const Color _emergencyDefaultAccent = Color(0xFFD93540);
