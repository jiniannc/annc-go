import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ui_constants.dart';
import '../../data/models/delay_reason_model.dart';
import '../../domain/entities/situational_script.dart';
import '../../domain/services/announcement_formatter.dart';
import '../providers/announcement_provider.dart';
import '../providers/flight_setup_provider.dart';
import '../providers/situational_provider.dart';
import 'inline_delay_reason_dropdown.dart';
import 'announcement_script_block.dart'
    show
        buildEmergencyKoEnMixedSegments,
        buildKoEnMixedSegmentRule,
        KoEnMixedSegment;
import 'liquid_glass_card.dart';
import 'pause_breath_inline.dart';
import 'phase_guidance_inline.dart';

/// 짙은 `situationalNavy` 는 다크 배경에서 대비가 사라짐 — 인라인 토큰/칩 전용.
Color _situationalReadableAccent(BuildContext context, Color base) {
  if (Theme.of(context).brightness != Brightness.dark) return base;
  return const Color(0xFFB4C8F0);
}

Color _situationalLinkRowPrimary(BuildContext context, Color base) {
  if (Theme.of(context).brightness != Brightness.dark) {
    return base.withValues(alpha: 0.82);
  }
  return const Color(0xFFE8EDF7);
}

Color _situationalLinkRowMuted(BuildContext context, Color base) {
  if (Theme.of(context).brightness != Brightness.dark) {
    return base.withValues(alpha: 0.5);
  }
  return const Color(0xFFA2B4D4);
}

/// [SituationalScript.linkTarget] 을 `|` 로 쪼갠 뒤 각 조각을 해석한 결과(허브가 채움).
class SituationalResolvedLink {
  const SituationalResolvedLink({
    required this.raw,
    this.target,
    this.missing = false,
    this.onNavigate,
  });

  final String raw;
  final SituationalScript? target;
  final bool missing;
  final VoidCallback? onNavigate;
}

/// Scenario 한 건을 보여주는 카드.
///
/// 디자인 원칙(홈 메인 화면과 일관성을 맞춘다):
/// - 카드 컨테이너는 홈의 [LiquidGlassCard] 를 그대로 차용한다(부드러운
///   gradient + blur + 그림자 + 라운드). 컬러팔레트만 카테고리 accent로 살짝
///   tint해서 situational 임을 표현한다.
/// - 한 Scenario는 "하나의 스크립트"로 읽혀야 한다. 섹션마다 박스를 쪼개지
///   않고 본문 안에 단락으로 자연스럽게 이어 붙인다.
/// - 옵션 토큰은 본문 안의 `인라인 드롭다운`으로 노출한다. 옵션이 적으면
///   Material `DropdownButton`, 많거나 SubGroup 으로 분류된 경우엔 바텀시트
///   피커로 자연스럽게 전환한다.
/// - "필요시" 섹션만 announcement 의 [필요시] 박스 패턴을 차용한다.
class SituationalScriptCard extends ConsumerStatefulWidget {
  const SituationalScriptCard({
    super.key,
    required this.script,
    required this.accentColor,
    this.subCategoryStripeColor,
    required this.isExpanded,
    required this.onExpansionChanged,
    this.linkResolutions = const [],
    this.onBackFromLink,
    this.backFromLinkTooltip,
  });

  final SituationalScript script;
  final Color accentColor;

  /// 서브카테고리별 좌측 세로줄 색. null이면 [accentColor]와 동일 톤으로 그린다.
  final Color? subCategoryStripeColor;

  /// true 인 시나리오만 본문이 펼쳐진다(부모가 아코디언으로 제어).
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;

  /// `Link` 컬럼을 `|` 로 나눈 각 대상의 해석·이동 콜백.
  final List<SituationalResolvedLink> linkResolutions;

  /// 링크 이동 후 스택이 쌓여 있을 때(허브), 문안·링크 사이 «돌아가기».
  final VoidCallback? onBackFromLink;

  /// [onBackFromLink] 툴팁(예: 이전 시나리오 제목).
  final String? backFromLinkTooltip;

  @override
  ConsumerState<SituationalScriptCard> createState() =>
      _SituationalScriptCardState();
}

class _SituationalScriptCardState extends ConsumerState<SituationalScriptCard> {
  bool _showEnglish = false;

  /// 섹션 · 그룹별 현재 선택된 옵션. key = "${sectionIndex}::${groupId}"
  final Map<String, SituationalOption> _selected = {};

  /// Optional 섹션의 포함 여부. 기본값: 미포함.
  final Map<int, bool> _includeOptional = {};

  SituationalScript get script => widget.script;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favorites = ref.watch(situationalFavoritesProvider);
    final isFav = favorites.contains(script.id);
    final accent = widget.accentColor;
    final stripe = widget.subCategoryStripeColor ?? accent;
    final washColor = widget.subCategoryStripeColor ?? accent;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final hasContent = script.hasAnyContent;
    final timingGuides = splitGuidanceList(script.timing);
    final etcGuides = splitGuidanceList(script.etcNote);
    final hasGuidance = timingGuides.isNotEmpty || etcGuides.isNotEmpty;
    final headerBottomFlat = widget.isExpanded && hasContent;

    // LiquidGlassCard 자체로 컨테이너를 만들고, 카테고리 accent를 살짝 띤
    // 좌측 stripe로 situational 임을 표현한다(컬러팔레트만 트위스트).
    const cardRadius = 18.0;
    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: cardRadius,
      child: Stack(
        children: [
          // 서브카테고리별 카드 전체를 아주 옅게 틴트(그룹 구분).
          if (widget.subCategoryStripeColor != null)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cardRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        stripe.withValues(alpha: isDark ? 0.10 : 0.068),
                        stripe.withValues(alpha: isDark ? 0.048 : 0.034),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // 펼침 시 추가로 살짝 깊어지는 틴트.
          if (widget.isExpanded)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(cardRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        washColor.withValues(alpha: isDark ? 0.09 : 0.055),
                        washColor.withValues(alpha: isDark ? 0.05 : 0.038),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // 좌측 wash — 서브가 있으면 서브 색, 없으면 카테고리 accent.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(cardRadius),
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      washColor.withValues(alpha: isDark ? 0.085 : 0.056),
                      washColor.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.45],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: hasContent
                    ? () {
                        HapticFeedback.selectionClick();
                        widget.onExpansionChanged(!widget.isExpanded);
                      }
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(cardRadius),
                  topRight: const Radius.circular(cardRadius),
                  bottomLeft: headerBottomFlat
                      ? Radius.zero
                      : const Radius.circular(cardRadius),
                  bottomRight: headerBottomFlat
                      ? Radius.zero
                      : const Radius.circular(cardRadius),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    9,
                    6,
                    headerBottomFlat ? 6 : 10,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 3,
                        height: 30,
                        decoration: BoxDecoration(
                          color: stripe.withValues(alpha: isDark ? 0.58 : 0.52),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ScenarioHeaderTitle(
                          title: script.displayTitle,
                          onSurface: onSurface,
                        ),
                      ),
                      IconButton(
                        tooltip: isFav ? '즐겨찾기 해제' : '즐겨찾기',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        iconSize: 22,
                        icon: Icon(
                          isFav
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isFav
                              ? Colors.amber.shade600
                              : onSurface.withValues(alpha: 0.7),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(situationalFavoritesProvider.notifier)
                              .toggle(script.id);
                        },
                      ),
                      if (hasContent)
                        Icon(
                          widget.isExpanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 22,
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                    ],
                  ),
                ),
              ),
              AnimatedCrossFade(
                duration: UiConstants.softAnimation,
                crossFadeState: widget.isExpanded && hasContent
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasGuidance) ...[
                        PhaseGuidanceInline(
                          announcers: const [],
                          timings: timingGuides,
                          etcNotes: etcGuides,
                        ),
                        const SizedBox(height: 6),
                      ],
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (!_showEnglish &&
                              !script
                                  .hasRenderableContentEnForKoAlignedSections(
                                    _includeOptional,
                                  )) {
                            return;
                          }
                          HapticFeedback.selectionClick();
                          setState(() => _showEnglish = !_showEnglish);
                        },
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: double.infinity,
                            minHeight: 88,
                          ),
                          child: _ScriptBody(
                            script: script,
                            showEnglish: _showEnglish,
                            accent: accent,
                            selected: _selected,
                            includeOptional: _includeOptional,
                            onSelect: (sectionIndex, groupId, opt) {
                              setState(() {
                                _selected['$sectionIndex::$groupId'] = opt;
                              });
                            },
                            onIncludeOptional: (sectionIndex, value) {
                              setState(() {
                                _includeOptional[sectionIndex] = value;
                              });
                            },
                          ),
                        ),
                      ),
                      if (widget.onBackFromLink != null ||
                          widget.linkResolutions.isNotEmpty)
                        _SituationalLinkZone(
                          onBack: widget.onBackFromLink,
                          backTooltip: widget.backFromLinkTooltip,
                          links: widget.linkResolutions,
                          accent: accent,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// «이어서 보기» 한 블록: 돌아가기(있을 때) + 링크 — 동일 행 높이·톤.
class _SituationalLinkZone extends StatefulWidget {
  const _SituationalLinkZone({
    this.onBack,
    this.backTooltip,
    required this.links,
    required this.accent,
  });

  final VoidCallback? onBack;
  final String? backTooltip;
  final List<SituationalResolvedLink> links;
  final Color accent;

  @override
  State<_SituationalLinkZone> createState() => _SituationalLinkZoneState();
}

class _SituationalLinkZoneState extends State<_SituationalLinkZone>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    _syncPulseWithOnBack();
  }

  @override
  void didUpdateWidget(covariant _SituationalLinkZone oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onBack != widget.onBack) {
      _syncPulseWithOnBack();
    }
  }

  void _syncPulseWithOnBack() {
    if (widget.onBack != null) {
      _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1100),
      )..repeat(reverse: true);
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = widget.accent;
    final primary = _situationalLinkRowPrimary(context, accent);
    final secondary = _situationalLinkRowMuted(context, accent);
    final hasBack = widget.onBack != null;
    final links = widget.links;
    if (!hasBack && links.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '이어서 보기',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: secondary,
              letterSpacing: 1.15,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Divider(
            height: 1,
            thickness: 0.5,
            color: onSurface.withValues(alpha: isDark ? 0.14 : 0.12),
          ),
          if (hasBack) _buildBackRow(context),
          if (hasBack && links.isNotEmpty)
            Divider(
              height: 0.5,
              indent: 20,
              thickness: 0.5,
              color: onSurface.withValues(alpha: 0.08),
            ),
          for (var i = 0; i < links.length; i++) ...[
            if (i > 0)
              Divider(
                height: 0.5,
                indent: 20,
                thickness: 0.5,
                color: onSurface.withValues(alpha: 0.08),
              ),
            _SituationalLinkLine(
              item: links[i],
              linkInk: primary,
              linkSub: secondary,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBackRow(BuildContext context) {
    final c = _pulse;
    if (c == null) {
      return const SizedBox.shrink();
    }
    final accent = widget.accent;
    final secondary = _situationalLinkRowMuted(context, accent);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final o = UiConstants.situationalOrange;
    // 링크 줄(secondary)과 동일 정렬·패딩, 색만 오렌지를 낮게 섞어 구분.
    final backInk = Color.lerp(secondary, o, isDark ? 0.58 : 0.44)!;
    final backIcon = Color.lerp(secondary, o, isDark ? 0.52 : 0.40)!;

    final row = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onBack!();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 0.5),
                child: AnimatedBuilder(
                  animation: c,
                  builder: (context, child) {
                    final ph = c.value * math.pi * 2;
                    final slide = math.sin(ph) * 2.0;
                    final glow = 0.78 + 0.22 * (0.5 + 0.5 * math.sin(ph));
                    return Transform.translate(
                      offset: Offset(slide, 0),
                      child: Opacity(opacity: glow, child: child),
                    );
                  },
                  child: Icon(Icons.west_rounded, size: 15, color: backIcon),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '돌아가기',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                    color: backInk,
                    letterSpacing: -0.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final tip = widget.backTooltip;
    if (tip != null && tip.isNotEmpty) {
      return Tooltip(message: tip, child: row);
    }
    return row;
  }
}

class _SituationalLinkLine extends StatelessWidget {
  const _SituationalLinkLine({
    required this.item,
    required this.linkInk,
    required this.linkSub,
  });

  final SituationalResolvedLink item;
  final Color linkInk;
  final Color linkSub;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = item.target;
    final title = (t != null && t.scenario.isNotEmpty) ? t.scenario : item.raw;
    final canTap = !item.missing && item.onNavigate != null;

    if (canTap) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            item.onNavigate!();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 0.5),
                  child: Icon(
                    Icons.north_east_rounded,
                    size: 15,
                    color: linkSub,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.22,
                      color: linkInk,
                      letterSpacing: -0.25,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: linkSub),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 0.5),
            child: Icon(
              Icons.link_off_rounded,
              size: 15,
              color: isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              item.raw.isNotEmpty
                  ? '“${item.raw}” — 대상 시나리오를 찾을 수 없습니다'
                  : '대상을 찾을 수 없습니다',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: isDark
                    ? const Color(0xFFFFB4AB)
                    : const Color(0xFFB71C1C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 리스트 썸네일(접힌 카드) 제목 — "유형: 세부" 처럼 `:`가 있으면 뒤쪽(세부)을
/// 더 강한 볼드로(Announcements 리스트 톤과 유사).
/// 콜론 직후 공백은 시트 그대로 둔다(`trimLeft` 금지 — "출발 지연: General" 등).
class _ScenarioHeaderTitle extends StatelessWidget {
  const _ScenarioHeaderTitle({required this.title, required this.onSurface});

  final String title;
  final Color onSurface;

  @override
  Widget build(BuildContext context) {
    final colon = title.indexOf(':');
    if (colon > 0 && colon < title.length - 1) {
      final head = title.substring(0, colon);
      var tail = title.substring(colon + 1);
      // TextSpan 경계 + 음의 letterSpacing 에서 일반 공백이 시각적으로 사라지는
      // 경우가 있어, 맨 앞 공백을 NBSP 로 고정한다.
      if (tail.isNotEmpty && tail[0] == ' ') {
        tail = '\u00A0${tail.substring(1)}';
      }
      return Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 16,
            color: onSurface,
            letterSpacing: -0.4,
            height: 1.15,
          ),
          children: [
            TextSpan(
              text: '$head:',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: tail,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: onSurface,
        letterSpacing: -0.4,
        height: 1.15,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// [AnnouncementFormatter] 가 넣는 강조 마커(치환된 값) 구간을 w700 본문에 얹는다
/// (홈 teleprompter [_spansWithResolvedVariableEmphasis] 와 동일 취지, 옵션
/// [{{…}}] 분해 전에 적용).
List<InlineSpan> _situationalEmphasisInlineSpans(
  String segment,
  TextStyle base,
) {
  if (segment.isEmpty) {
    return const <InlineSpan>[];
  }
  const emS = AnnouncementFormatter.kVariableEmphasisStart;
  const emE = AnnouncementFormatter.kVariableEmphasisEnd;
  final out = <InlineSpan>[];
  var i = 0;
  while (i < segment.length) {
    final start = segment.indexOf(emS, i);
    if (start < 0) {
      out.addAll(pauseBreathInlineSpans(segment.substring(i), base));
      break;
    }
    if (start > i) {
      out.addAll(pauseBreathInlineSpans(segment.substring(i, start), base));
    }
    final end = segment.indexOf(emE, start + emS.length);
    if (end < 0) {
      out.addAll(pauseBreathInlineSpans(segment.substring(start), base));
      break;
    }
    if (end > start + emS.length) {
      out.addAll(
        pauseBreathInlineSpans(
          segment.substring(start + emS.length, end),
          base.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }
    i = end + emE.length;
  }
  return out;
}

List<InlineSpan> _spansForPlainWithBraces(
  String text,
  TextStyle base,
  Color pointColor,
) {
  if (text.isEmpty) {
    return const <InlineSpan>[];
  }
  final out = <InlineSpan>[];
  // `Announcements` 와 같이 `{key}` / `[key]` 가 시트에 남아 있을 수 있음.
  final re = RegExp(r'(\{[^}]+\}|\[[^\]]+\])');
  var start = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > start) {
      out.addAll(pauseBreathInlineSpans(text.substring(start, m.start), base));
    }
    out.add(
      TextSpan(
        text: m.group(0),
        style: base.copyWith(color: pointColor, fontWeight: FontWeight.w700),
      ),
    );
    start = m.end;
  }
  if (start < text.length) {
    out.addAll(pauseBreathInlineSpans(text.substring(start), base));
  }
  return out;
}

/// option / inline 칩·메뉴·모달 전용. 기본(네이비) 볼드와 겹쳐도 보이도록
/// 치환 강조(PUA)와 `{key}` 는 [pointColor] 로 묶는다.
List<InlineSpan> _situationalOptionValueSpans(
  String text,
  TextStyle base, {
  required Color pointColor,
}) {
  if (text.isEmpty) {
    return const <InlineSpan>[];
  }
  const emS = AnnouncementFormatter.kVariableEmphasisStart;
  const emE = AnnouncementFormatter.kVariableEmphasisEnd;
  final out = <InlineSpan>[];
  var i = 0;
  while (i < text.length) {
    final emStart = text.indexOf(emS, i);
    if (emStart < 0) {
      out.addAll(_spansForPlainWithBraces(text.substring(i), base, pointColor));
      break;
    }
    if (emStart > i) {
      out.addAll(
        _spansForPlainWithBraces(text.substring(i, emStart), base, pointColor),
      );
    }
    final emEnd = text.indexOf(emE, emStart + emS.length);
    if (emEnd < 0) {
      out.addAll(
        _spansForPlainWithBraces(text.substring(emStart), base, pointColor),
      );
      break;
    }
    final inner = text.substring(emStart + emS.length, emEnd);
    if (inner.isNotEmpty) {
      out.add(
        TextSpan(
          text: inner,
          style: base.copyWith(color: pointColor, fontWeight: FontWeight.w800),
        ),
      );
    }
    i = emEnd + emE.length;
  }
  return out;
}

Widget _situationalOptionValueText(
  String text,
  TextStyle base, {
  required Color pointColor,
  bool softWrap = true,
  TextAlign textAlign = TextAlign.start,
}) {
  return Text.rich(
    TextSpan(
      children: _situationalOptionValueSpans(
        text,
        base,
        pointColor: pointColor,
      ),
    ),
    softWrap: softWrap,
    textAlign: textAlign,
  );
}

// ============================================================================
// Body — 모든 섹션을 한 흐름의 스크립트로 렌더링한다.
// Announcements와 동일하게 [AnnouncementFormatter]로
// {origin_airport_ko} 등 항공·편명 변수를 치환한 뒤,
// Situational 전용 [{{REASON}}] 토큰을 인라인 UI로 쪼갠다.
// ============================================================================

class _ScriptBody extends ConsumerWidget {
  const _ScriptBody({
    required this.script,
    required this.showEnglish,
    required this.accent,
    required this.selected,
    required this.includeOptional,
    required this.onSelect,
    required this.onIncludeOptional,
  });

  final SituationalScript script;
  final bool showEnglish;
  final Color accent;
  final Map<String, SituationalOption> selected;
  final Map<int, bool> includeOptional;
  final void Function(int sectionIndex, String groupId, SituationalOption opt)
  onSelect;
  final void Function(int sectionIndex, bool include) onIncludeOptional;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final mainReadable = isDark
        ? onSurface.withValues(alpha: 0.96)
        : const Color(0xFF111111);
    final secondaryReadable = isDark
        ? onSurface.withValues(alpha: 0.86)
        : const Color(0xFF262626);

    final bodyStyle = TextStyle(
      fontSize: 18,
      height: 1.55,
      fontWeight: showEnglish
          ? FontWeight.w500
          : (isDark ? FontWeight.w600 : FontWeight.w500),
      letterSpacing: showEnglish ? -0.28 : -0.06,
      color: showEnglish ? secondaryReadable : mainReadable,
      fontStyle: showEnglish ? FontStyle.italic : FontStyle.normal,
    );

    final setup = ref.watch(flightSetupProvider);
    final formatter = ref.watch(announcementFormatterProvider);
    final origin = ref.watch(originAirportProvider);
    final destination = ref.watch(destinationAirportProvider);
    final aircraft = ref.watch(currentAircraftProvider);
    final selectedDelay = ref.watch(selectedDelayReasonProvider);
    final delayReasons = ref.watch(delayReasonsProvider);
    final delayForFormat =
        selectedDelay ?? (delayReasons.isNotEmpty ? delayReasons.first : null);

    String applyFlightTemplate(
      String template, {
      bool inlineDelaySlot = false,
    }) {
      if (template.isEmpty) return template;
      if (setup == null) return template;
      return formatter.format(
        template: template,
        setup: setup,
        originAirport: origin,
        destinationAirport: destination,
        aircraft: aircraft,
        selectedDelayReason: delayForFormat,
        inlineDelayReasonSlot: inlineDelaySlot,
        emphasizeResolvedPlaceholders: true,
      );
    }

    final dualKoStyle = TextStyle(
      fontSize: 20,
      height: 1.65,
      fontWeight: isDark ? FontWeight.w600 : FontWeight.w500,
      letterSpacing: -0.06,
      color: mainReadable,
      fontStyle: FontStyle.normal,
    );

    /// [bodyStyle] 의 영어 모드와 동일(이탤릭 등). 혼합 Content_KO 내 라틴 구간만 20px로 통일.
    final dualEnStyle = TextStyle(
      fontSize: 20,
      height: 1.65,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.28,
      color: secondaryReadable,
      fontStyle: FontStyle.italic,
    );

    final children = <Widget>[];
    for (var i = 0; i < script.sections.length; i++) {
      final section = script.sections[i];
      final raw = showEnglish ? section.contentEn : section.contentKo;
      final body = applyFlightTemplate(raw, inlineDelaySlot: true);
      if (body.trim().isEmpty && section.optionGroups.isEmpty) continue;

      final dualSegs = !showEnglish
          ? buildEmergencyKoEnMixedSegments(body)
          : null;

      final Widget paragraph = dualSegs != null
          ? _SituationalKoEnMixedParagraphColumn(
              section: section,
              sectionIndex: i,
              optionShowEnglish: showEnglish,
              segments: dualSegs,
              dualKoStyle: dualKoStyle,
              dualEnStyle: dualEnStyle,
              accent: accent,
              selected: selected,
              applyFlightTemplate: applyFlightTemplate,
              onSelect: onSelect,
            )
          : _SectionParagraph(
              section: section,
              sectionIndex: i,
              showEnglish: showEnglish,
              accent: accent,
              textStyle: bodyStyle,
              selected: selected,
              applyFlightTemplate: applyFlightTemplate,
              onSelect: onSelect,
            );

      if (section.isOptional) {
        children.add(
          _OptionalSectionShell(
            included: includeOptional[i] ?? false,
            title: section.title,
            accent: accent,
            onChanged: (v) => onIncludeOptional(i, v),
            child: paragraph,
          ),
        );
      } else {
        children.add(paragraph);
      }

      if (i < script.sections.length - 1) {
        children.add(const SizedBox(height: 14));
      }
    }

    if (children.isEmpty) {
      return Text(
        showEnglish ? 'No script available.' : '표시할 방송문이 없습니다.',
        style: bodyStyle.copyWith(
          fontSize: 14,
          fontStyle: FontStyle.italic,
          color: onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

// ============================================================================
// Paragraph — 한 섹션의 본문을 RichText로 렌더링하고, {{TOKEN}}을 인라인
// 드롭다운(또는 바텀시트 트리거)으로 대체한다.
//
// 포맷·치환이 끝난 문자열 단위 렌더는 [_FormattedBodyRichParagraph].
// 한·영 병기 시나리오는 [_SituationalKoEnMixedParagraphColumn].
// ============================================================================

/// [formattedBody]: [applyFlightTemplate] 등으로 미리 포맷된 본문 한 덩어리.
/// [delayDropdownEnglishLabels]: `{delay_reason}` 칩 레이블만 KO/EN 중 어디를 쓸지.
class _FormattedBodyRichParagraph extends ConsumerWidget {
  const _FormattedBodyRichParagraph({
    required this.section,
    required this.sectionIndex,
    required this.optionShowEnglish,
    required this.delayDropdownEnglishLabels,
    required this.formattedBody,
    required this.accent,
    required this.textStyle,
    required this.selected,
    required this.applyFlightTemplate,
    required this.onSelect,
  });

  final SituationalSection section;
  final int sectionIndex;

  /// 옵션 칩 레이블 — 전역 EN 표시 여부와 동일하게 두는 게 일반적.
  final bool optionShowEnglish;
  final bool delayDropdownEnglishLabels;
  final String formattedBody;
  final Color accent;
  final TextStyle textStyle;
  final Map<String, SituationalOption> selected;
  final String Function(String template, {bool inlineDelaySlot})
  applyFlightTemplate;
  final void Function(int sectionIndex, String groupId, SituationalOption opt)
  onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = formattedBody;

    final formatter = ref.watch(announcementFormatterProvider);
    final setup = ref.watch(flightSetupProvider);
    final origin = ref.watch(originAirportProvider);
    final destination = ref.watch(destinationAirportProvider);
    final aircraft = ref.watch(currentAircraftProvider);
    final delayReasons = ref.watch(delayReasonsProvider);
    final selectedDelay = ref.watch(selectedDelayReasonProvider);

    String formattedDelayReason(DelayReasonModel r, {required bool english}) {
      final rawReason = english ? r.reasonEn : r.reasonKo;
      if (rawReason.trim().isEmpty) {
        return r.id;
      }
      if (setup == null) {
        return rawReason.trim();
      }
      return formatter.formatDelayReasonSnippet(
        template: rawReason,
        setup: setup,
        originAirport: origin,
        destinationAirport: destination,
        aircraft: aircraft,
      );
    }

    DelayReasonModel? effectiveDelay;
    if (delayReasons.isNotEmpty) {
      effectiveDelay =
          selectedDelay != null && delayReasons.contains(selectedDelay)
          ? selectedDelay
          : delayReasons.first;
    }

    const delaySentinel = AnnouncementFormatter.kInlineDelayReasonSentinel;
    final tokenPattern = SituationalScript.tokenPattern;

    RegExpMatch? nextTokenMatchFrom(int pos) {
      for (final m in tokenPattern.allMatches(body)) {
        if (m.start >= pos) return m;
      }
      return null;
    }

    if (body.trim().isEmpty) {
      if (section.optionGroups.isEmpty) return const SizedBox.shrink();
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final groupId in section.optionGroups.keys)
            _InlineOptionTrigger(
              groupId: groupId,
              options: section.optionGroups[groupId] ?? const [],
              mode: section.optionGroupModes[groupId],
              selected: selected['$sectionIndex::$groupId'],
              showEnglish: optionShowEnglish,
              accent: accent,
              textStyle: textStyle,
              applyFlightTemplate: applyFlightTemplate,
              onChanged: (opt) => onSelect(sectionIndex, groupId, opt),
            ),
        ],
      );
    }

    final spans = <InlineSpan>[];
    var cursor = 0;
    while (cursor < body.length) {
      final nextDelay = body.indexOf(delaySentinel, cursor);
      final optMatch = nextTokenMatchFrom(cursor);
      final nextOpt = optMatch?.start ?? -1;

      const none = 1 << 30;
      final candDelay = nextDelay >= 0 ? nextDelay : none;
      final candOpt = nextOpt >= 0 ? nextOpt : none;

      if (candDelay == none && candOpt == none) {
        spans.addAll(
          _situationalEmphasisInlineSpans(body.substring(cursor), textStyle),
        );
        break;
      }

      if (candOpt <= candDelay) {
        final m = optMatch!;
        if (m.start > cursor) {
          spans.addAll(
            _situationalEmphasisInlineSpans(
              body.substring(cursor, m.start),
              textStyle,
            ),
          );
        }
        final groupId = m.group(1) ?? '';
        final options = section.optionGroups[groupId] ?? const [];
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: _InlineOptionTrigger(
              groupId: groupId,
              options: options,
              mode: section.optionGroupModes[groupId],
              selected: selected['$sectionIndex::$groupId'],
              showEnglish: optionShowEnglish,
              accent: accent,
              textStyle: textStyle,
              applyFlightTemplate: applyFlightTemplate,
              onChanged: (opt) => onSelect(sectionIndex, groupId, opt),
            ),
          ),
        );
        cursor = m.end;
      } else {
        if (nextDelay > cursor) {
          spans.addAll(
            _situationalEmphasisInlineSpans(
              body.substring(cursor, nextDelay),
              textStyle,
            ),
          );
        }
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: delayReasons.isNotEmpty && effectiveDelay != null
                ? InlineDelayReasonDropdown(
                    reasons: delayReasons,
                    value: effectiveDelay,
                    delayReasonLabel: (r) => formattedDelayReason(
                      r,
                      english: delayDropdownEnglishLabels,
                    ),
                    onChanged: (next) {
                      ref.read(selectedDelayReasonProvider.notifier).state =
                          next;
                    },
                    textStyle: textStyle,
                  )
                : Text('…', style: textStyle),
          ),
        );
        cursor = nextDelay + delaySentinel.length;
      }
    }

    return Text.rich(
      TextSpan(style: textStyle, children: spans),
      strutStyle: StrutStyle(
        fontSize: textStyle.fontSize,
        height: textStyle.height,
        fontWeight: textStyle.fontWeight,
        fontStyle: textStyle.fontStyle,
        forceStrutHeight: false,
        leading: 0.05,
      ),
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: true,
      ),
    );
  }
}

class _SituationalKoEnMixedParagraphColumn extends StatelessWidget {
  const _SituationalKoEnMixedParagraphColumn({
    required this.section,
    required this.sectionIndex,
    required this.optionShowEnglish,
    required this.segments,
    required this.dualKoStyle,
    required this.dualEnStyle,
    required this.accent,
    required this.selected,
    required this.applyFlightTemplate,
    required this.onSelect,
  });

  final SituationalSection section;
  final int sectionIndex;
  final bool optionShowEnglish;
  final List<KoEnMixedSegment> segments;
  final TextStyle dualKoStyle;
  final TextStyle dualEnStyle;
  final Color accent;
  final Map<String, SituationalOption> selected;
  final String Function(String template, {bool inlineDelaySlot})
  applyFlightTemplate;
  final void Function(int sectionIndex, String groupId, SituationalOption opt)
  onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seg in segments) ...[
          for (var d = 0; d < seg.leadingStructuralDividers; d++)
            buildKoEnMixedSegmentRule(isDark: isDark),
          _FormattedBodyRichParagraph(
            section: section,
            sectionIndex: sectionIndex,
            optionShowEnglish: optionShowEnglish,
            delayDropdownEnglishLabels: seg.isLatin,
            formattedBody: seg.text,
            accent: accent,
            textStyle: seg.isLatin ? dualEnStyle : dualKoStyle,
            selected: selected,
            applyFlightTemplate: applyFlightTemplate,
            onSelect: onSelect,
          ),
        ],
      ],
    );
  }
}

class _SectionParagraph extends ConsumerWidget {
  const _SectionParagraph({
    required this.section,
    required this.sectionIndex,
    required this.showEnglish,
    required this.accent,
    required this.textStyle,
    required this.selected,
    required this.applyFlightTemplate,
    required this.onSelect,
  });

  final SituationalSection section;
  final int sectionIndex;
  final bool showEnglish;
  final Color accent;
  final TextStyle textStyle;
  final Map<String, SituationalOption> selected;

  /// {origin_airport_ko} 등: 본문 템플릿([inlineDelaySlot]==true)은 지연사유 센티넬 허용,
  /// 옵션 칩 레이블에서는 false(기본)로 치환문만 반영.
  final String Function(String template, {bool inlineDelaySlot})
  applyFlightTemplate;
  final void Function(int sectionIndex, String groupId, SituationalOption opt)
  onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = showEnglish ? section.contentEn : section.contentKo;
    final body = applyFlightTemplate(raw, inlineDelaySlot: true);
    return _FormattedBodyRichParagraph(
      section: section,
      sectionIndex: sectionIndex,
      optionShowEnglish: showEnglish,
      delayDropdownEnglishLabels: showEnglish,
      formattedBody: body,
      accent: accent,
      textStyle: textStyle,
      selected: selected,
      applyFlightTemplate: applyFlightTemplate,
      onSelect: onSelect,
    );
  }
}
// ============================================================================
// Optional 섹션 박스 — announcement [필요시] 박스 패턴을 차용.
// ============================================================================

class _OptionalSectionShell extends StatelessWidget {
  const _OptionalSectionShell({
    required this.included,
    required this.title,
    required this.accent,
    required this.onChanged,
    required this.child,
  });

  final bool included;
  final String title;
  final Color accent;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // 헤더 한 줄(배지·제목·토글)은 켜짐/꺼짐 동일 — 펼쳤을 때 본문만 아래에 추가.
    final a = accent;

    return AnimatedOpacity(
      duration: UiConstants.softAnimation,
      opacity: included ? 1.0 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: included ? 0.05 : 0.03)
              : UiConstants.navyInk.withValues(alpha: included ? 0.06 : 0.035),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 7, 12, 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: a.withValues(alpha: isDark ? 0.09 : 0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '필요 시',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? _situationalReadableAccent(
                                context,
                                a,
                              ).withValues(alpha: 0.72)
                            : a.withValues(alpha: 0.58),
                        letterSpacing: -0.05,
                      ),
                    ),
                  ),
                  if (title.trim().isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title.trim(),
                        style: TextStyle(
                          fontSize: 12.8,
                          fontWeight: FontWeight.w500,
                          color: onSurface.withValues(
                            alpha: isDark ? 0.66 : 0.52,
                          ),
                          letterSpacing: -0.15,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch.adaptive(
                      value: included,
                      activeTrackColor: a.withValues(alpha: 0.38),
                      activeThumbColor: Colors.white,
                      onChanged: (v) {
                        HapticFeedback.selectionClick();
                        onChanged(v);
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (included)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 12, 10),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Inline option trigger — `option_inline` 은 PopupMenu, `option` 은
// 센터 모달 [_OptionPickerDialog] 로 분기한다. 둘 다 동일한 [_OptionChip]
// 외형을 사용해서 본문 안에서 baseline·폰트·간격이 일정하게 보이도록 한다.
// ============================================================================

class _InlineOptionTrigger extends StatefulWidget {
  const _InlineOptionTrigger({
    required this.groupId,
    required this.options,
    required this.mode,
    required this.selected,
    required this.showEnglish,
    required this.accent,
    required this.textStyle,
    required this.applyFlightTemplate,
    required this.onChanged,
  });

  final String groupId;
  final List<SituationalOption> options;
  final OptionDisplayMode? mode;
  final SituationalOption? selected;
  final bool showEnglish;
  final Color accent;
  final TextStyle textStyle;
  final String Function(String template, {bool inlineDelaySlot})
  applyFlightTemplate;
  final ValueChanged<SituationalOption> onChanged;

  @override
  State<_InlineOptionTrigger> createState() => _InlineOptionTriggerState();
}

class _InlineOptionTriggerState extends State<_InlineOptionTrigger> {
  final GlobalKey _chipKey = GlobalKey();
  double _menuMinWidth = 0;

  static const int _inlineDropdownThreshold = 6;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncMenuMinWidth());
  }

  bool get _hasSubGroup =>
      widget.options.any((o) => o.subGroup.trim().isNotEmpty);

  bool get _useInline {
    if (widget.mode == OptionDisplayMode.inline) return true;
    if (widget.mode == OptionDisplayMode.sheet) return false;
    return widget.options.length <= _inlineDropdownThreshold && !_hasSubGroup;
  }

  String _label(SituationalOption o) {
    final v = (widget.showEnglish ? o.contentEn : o.contentKo).trim();
    final raw = v.isEmpty ? o.contentKo.trim() : v;
    return widget.applyFlightTemplate(raw);
  }

  void _syncMenuMinWidth() {
    final ctx = _chipKey.currentContext;
    if (ctx == null) return;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    final w = ro.size.width;
    if (w <= 0) return;
    if ((w - _menuMinWidth).abs() > 0.5) {
      setState(() => _menuMinWidth = w);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.options.isEmpty) {
      return _OptionChip(
        label: '(${widget.groupId})',
        accent: widget.accent,
        textStyle: widget.textStyle,
        pointColor: UiConstants.situationalOrange,
        showCaret: false,
        onTap: null,
      );
    }

    final effective = widget.selected ?? widget.options.first;
    final label = _label(effective);

    if (_useInline) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncMenuMinWidth());
      return PopupMenuButton<int>(
        tooltip: '',
        padding: EdgeInsets.zero,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 4),
        initialValue: widget.options.indexOf(effective),
        elevation: 6,
        color: Theme.of(context).colorScheme.surface,
        // 트리거(칩)와 동일한 최소 너비 — 항목 문구가 칩보다 좁은 기본 메뉴로 줄바꿈되는
        // 현상을 막는다.
        constraints: _menuMinWidth > 0
            ? BoxConstraints(minWidth: _menuMinWidth)
            : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: _situationalReadableAccent(
              context,
              widget.accent,
            ).withValues(alpha: 0.35),
          ),
        ),
        onOpened: () {
          HapticFeedback.selectionClick();
          _syncMenuMinWidth();
        },
        onSelected: (idx) => widget.onChanged(widget.options[idx]),
        itemBuilder: (ctx) => [
          for (var i = 0; i < widget.options.length; i++)
            PopupMenuItem<int>(
              value: i,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: _situationalOptionValueText(
                _label(widget.options[i]),
                TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: Theme.of(ctx).colorScheme.onSurface,
                ),
                pointColor: UiConstants.situationalOrange,
                softWrap: true,
              ),
            ),
        ],
        child: _OptionChip(
          key: _chipKey,
          label: label,
          accent: widget.accent,
          textStyle: widget.textStyle,
          pointColor: UiConstants.situationalOrange,
          showCaret: true,
          onTap: null,
        ),
      );
    }

    return _OptionChip(
      label: label,
      accent: widget.accent,
      textStyle: widget.textStyle,
      pointColor: UiConstants.situationalOrange,
      showCaret: true,
      onTap: () async {
        HapticFeedback.selectionClick();
        final picked = await showDialog<SituationalOption>(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black.withValues(alpha: 0.45),
          builder: (dialogCtx) => _OptionPickerDialog(
            groupId: widget.groupId,
            options: widget.options,
            selected: effective,
            showEnglish: widget.showEnglish,
            accent: widget.accent,
            formatLine: widget.applyFlightTemplate,
          ),
        );
        if (picked != null) widget.onChanged(picked);
      },
    );
  }
}

/// inline / sheet trigger 가 공유하는 외형.
///
/// [WidgetSpan] + 본문과의 수직 정렬은 상위 [PlaceholderAlignment.middle] 과
/// 내부 [Row] center 정렬로 맞춘다.
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    super.key,
    required this.label,
    required this.accent,
    required this.textStyle,
    required this.pointColor,
    required this.showCaret,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final TextStyle textStyle;

  /// 치환 강조·`{key}` — 본문 네이비 볼드와 구분되는 포인트.
  final Color pointColor;
  final bool showCaret;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mediaW = (MediaQuery.sizeOf(context).width - 48).clamp(160.0, 900.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final accentFg = _situationalReadableAccent(context, accent);
        final radius = BorderRadius.circular(8);
        final baseSize = textStyle.fontSize ?? 19;
        // RichText의 WidgetSpan이 남은 줄 너비를 넘겨줄 때 intrinsic 높이와
        // 실제 줄바꿈 너비를 맞추기 위해 우선 부모 maxWidth를 쓴다.
        final maxChipW =
            (constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0)
            ? constraints.maxWidth.clamp(80.0, 900.0)
            : mediaW;
        final chipStyle = TextStyle(
          fontSize: baseSize,
          fontWeight: FontWeight.w700,
          color: accentFg,
          letterSpacing: textStyle.letterSpacing ?? -0.2,
          // 본문(strut)과 rhythm 을 맞추면 다줄 칩-텍스트 간격이 안정적이다.
          height: textStyle.height ?? 1.65,
        );
        final caret = Icon(
          Icons.arrow_drop_down_rounded,
          size: baseSize + 4,
          color: accentFg,
        );

        final body = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxChipW),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: _situationalOptionValueText(
                  label,
                  chipStyle,
                  pointColor: pointColor,
                  softWrap: true,
                ),
              ),
              if (showCaret)
                Padding(padding: const EdgeInsets.only(left: 6), child: caret),
            ],
          ),
        );

        final chip = Container(
          padding: EdgeInsets.fromLTRB(6, 2, showCaret ? 4 : 6, 2),
          decoration: BoxDecoration(
            color: isDark
                ? accentFg.withValues(alpha: 0.14)
                : accent.withValues(alpha: 0.07),
            borderRadius: radius,
          ),
          child: body,
        );

        final interactive = onTap == null
            ? chip
            : Material(
                color: Colors.transparent,
                borderRadius: radius,
                child: InkWell(onTap: onTap, borderRadius: radius, child: chip),
              );

        // 본문 줄과의 baseline 어긋남을 줄이기 위한 소폭 보정(과도한 하단 여백 없음).
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: interactive,
        );
      },
    );
  }
}

// ============================================================================
// 옵션이 많거나 SubGroup으로 분류되는 경우 — 센터 모달(배리어/ X 로 닫힘) +
// 전체(기본) + SubGroup 칩 + 검색 + 스크롤 리스트. Situational 시트 위에
// 또다른 bottom sheet 를 쌓지 않는다.
// ============================================================================

class _OptionPickerDialog extends StatefulWidget {
  const _OptionPickerDialog({
    required this.groupId,
    required this.options,
    required this.selected,
    required this.showEnglish,
    required this.accent,
    required this.formatLine,
  });

  final String groupId;
  final List<SituationalOption> options;
  final SituationalOption? selected;
  final bool showEnglish;
  final Color accent;
  final String Function(String template, {bool inlineDelaySlot}) formatLine;

  @override
  State<_OptionPickerDialog> createState() => _OptionPickerDialogState();
}

class _OptionPickerDialogState extends State<_OptionPickerDialog> {
  /// 항상 '전체'로 시작 — 모든 subcategory 사유를 처음부터 한눈에.
  String _activeGroup = '__all__';
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _orderedSubGroups() {
    final seen = <String>{};
    final ordered = <String>[];
    for (final o in widget.options) {
      final sg = o.subGroup.trim();
      if (sg.isEmpty) continue;
      if (seen.add(sg)) ordered.add(sg);
    }
    return ordered;
  }

  String _label(SituationalOption o) {
    final v = (widget.showEnglish ? o.contentEn : o.contentKo).trim();
    final raw = v.isEmpty ? o.contentKo.trim() : v;
    return widget.formatLine(raw);
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final point = UiConstants.situationalOrange;
    final baseNavy = widget.accent;

    final groups = _orderedSubGroups();
    final showAllTab = groups.isNotEmpty;
    final filteredByGroup = widget.options.where((o) {
      if (!showAllTab) return true;
      if (_activeGroup == '__all__') return true;
      final sg = o.subGroup.trim();
      return sg == _activeGroup;
    }).toList();

    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? filteredByGroup
        : filteredByGroup
              .where(
                (o) =>
                    o.contentKo.toLowerCase().contains(q) ||
                    o.contentEn.toLowerCase().contains(q),
              )
              .toList();

    final maxH = (mq.size.height * 0.75).clamp(300.0, 680.0);
    final surface = isDark ? const Color(0xFF1C2430) : Colors.white;
    final fillSoft = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : UiConstants.navyInk.withValues(alpha: 0.05);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Material(
              color: surface,
              elevation: 10,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.max,
                children: [
                  // 헤더: 제목 + X (배리어/ X 모두 [Navigator.pop] → 선택 없음)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 2, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 4, 0),
                            child: Text(
                              _sheetTitle(widget.groupId),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? onSurface : UiConstants.navyInk,
                                letterSpacing: -0.4,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '닫기',
                          icon: Icon(
                            Icons.close_rounded,
                            size: 24,
                            color: onSurface.withValues(alpha: 0.5),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v),
                      cursorColor: point,
                      style: TextStyle(
                        color: isDark ? onSurface : UiConstants.navyInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 4,
                        ),
                        hintText: '옵션 검색',
                        hintStyle: TextStyle(
                          color: onSurface.withValues(alpha: 0.45),
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: isDark
                              ? _situationalReadableAccent(context, baseNavy)
                              : baseNavy,
                          size: 22,
                        ),
                        filled: true,
                        fillColor: fillSoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: point.withValues(alpha: 0.5),
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showAllTab) ...[
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        scrollDirection: Axis.horizontal,
                        itemCount: groups.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final id = i == 0 ? '__all__' : groups[i - 1];
                          final label = i == 0 ? '전체' : groups[i - 1];
                          final active = id == _activeGroup;
                          return _SheetGroupChip(
                            label: label,
                            active: active,
                            accent: baseNavy,
                            point: point,
                            isDark: isDark,
                            onSurface: onSurface,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activeGroup = id);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                q.isEmpty
                                    ? '이 그룹에 옵션이 없습니다.'
                                    : '"$q" 에 해당하는 옵션이 없습니다.',
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 2),
                            itemBuilder: (_, i) {
                              final o = filtered[i];
                              final isSelected =
                                  widget.selected != null &&
                                  widget.selected!.contentKo == o.contentKo &&
                                  widget.selected!.contentEn == o.contentEn;
                              final secondaryRaw = widget.showEnglish
                                  ? o.contentKo
                                  : o.contentEn;
                              final secondary = secondaryRaw.trim().isEmpty
                                  ? null
                                  : widget.formatLine(secondaryRaw.trim());
                              return _SheetOptionRow(
                                primary: _label(o),
                                secondary: secondary,
                                isSelected: isSelected,
                                accent: baseNavy,
                                point: point,
                                isDark: isDark,
                                onSurface: onSurface,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.of(context).pop(o);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _sheetTitle(String groupId) {
    switch (groupId) {
      case 'REASON':
        return '사유 선택';
      case 'DURATION':
        return '소요 시간 선택';
      case 'ACTION':
        return '조치 안내 선택';
      case 'FUEL_STATUS':
        return '연료 공급 상태 선택';
      default:
        return '$groupId 선택';
    }
  }
}

class _SheetGroupChip extends StatelessWidget {
  const _SheetGroupChip({
    required this.label,
    required this.active,
    required this.accent,
    required this.point,
    required this.isDark,
    required this.onSurface,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color accent;
  final Color point;
  final bool isDark;
  final Color onSurface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // borderless + 세로 정렬: 고정 높이 안에서 [Center] 로 글자 중앙.
    final bg = active
        ? accent.withValues(alpha: isDark ? 0.18 : 0.12)
        : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : UiConstants.navyInk.withValues(alpha: 0.05));
    final fg = active
        ? (isDark ? const Color(0xFFB4C8F0) : accent)
        : onSurface.withValues(alpha: 0.72);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: point.withValues(alpha: 0.12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36, maxHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.0,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  color: fg,
                  letterSpacing: -0.15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetOptionRow extends StatelessWidget {
  const _SheetOptionRow({
    required this.primary,
    required this.secondary,
    required this.isSelected,
    required this.accent,
    required this.point,
    required this.isDark,
    required this.onSurface,
    required this.onTap,
  });

  final String primary;
  final String? secondary;
  final bool isSelected;
  final Color accent;
  final Color point;
  final bool isDark;
  final Color onSurface;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rowBg = isSelected
        ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
        : (isDark
              ? Colors.white.withValues(alpha: 0.02)
              : UiConstants.navyInk.withValues(alpha: 0.02));
    final lead = isSelected
        ? Icon(Icons.check_circle_rounded, size: 22, color: point)
        : Icon(
            Icons.circle_outlined,
            size: 20,
            color: onSurface.withValues(alpha: 0.35),
          );
    return Material(
      color: rowBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 1), child: lead),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _situationalOptionValueText(
                      primary,
                      TextStyle(
                        fontSize: 15,
                        height: 1.45,
                        color: onSurface.withValues(
                          alpha: isSelected ? 1.0 : 0.9,
                        ),
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        letterSpacing: -0.12,
                      ),
                      pointColor: point,
                      softWrap: true,
                    ),
                    if (secondary != null && secondary!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      _situationalOptionValueText(
                        secondary!,
                        TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: onSurface.withValues(alpha: 0.55),
                          fontStyle: FontStyle.italic,
                          letterSpacing: -0.1,
                        ),
                        pointColor: point,
                        softWrap: true,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// (언어: Announcements와 동일하게 펼친 본문 영역 탭으로 한↔전환)
