import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../core/utils/situational_subcategory_palette.dart';
import '../../../domain/entities/situational_script.dart';
import '../../../domain/services/situational_global_search.dart';
import '../../../domain/services/situational_link_resolver.dart';
import '../../providers/flight_setup_provider.dart';
import '../../providers/situational_provider.dart';
import '../../providers/situational_quick_access_provider.dart';
import '../../widgets/quick_access_mini_popup.dart';
import '../../widgets/quick_dock.dart';
import '../../widgets/situational_script_card.dart';
import '../../widgets/staggered_entrance.dart';
import '../emergency/emergency_screen.dart';

/// [UiConstants.situationalNavy] 는 다크 배경에서 대비가 사라짐 — 허브 eyebrow·서브탭·검색 아이콘용.
Color _situationalHubReadableInk(BuildContext context) {
  if (Theme.of(context).brightness != Brightness.dark) {
    return UiConstants.situationalNavy;
  }
  return const Color(0xFFB4C8F0);
}

/// 검색어와 겹치는 구간만 [highlightStyle]로 묶은 [TextSpan] 목록.
List<TextSpan> _highlightQueryInText(
  String text,
  String query,
  TextStyle baseStyle,
  TextStyle highlightStyle,
) {
  final q = query.trim();
  if (q.isEmpty || text.isEmpty) {
    return [TextSpan(text: text, style: baseStyle)];
  }
  final lower = text.toLowerCase();
  final qLower = q.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (start < text.length) {
    final i = lower.indexOf(qLower, start);
    if (i < 0) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
      break;
    }
    if (i > start) {
      spans.add(TextSpan(text: text.substring(start, i), style: baseStyle));
    }
    final end = (i + q.length).clamp(0, text.length);
    spans.add(
      TextSpan(
        text: text.substring(i, end),
        style: highlightStyle,
      ),
    );
    start = end;
  }
  return spans;
}

const _subTabAll = '__all__';
const _subTabFavorite = '__fav__';
const _subTabRecent = '__recent__';

/// 홈 [_kPhaseHeaderStripHeight] 와 같이 — 텍스트·캡션 길이가 바뀌어도 상단 줄 높이 고정.
const double _kSituationalHubEyebrowRowHeight = 44;

/// 큰 카테고리 제목 한 줄(아이콘 26 + 28pt 타이틀) 기준.
const double _kSituationalHubCategoryTitleRowHeight = 38;

/// 서브탭 칩 행 / 검색 필드 행.
const double _kSituationalHubFilterRowHeight = 44;

class SituationalCategoryHubScreen extends ConsumerStatefulWidget {
  const SituationalCategoryHubScreen({
    super.key,
    required this.category,
    this.initialFocusScriptId,
  });

  final SituationalCategoryDef category;

  /// 열리자마자 해당 시나리오 카드를 펼치고 스크롤한다 (`SituationalScript.id`).
  final String? initialFocusScriptId;

  @override
  ConsumerState<SituationalCategoryHubScreen> createState() =>
      _SituationalCategoryHubScreenState();
}

class _SituationalCategoryHubScreenState
    extends ConsumerState<SituationalCategoryHubScreen> {
  String _activeTab = _subTabAll;
  bool _searchOpen = false;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  /// 허브 안에서 다시 띄울 때 사용할 Quick Access 도크 버튼 anchor.
  final GlobalKey _quickAccessAnchorKey = GlobalKey();

  /// 현재 표시 중인 카테고리. QuickDock에서 다른 카테고리를 누르면 화면을 새로
  /// 푸시하지 않고 in-place로 전환되도록 mutable 상태로 보관한다.
  late SituationalCategoryDef _def;

  /// 한 번에 하나의 시나리오 카드만 펼쳐진다(아코디언).
  String? _expandedScriptId;

  /// [Scrollable.ensureVisible]용 — 시나리오 id → 카드 [GlobalKey].
  final _scenarioCardKeys = <String, GlobalKey>{};

  /// 시나리오 목록·전역 검색 결과 — 시트/부모와 [PrimaryScrollController] 충돌 방지.
  final ScrollController _listScrollController = ScrollController();

  /// [Link] 로 다른 카테고리 시나리오로 점프할 때, 닫지 않고 돌아올 스냅샷.
  final List<_SituationalLinkFrame> _linkBackStack = <_SituationalLinkFrame>[];

  /// 링크로 방금 도착한 시나리오 — 같은 카드를 접었다 펼칠 때는 [onExpansionChanged] 가 스택을 비우지 않음.
  String? _linkArrivalId;

  /// 바로가기 등으로 열 때 초기 펼침이 끝났는지.
  bool _appliedInitialFocus = false;

  /// [onExpansionChanged] 가 링크 이동 직후 프레임에 먼저 올 수 있어, 프로그램적 펼침에서는
  /// 스택을 비우지 않도록 표시한다.
  String? _pendingLinkJumpId;

  GlobalKey _keyForScenario(String id) {
    return _scenarioCardKeys.putIfAbsent(id, () => GlobalKey());
  }

  /// 카테고리 전환(도크·링크·«돌아가기») 시 기존 [GlobalKey] 가 한 프레임에 두
  /// 카드에 붙는 레이아웃 버그를 피하기 위해 맵을 비운다.
  void _clearScenarioCardKeys() {
    _scenarioCardKeys.clear();
  }

  /// 즐겨찾기 등 전역 목록 정렬용 — [situationalCategoryOrder] 와 동일한 순서.
  int _situationalCategorySortIndex(SituationalScript s) {
    final d = categoryDefByLabel(s.category);
    if (d == null) return situationalCategoryOrder.length;
    final i = situationalCategoryOrder.indexOf(d);
    return i < 0 ? situationalCategoryOrder.length : i;
  }

  /// 펼친 뒤 레이아웃이 잡힌 다음 스크롤(잘림 방지). 한 프레임 더 쉬어
  /// [AnimatedCrossFade] 이후 측정이 안정적이다.
  void _goToLinkedScenario(SituationalScript from, SituationalScript to) {
    if (!mounted) return;
    final nextDef = categoryDefByLabel(to.category);
    if (nextDef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이동할 카테고리를 찾을 수 없습니다.'),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _clearScenarioCardKeys();
      _linkBackStack.add(
        _SituationalLinkFrame(
          category: _def,
          expandedScriptId: _expandedScriptId,
          activeSubTab: _activeTab,
          returnLabel: from.scenario,
        ),
      );
      _def = nextDef;
      final subs = ref.read(situationalSubCategoriesProvider(nextDef.id));
      _activeTab = (to.subCategory.isNotEmpty && subs.contains(to.subCategory))
          ? to.subCategory
          : _subTabAll;
      _searchOpen = false;
      _query = '';
      _searchController.clear();
      _expandedScriptId = to.id;
      _linkArrivalId = to.id;
      _pendingLinkJumpId = to.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollExpandedIntoView(to.id);
      // onExpansionChanged 가 안 오는 경우 대비(고아 _pendingLinkJumpId 제거)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pendingLinkJumpId == to.id) {
          setState(() => _pendingLinkJumpId = null);
        }
      });
    });
  }

  List<SituationalResolvedLink> _resolveLinksForScript(
    SituationalScript s,
    List<SituationalScript>? all,
  ) {
    final raw = s.linkTarget.trim();
    if (raw.isEmpty) return const [];
    final segs = raw
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (segs.isEmpty) return const [];
    if (all == null) {
      return [
        for (final seg in segs)
          SituationalResolvedLink(raw: seg, missing: true),
      ];
    }
    return [
      for (final seg in segs)
        _resolveOneLink(s, all, seg),
    ];
  }

  SituationalResolvedLink _resolveOneLink(
    SituationalScript from,
    List<SituationalScript> all,
    String seg,
  ) {
    final t = resolveSituationalLink(all, seg, from: from);
    if (t == null) {
      return SituationalResolvedLink(raw: seg, missing: true);
    }
    final dest = t;
    return SituationalResolvedLink(
      raw: seg,
      target: dest,
      onNavigate: () => _goToLinkedScenario(from, dest),
    );
  }

  void _popLinkNavigation() {
    if (_linkBackStack.isEmpty) return;
    HapticFeedback.selectionClick();
    final prev = _linkBackStack.removeLast();
    setState(() {
      _clearScenarioCardKeys();
      _def = prev.category;
      _expandedScriptId = prev.expandedScriptId;
      _activeTab = prev.activeSubTab;
      _searchOpen = false;
      _query = '';
      _searchController.clear();
      _linkArrivalId = null;
      _pendingLinkJumpId = null;
    });
    if (prev.expandedScriptId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollExpandedIntoView(prev.expandedScriptId!);
      });
    }
  }

  void _scrollExpandedIntoView(String id) {
    /// 복귀 시 카테고리·탭 전환 후 리스트가 다시 붙을 때까지 컨텍스트가 없을 수 있어
    /// 프레임을 몇 번 돌며 재시도한다. 펼침 애니메이션 뒤 높이 변화를 위해 2회 스크롤.
    /// [alignment] 0 — 카드 상단(헤더)이 리스트 뷰포트 상단에 맞도록.
    const alignment = 0.0;
    var waitFrames = 0;

    void scrollNow() {
      final ctx = _scenarioCardKeys[id]?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: alignment,
      );
    }

    void schedule() {
      if (!mounted || waitFrames > 20) return;
      waitFrames++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = _scenarioCardKeys[id]?.currentContext;
        if (ctx != null) {
          scrollNow();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            scrollNow();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) scrollNow();
            });
          });
        } else {
          schedule();
        }
      });
    }

    schedule();
  }

  /// 사용자가 카드를 펼칠 때 — [AnimatedCrossFade] 이후 한 번 더 맞춤.
  void _scrollExpandedIntoViewAfterUserExpand(String id) {
    _scrollExpandedIntoView(id);
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      if (_expandedScriptId != id) return;
      _scrollExpandedIntoView(id);
    });
  }

  void _applyInitialFocus(List<SituationalScript> all, String focusId) {
    if (_appliedInitialFocus) return;
    SituationalScript? script;
    for (final s in all) {
      if (s.id == focusId) {
        script = s;
        break;
      }
    }
    if (script == null) {
      _appliedInitialFocus = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('해당 방송문을 찾을 수 없습니다. 시트 매칭을 확인해 주세요.'),
            duration: Duration(milliseconds: 1600),
          ),
        );
      }
      return;
    }
    final def = categoryDefByLabel(script.category);
    if (def == null) {
      _appliedInitialFocus = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('카테고리를 찾을 수 없습니다.'),
            duration: Duration(milliseconds: 1400),
          ),
        );
      }
      return;
    }
    _appliedInitialFocus = true;
    HapticFeedback.selectionClick();
    final sId = script.id;
    final sub = script.subCategory;
    setState(() {
      _clearScenarioCardKeys();
      _def = def;
      final subs = ref.read(situationalSubCategoriesProvider(def.id));
      _activeTab = (sub.isNotEmpty && subs.contains(sub)) ? sub : _subTabAll;
      _searchOpen = false;
      _query = '';
      _searchController.clear();
      _expandedScriptId = sId;
      _linkArrivalId = null;
      _pendingLinkJumpId = sId;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollExpandedIntoView(sId);
    });
  }

  @override
  void initState() {
    super.initState();
    _def = widget.category;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focusId = widget.initialFocusScriptId;
      if (focusId != null) {
        _tryApplyInitialFocusIfDataReady(focusId);
      } else {
        _autoSelectSubTab();
      }
    });
  }

  /// [initialFocusScriptId]: 스크립트가 이미 로드된 경우(ref 가 곧바로
  /// AsyncData) `ref.listen` 이 다시 불리지 않아 펼침이 누락될 수 있다.
  /// 첫 프레임에 동기 확인으로 보충한다.
  void _tryApplyInitialFocusIfDataReady(String focusId) {
    if (_appliedInitialFocus) return;
    final all = ref.read(situationalScriptsProvider).valueOrNull;
    if (all == null || all.isEmpty) return;
    _applyInitialFocus(all, focusId);
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _autoSelectSubTab() {
    if (!mounted) return;
    final milestone = ref.read(selectedMilestoneProvider);
    if (milestone == null) return;
    final subs = ref.read(situationalSubCategoriesProvider(_def.id));
    final match = subs.firstWhere(
      (s) => _isMilestoneMatch(s, milestone),
      orElse: () => '',
    );
    if (match.isNotEmpty && _activeTab == _subTabAll) {
      setState(() {
        _activeTab = match;
        _expandedScriptId = null;
      });
    }
  }

  bool _isMilestoneMatch(String subCategory, String milestone) {
    final sub = subCategory.toLowerCase();
    final ms = milestone.toLowerCase();
    if (sub.contains('pushback') && ms.contains('pushback')) return true;
    if (sub.contains('이륙') && ms.contains('take')) return true;
    if (sub.contains('비행 중') &&
        (ms.contains('cruise') || ms.contains('flight'))) {
      return true;
    }
    if (sub.contains('착륙') &&
        (ms.contains('land') || ms.contains('arrival'))) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final focusId = widget.initialFocusScriptId;
    if (focusId != null) {
      ref.listen(situationalScriptsProvider, (prev, next) {
        if (_appliedInitialFocus) return;
        next.whenData((all) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _appliedInitialFocus) return;
            _applyInitialFocus(all, focusId);
          });
        });
      });
    }

    ref.listen(situationalQuickAccessTargetIdProvider, (prev, id) {
      if (id == null || id.isEmpty) return;
      ref.read(situationalQuickAccessTargetIdProvider.notifier).state = null;
      final all = ref.read(situationalScriptsProvider).valueOrNull;
      if (all == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _appliedInitialFocus = false;
        _applyInitialFocus(all, id);
      });
    });

    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Situational 의 시각 베이스는 차분한 navy. 오렌지는 점/배지 같은
    // 의미 있는 포인트에만 짧게 사용한다.
    const accent = UiConstants.situationalNavy;
    const pointAccent = UiConstants.situationalOrange;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subCategories = ref.watch(situationalSubCategoriesProvider(_def.id));
    final scriptsAsync = ref.watch(situationalScriptsProvider);

    // 시트가 차지할 영역 — 홈의 로고 한 줄 정도만 살짝 보이도록 위쪽에 좁게
    // 여백을 둔다(status bar + 로고 높이 정도).
    final topInset = MediaQuery.viewPaddingOf(context).top;
    final reservedTop = topInset + 56;

    final surfaceTop = isDark
        ? const Color(0xFF1E2735).withValues(alpha: 0.86)
        : Colors.white.withValues(alpha: 0.82);
    final surfaceBottom = isDark
        ? const Color(0xFF18212F).withValues(alpha: 0.84)
        : const Color(0xFFF5F9FF).withValues(alpha: 0.74);

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
              Navigator.of(context).maybePop();
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: reservedTop,
          bottom: 0,
          child: ClipRRect(
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [surfaceTop, surfaceBottom],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0x66000000)
                      : const Color(0xFF93A8C2).withValues(alpha: 0.18),
                  blurRadius: 28,
                  spreadRadius: -8,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  children: [
                    _buildHeader(pointAccent, onSurface),
                    const SizedBox(height: 7),
                    _buildSubTabs(subCategories, onSurface),
                    const SizedBox(height: 7),
                    Expanded(
                      child: scriptsAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('데이터를 불러오지 못했습니다.\n$e'),
                          ),
                        ),
                        data: (_) => _buildList(accent),
                      ),
                    ),
                    QuickDock(
                      highlightCategory: _def.id,
                      quickAccessAnchorKey: _quickAccessAnchorKey,
                      onCategoryTap: (def) {
                        HapticFeedback.lightImpact();
                        if (def.id == _def.id) return;
                        setState(() {
                          _clearScenarioCardKeys();
                          _def = def;
                          _activeTab = _subTabAll;
                          _searchOpen = false;
                          _query = '';
                          _searchController.clear();
                          _expandedScriptId = null;
                          _linkBackStack.clear();
                          _linkArrivalId = null;
                          _pendingLinkJumpId = null;
                        });
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _autoSelectSubTab(),
                        );
                      },
                      onQuickAccessTap: () async {
                        HapticFeedback.mediumImpact();
                        await showQuickAccessMiniPopup(
                          context: context,
                          ref: ref,
                          anchorKey: _quickAccessAnchorKey,
                          onNavigateToScript: (script) async {
                            ref
                                .read(
                                  situationalQuickAccessTargetIdProvider
                                      .notifier,
                                )
                                .state = script.id;
                          },
                        );
                      },
                      onEmergencyTap: () async {
                        HapticFeedback.heavyImpact();
                        if (!context.mounted) return;
                        await EmergencyScreen.show(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Color pointAccent, Color onSurface) {
    final softInk = onSurface.withValues(alpha: 0.7);
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(UiConstants.pagePadding, 6, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow caption + 우측 검색/닫기 액션. 작은 dot 만 orange 포인트.
          SizedBox(
            height: _kSituationalHubEyebrowRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: pointAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: pointAccent.withValues(alpha: 0.55),
                        blurRadius: 6,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 20,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedSwitcher(
                        duration: UiConstants.softAnimation,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: Text(
                          _searchOpen
                              ? 'SITUATIONAL · 검색'
                              : 'SITUATIONAL · ${_def.caption}',
                          key: ValueKey<bool>(_searchOpen),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.0,
                            fontWeight: FontWeight.w800,
                            color: _situationalHubReadableInk(context),
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '검색',
                  icon: Icon(
                    _searchOpen ? Icons.close_rounded : Icons.search_rounded,
                    color: softInk,
                    size: 22,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    setState(() {
                      _searchOpen = !_searchOpen;
                      if (!_searchOpen) {
                        _query = '';
                        _searchController.clear();
                      }
                      _expandedScriptId = null;
                    });
                  },
                ),
                IconButton(
                  tooltip: '닫기',
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: softInk,
                    size: 26,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          AnimatedSize(
            duration: UiConstants.softAnimation,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topLeft,
            clipBehavior: Clip.hardEdge,
            child: _searchOpen
                ? const SizedBox.shrink()
                : SizedBox(
                    height: _kSituationalHubCategoryTitleRowHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: UiConstants.pagePadding,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            _def.icon,
                            color: onSurface.withValues(alpha: 0.85),
                            size: 26,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _def.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 28,
                                height: 1.0,
                                fontWeight: FontWeight.w800,
                                color: onSurface,
                                letterSpacing: -0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabs(
    List<String> subCategories,
    Color onSurface,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final favorites = ref.watch(situationalFavoritesProvider);
    final recents = ref.watch(situationalRecentsProvider);
    final allScriptsGlobal =
        ref.watch(situationalScriptsProvider).value ?? const [];
    final allScripts =
        ref.watch(situationalScriptsByCategoryProvider(_def.id));
    final favCountGlobal = allScriptsGlobal
        .where((s) => favorites.contains(s.id))
        .length;
    final recentCountInCategory = allScripts
        .where((s) => recents.contains(s.id))
        .length;

    final tabs = <_SubTab>[
      _SubTab(id: _subTabAll, label: '전체', icon: Icons.apps_rounded),
      _SubTab(
        id: _subTabFavorite,
        label: '즐겨찾기 · $favCountGlobal',
        icon: Icons.star_rounded,
      ),
      if (recentCountInCategory > 0)
        _SubTab(
          id: _subTabRecent,
          label: '최근 · $recentCountInCategory',
          icon: Icons.history_rounded,
        ),
      for (final s in subCategories)
        _SubTab(id: s, label: s, icon: null),
    ];

    if (_searchOpen) {
      return Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: UiConstants.pagePadding),
        child: SizedBox(
          height: _kSituationalHubFilterRowHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withAlpha(140),
              ),
            ),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textAlignVertical: TextAlignVertical.center,
              onChanged: (v) => setState(() {
                _query = v.trim();
                _expandedScriptId = null;
              }),
              style: TextStyle(
                color: isDark ? onSurface : UiConstants.navyInk,
                fontSize: 15,
                height: 1.0,
                fontWeight: FontWeight.w600,
              ),
              cursorColor: UiConstants.situationalOrange,
              decoration: InputDecoration(
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: _situationalHubReadableInk(context),
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 44,
                ),
                hintText: '모든 카테고리 · 제목 · 본문 · 옵션 검색',
                hintStyle: TextStyle(
                  color: onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  height: 1.0,
                ),
                filled: false,
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                isDense: false,
                contentPadding: const EdgeInsets.fromLTRB(0, 12, 14, 12),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: _kSituationalHubFilterRowHeight,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: UiConstants.pagePadding,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final tab = tabs[i];
          final active = tab.id == _activeTab;
          final stripe = (tab.id != _subTabAll &&
                  tab.id != _subTabFavorite &&
                  tab.id != _subTabRecent)
              ? SituationalSubCategoryPalette.colorForSubCategory(
                  tab.id,
                  subCategories,
                  isDark,
                )
              : null;
          return _SubTabChip(
            tab: tab,
            active: active,
            subCategoryStripe: stripe,
            iconColor: tab.id == _subTabFavorite
                ? const Color(0xFFEAB308)
                : null,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _activeTab = tab.id;
                _expandedScriptId = null;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildList(Color accent) {
    final allForResolve =
        ref.watch(situationalScriptsProvider).valueOrNull;
    final allScriptsGlobal =
        ref.watch(situationalScriptsProvider).value ?? const [];
    final allScripts =
        ref.watch(situationalScriptsByCategoryProvider(_def.id));
    final favorites = ref.watch(situationalFavoritesProvider);
    final recents = ref.watch(situationalRecentsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final queryTrim = _query.trim();

    if (_searchOpen) {
      if (queryTrim.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              '모든 카테고리 방송문에서 검색합니다.\n검색어를 입력해 주세요.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
          ),
        );
      }
      if (allScriptsGlobal.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              '방송문 데이터가 없어 검색할 수 없습니다.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }
      final hits = situationalGlobalSearch(allScriptsGlobal, queryTrim);
      if (hits.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              '"$queryTrim"에 해당하는 방송문이 없습니다.\n(전체 카테고리 검색)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
      }
      return ListView.separated(
        key: ValueKey('global_search_$queryTrim'),
        controller: _listScrollController,
        primary: false,
        padding: const EdgeInsets.fromLTRB(
          UiConstants.pagePadding,
          4,
          UiConstants.pagePadding,
          14,
        ),
        itemCount: hits.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (_, i) => StaggeredEntrance(
          index: i,
          child: _buildSearchHitTile(hits[i], queryTrim, isDark),
        ),
      );
    }

    Iterable<SituationalScript> filtered = allScripts;

    if (_activeTab == _subTabFavorite) {
      filtered = allScriptsGlobal
          .where((s) => favorites.contains(s.id))
          .toList()
        ..sort((a, b) {
          final c = _situationalCategorySortIndex(a)
              .compareTo(_situationalCategorySortIndex(b));
          if (c != 0) return c;
          final cs = a.subCategory.compareTo(b.subCategory);
          if (cs != 0) return cs;
          return a.scenario.compareTo(b.scenario);
        });
    } else if (_activeTab == _subTabRecent) {
      final index = {
        for (var i = 0; i < recents.length; i++) recents[i]: i,
      };
      filtered = filtered.where((s) => index.containsKey(s.id)).toList()
        ..sort((a, b) => (index[a.id] ?? 0).compareTo(index[b.id] ?? 0));
    } else if (_activeTab != _subTabAll) {
      filtered = filtered.where((s) => s.subCategory == _activeTab);
    }

    final list = filtered.toList();
    final seenIds = <String>{};
    final deduped = <SituationalScript>[];
    for (final s in list) {
      if (seenIds.add(s.id)) deduped.add(s);
    }
    if (deduped.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _emptyMessage(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    // QuickDock 이 같은 시트 안의 다음 형제 위젯이라, 리스트 자체는 일반적인
    // 카드 간 여백만 가지면 충분하다.
    return ListView.separated(
      key: ValueKey('${_def.id}_$_activeTab'),
      controller: _listScrollController,
      primary: false,
      padding: const EdgeInsets.fromLTRB(
        UiConstants.pagePadding,
        4,
        UiConstants.pagePadding,
        14,
      ),
      itemCount: deduped.length,
      separatorBuilder: (_, _) => const SizedBox(height: 9),
      itemBuilder: (_, i) {
        final s = deduped[i];
        final canPop = _linkBackStack.isNotEmpty;
        final scriptCat = categoryDefByLabel(s.category);
        final orderedForStripe = scriptCat != null
            ? ref.watch(situationalSubCategoriesProvider(scriptCat.id))
            : const <String>[];
        final stripeColor = s.subCategory.trim().isEmpty
            ? null
            : SituationalSubCategoryPalette.colorForSubCategory(
                s.subCategory,
                orderedForStripe,
                isDark,
              );
        return StaggeredEntrance(
          index: i,
          child: SituationalScriptCard(
            key: _keyForScenario(s.id),
            script: s,
            accentColor: accent,
            subCategoryStripeColor: stripeColor,
            isExpanded: _expandedScriptId == s.id,
            onExpansionChanged: (open) {
            final fromProgrammaticLink =
                open && _pendingLinkJumpId != null && s.id == _pendingLinkJumpId;
            setState(() {
              if (open) {
                if (fromProgrammaticLink) {
                  _pendingLinkJumpId = null;
                } else if (!(_linkArrivalId != null && s.id == _linkArrivalId)) {
                  _linkBackStack.clear();
                  _linkArrivalId = null;
                  _pendingLinkJumpId = null;
                }
                _expandedScriptId = s.id;
              } else if (_expandedScriptId == s.id) {
                _expandedScriptId = null;
              }
            });
            if (open) {
              if (fromProgrammaticLink) {
                _scrollExpandedIntoView(s.id);
              } else {
                _scrollExpandedIntoViewAfterUserExpand(s.id);
              }
            }
          },
          linkResolutions: _resolveLinksForScript(s, allForResolve),
          onBackFromLink: canPop ? _popLinkNavigation : null,
          backFromLinkTooltip: canPop
              ? '이전: ${_linkBackStack.last.returnLabel}'
              : null,
          ),
        );
      },
    );
  }

  void _openSearchHit(SituationalSearchHit hit) {
    final script = hit.script;
    final nextDef = categoryDefByLabel(script.category);
    if (nextDef == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('이동할 카테고리를 찾을 수 없습니다.'),
          duration: Duration(milliseconds: 1500),
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    final subs = ref.read(situationalSubCategoriesProvider(nextDef.id));
    setState(() {
      _clearScenarioCardKeys();
      _def = nextDef;
      _activeTab =
          (script.subCategory.isNotEmpty && subs.contains(script.subCategory))
              ? script.subCategory
              : _subTabAll;
      _searchOpen = false;
      _query = '';
      _searchController.clear();
      _expandedScriptId = script.id;
      _linkBackStack.clear();
      _linkArrivalId = null;
      _pendingLinkJumpId = script.id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollExpandedIntoView(script.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pendingLinkJumpId == script.id) {
          setState(() => _pendingLinkJumpId = null);
        }
      });
    });
  }

  Widget _buildSearchHitTile(
    SituationalSearchHit hit,
    String queryTrim,
    bool isDark,
  ) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final script = hit.script;
    final catDef = categoryDefByLabel(script.category);
    final categoryLabel = catDef?.label ?? script.category;
    final orderedSubsForScript = catDef != null
        ? ref.watch(situationalSubCategoriesProvider(catDef.id))
        : const <String>[];
    final stripeColor = script.subCategory.trim().isEmpty
        ? null
        : SituationalSubCategoryPalette.colorForSubCategory(
            script.subCategory,
            orderedSubsForScript,
            isDark,
          );

    final baseStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: onSurface.withValues(alpha: 0.92),
          height: 1.35,
        );
    final titleStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: onSurface,
          height: 1.25,
        );
    final hiBg = isDark
        ? UiConstants.situationalOrange.withValues(alpha: 0.42)
        : UiConstants.situationalOrange.withValues(alpha: 0.35);
    final hiStyle = baseStyle.copyWith(
      backgroundColor: hiBg,
      color: isDark ? Colors.white : UiConstants.navyInk,
      fontWeight: FontWeight.w800,
    );
    final titleHiStyle = titleStyle.copyWith(
      backgroundColor: hiBg,
      color: isDark ? Colors.white : UiConstants.navyInk,
    );

    final first = hit.matches.first;
    final snippetSpans = _highlightQueryInText(
      first.snippet,
      queryTrim,
      baseStyle,
      hiStyle,
    );
    final titleSpans = _highlightQueryInText(
      situationalSearchMaskTokens(script.scenario),
      queryTrim,
      titleStyle,
      titleHiStyle,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openSearchHit(hit),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stripeColor != null)
                Container(
                  width: 4,
                  margin: const EdgeInsets.only(right: 12, top: 2),
                  height: 44,
                  decoration: BoxDecoration(
                    color: stripeColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.labelSmall!.copyWith(
                              color: onSurface.withValues(alpha: 0.65),
                              fontWeight: FontWeight.w600,
                            ),
                        children: [
                          TextSpan(text: categoryLabel),
                          if (script.subCategory.isNotEmpty)
                            TextSpan(text: ' · ${script.subCategory}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(TextSpan(children: titleSpans)),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(children: snippetSpans),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: onSurface.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _emptyMessage() {
    if (_query.isNotEmpty) {
      return '"$_query" 에 해당하는 방송문이 없습니다.';
    }
    if (_activeTab == _subTabFavorite) {
      return '즐겨찾기한 방송문이 없습니다.\n별 아이콘을 눌러 추가해 보세요.';
    }
    if (_activeTab == _subTabRecent) {
      return '최근 사용한 방송문이 없습니다.';
    }
    return '표시할 방송문이 없습니다.';
  }
}

class _SituationalLinkFrame {
  const _SituationalLinkFrame({
    required this.category,
    this.expandedScriptId,
    required this.activeSubTab,
    this.returnLabel = '',
  });

  final SituationalCategoryDef category;
  final String? expandedScriptId;
  final String activeSubTab;
  final String returnLabel;
}

class _SubTab {
  const _SubTab({required this.id, required this.label, this.icon});
  final String id;
  final String label;
  final IconData? icon;
}

/// 홈의 `_PhaseControlChip` 톤(white 0.88 + soft outline + radius 14 + navy
/// ink)을 그대로 차용한 서브탭 칩. 다크에선 [UiConstants.situationalNavy] 대신
/// [_situationalHubReadableInk]로 활성 글자/그림자를 맞춘다.
class _SubTabChip extends StatelessWidget {
  const _SubTabChip({
    required this.tab,
    required this.active,
    this.subCategoryStripe,
    this.iconColor,
    required this.onTap,
  });

  final _SubTab tab;
  final bool active;
  final Color? subCategoryStripe;
  /// null 이면 글자색([textColor])과 동일하게 아이콘을 칠한다.
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkAccent = _situationalHubReadableInk(context);
    final stripe = subCategoryStripe;

    final Color surfaceFill;
    if (active && stripe != null) {
      final base = isDark
          ? const Color(0xFF252F3D).withValues(alpha: 0.88)
          : Colors.white.withValues(alpha: 0.97);
      surfaceFill = Color.alphaBlend(
        stripe.withValues(alpha: isDark ? 0.30 : 0.24),
        base,
      );
    } else {
      // 서브카테고리 줄무늬 없음(전체·즐겨찾기·최근): 홈 `_PhaseControlChip` 과 같이
      // 선택 시 면·테두리·그림자로 상태가 분명히 보이게 한다.
      if (isDark) {
        surfaceFill = active
            ? Colors.white.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.055);
      } else {
        surfaceFill = active
            ? Colors.white.withValues(alpha: 0.98)
            : Colors.white.withValues(alpha: 0.86);
      }
    }

    final Color outline;
    if (active && stripe != null) {
      outline = stripe.withValues(alpha: isDark ? 0.62 : 0.48);
    } else if (stripe == null) {
      outline = isDark
          ? Colors.white.withValues(alpha: active ? 0.34 : 0.11)
          : UiConstants.navyInk.withValues(alpha: active ? 0.22 : 0.11);
    } else {
      outline = isDark
          ? Colors.white.withValues(alpha: active ? 0.22 : 0.10)
          : Colors.white.withAlpha(active ? 220 : 140);
    }

    final textColor = active
        ? inkAccent
        : (isDark
            ? Colors.white.withValues(alpha: 0.78)
            : UiConstants.navyInk.withValues(alpha: 0.78));

    final List<BoxShadow>? shadows;
    if (active && stripe != null) {
      shadows = [
        BoxShadow(
          color: stripe.withValues(alpha: isDark ? 0.38 : 0.26),
          blurRadius: 10,
          spreadRadius: -3,
          offset: const Offset(0, 3),
        ),
        BoxShadow(
          color: stripe.withValues(alpha: isDark ? 0.22 : 0.12),
          blurRadius: 4,
          spreadRadius: -1,
          offset: const Offset(0, 1),
        ),
      ];
    } else if (active && stripe == null) {
      shadows = [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.38)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: isDark ? 14 : 8,
          spreadRadius: -3,
          offset: const Offset(0, 2),
        ),
      ];
    } else {
      shadows = null;
    }

    return AnimatedContainer(
      duration: UiConstants.softAnimation,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: surfaceFill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: outline,
          width: active && stripe != null
              ? 1.25
              : (active && stripe == null ? 1.15 : 1),
        ),
        boxShadow: shadows,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stripe != null) ...[
                  Container(
                    width: 3,
                    height: active ? 16 : 14,
                    decoration: BoxDecoration(
                      color: active
                          ? stripe.withValues(alpha: isDark ? 0.92 : 0.88)
                          : stripe,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (tab.icon != null) ...[
                  Icon(
                    tab.icon,
                    size: 14,
                    color: iconColor ?? textColor,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.0,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
