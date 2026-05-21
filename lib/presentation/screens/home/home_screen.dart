import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../data/models/delay_reason_model.dart';
import '../../../data/models/ui_control_model.dart';
import '../../../domain/entities/announcement.dart';
import '../../../domain/entities/flight_setup.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/flight_setup_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../widgets/announcement_script_block.dart';
import '../../widgets/app_premium_background.dart';
import '../../widgets/static_annc_logo.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/milestone_bar.dart';
import '../../widgets/phase_audio_ui.dart';
import '../../widgets/phase_guidance_inline.dart';
import '../../widgets/quick_access_mini_popup.dart';
import '../../widgets/quick_dock.dart';
import '../../widgets/quick_modal_sheet_shell.dart';
import '../../providers/situational_provider.dart';
import '../emergency/emergency_screen.dart';
import '../setup/setup_screen.dart';
import '../situational/situational_category_hub_screen.dart';
import 'turbulence_screen.dart';

/// [HomeScreen] [AppBar.toolbarHeight]와 반드시 같게 유지 — 바디 상단 패딩 계산용.
const double _kHomeAppBarToolbarHeight = 64;

/// 헤더(앱바) 하단과 마일스톤 바 상단 사이 간격.
const double _kHomeBodyGapBelowAppBar = 6;

/// 전체화면(문안 카드 확장)일 때 상태바 살짝 아래부터 본문·종료 줄까지 두는 세로 여백.
const double _kAnnouncementFsTopComfort = 14;

/// 문안 카드 헤더 구역에서 빠르게 위로 플링하면 전체화면 진입·해제 판별.
const double _kAnnouncementFsFlingVelocity = 560;

/// 전체화면일 때 스크롤 최상단에서 아래로 당김 바운스로 카드 종료.
const double _kAnnouncementFsExitOverscroll = 36;

/// 홈·첫 실행 공통: 비행 설정을 홈 위 [showModalBottomSheet]로 연다.
///
/// [isScrollControlled] 시트 내부는 부모에 따라 높이가 `∞`이 될 수 있어
/// [FractionallySizedBox] 대신 [MediaQuery] 기반 [SizedBox]로 고정한다(웹 포함).
Future<void> showFlightSetupBottomSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: false,
    // 자동 핸들은 투명 배경·커스텀 클립과 겹쳐 시트 위로 떠 보일 수 있음 — [SetupScreen] 헤더 내부에서 그린다.
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final mq = MediaQuery.of(sheetContext);
      // 키보드 높이를 반영하지 않으면 고정 높이(화면 비율) 시트와 viewInsets 충돌로
      // 하단 '저장' 버튼이 화면 중앙까지 떠 보인다(isScrollControlled + Stack).
      final availAboveKb = mq.size.height - mq.viewInsets.bottom;
      // Padding(bottom: 시트 높이)보다 크면 레이아웃이 깨진다 → 가용 높이의 비율만 사용
      final sheetHeight = availAboveKb * 0.92;
      final surface = Theme.of(sheetContext).colorScheme.surface;
      return Padding(
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: sheetHeight,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: Material(
                color: surface,
                clipBehavior: Clip.antiAlias,
                child: const SetupScreen(),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// [flightSetupProvider] 가 비어 있을 때 — 배경·로고가 보이고 시트가 겹친다.
class _PendingFlightSetupShell extends ConsumerStatefulWidget {
  const _PendingFlightSetupShell();

  @override
  ConsumerState<_PendingFlightSetupShell> createState() =>
      _PendingFlightSetupShellState();
}

class _PendingFlightSetupShellState
    extends ConsumerState<_PendingFlightSetupShell> {
  @override
  void initState() {
    super.initState();
    // 스플래시→홈 직후 첫 프레임에 시트를 띄우면(웹 포함) 내비게이터/시트
    // 제약이 꼬여 백지·깨짐이 난다. 한 프레임 더 쉬어 레이아웃이 잡힌 뒤 연다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(showFlightSetupBottomSheet(context));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(child: AppPremiumBackground()),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const StaticAnncLogo(height: 96),
                  const SizedBox(height: 28),
                  Text(
                    '비행 정보를 입력해 주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      unawaited(showFlightSetupBottomSheet(context));
                    },
                    child: const Text('비행 설정'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Phase 세그먼트 분할·연속 select 택1 그룹 카드·ScriptBlock 본문 카드·인라인
// 드롭다운·항공편 번호 hint·변수 강조 등 announcement 시트 공용 위젯은
// `widgets/announcement_script_block.dart` 로 모두 이동했다. (Emergency 시트도
// 같은 컴포넌트를 그대로 재사용.)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Phase 제목 왼쪽 — 아주 작은 방송 느낌의 웨이브(루프 애니메이션).
class _PhaseTitleMotionLeading extends StatefulWidget {
  const _PhaseTitleMotionLeading();

  @override
  State<_PhaseTitleMotionLeading> createState() =>
      _PhaseTitleMotionLeadingState();
}

class _PhaseTitleMotionLeadingState extends State<_PhaseTitleMotionLeading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    const barCount = 4;
    const maxH = 18.0;
    const minH = 5.0;
    return Semantics(
      label: '방송 페이즈 표시',
      child: SizedBox(
        width: 16,
        height: maxH,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value * 2 * math.pi;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(barCount, (i) {
                final phase = i * 0.72;
                final wave = 0.5 + 0.5 * math.sin(t + phase);
                final h = minH + (maxH - minH) * wave;
                final a = 0.28 + 0.42 * wave;
                return Container(
                  width: 2.2,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: ink.withValues(alpha: a.clamp(0.2, 0.78)),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// Phase 스트립: 미션 모션 + 제목.
Widget _phaseStripTitleBlock({
  required BuildContext context,
  required String milestone,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    mainAxisSize: MainAxisSize.min,
    children: [
      const _PhaseTitleMotionLeading(),
      const SizedBox(width: 10),
      Text(
        milestone,
        strutStyle: StrutStyle(
          fontSize: 26,
          height: 1.15,
          forceStrutHeight: true,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
          height: 1.15,
        ),
      ),
    ],
  );
}

/// [MilestoneBar] 점 사이 연결선과 같은 리듬의 전폭 레일 (본문보다 한 톤만 구분).
Widget _phaseMilestoneConnectorRail(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final softEdge = isDark
      ? Colors.white.withValues(alpha: 0.07)
      : const Color(0xFF000000).withValues(alpha: 0.045);
  final softMid = isDark
      ? Colors.white.withValues(alpha: 0.12)
      : const Color(0xFF000000).withValues(alpha: 0.065);
  return Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Container(
      width: double.infinity,
      height: 1,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [softEdge, softMid, softEdge],
        ),
      ),
    ),
  );
}

/// [MilestoneBar] 고정 높이(36) + 카드까지 간격 — 접힘 애니메이션 시 세로만 보간한다.
const double _kApproxMilestoneBarRailHeight = 36 + 5;

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _phasePageController;
  late final AudioPlayer _audioPlayer;
  late final StreamSubscription<PlayerState> _playerStateSub;
  bool _showEnglish = false;
  String? _playingAudioTag;
  final Map<String, int> _inlineSelectionByScript = {};
  bool _showAudioOverlay = false;
  String _overlayMilestone = '';
  bool _overlayIsJp = true;

  /// 도크의 Quick Access 탭 RenderBox 좌표를 잡아 미니 팝업 anchor로 사용한다.
  final GlobalKey _quickAccessAnchorKey = GlobalKey();

  /// 문안 카드 세로 확장(헤더·마일스톤 접기) 상태. 애니메이션 종료까지 true 유지 가능.
  bool _announcementFullscreen = false;

  late final AnimationController _announcementFullscreenController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 360),
      );
  late final Animation<double> _announcementFullscreenT = CurvedAnimation(
    parent: _announcementFullscreenController,
    curve: Curves.easeInOutCubic,
  );

  /// 가로 패딩은 전환 중에도 동일하게 유지(카드 너비 일관).
  static const double _kAnnouncementHorizontalPadding = 14;

  void _setAnnouncementFullscreen(bool want) {
    final c = _announcementFullscreenController;
    if (want) {
      if (_announcementFullscreen &&
          !c.isAnimating &&
          (c.status == AnimationStatus.completed || c.value >= 1)) {
        return;
      }
      HapticFeedback.selectionClick();
      setState(() => _announcementFullscreen = true);
      unawaited(c.forward());
      return;
    }
    if (!_announcementFullscreen &&
        !c.isAnimating &&
        (c.status == AnimationStatus.dismissed || c.value <= 0)) {
      return;
    }
    HapticFeedback.selectionClick();
    c.reverse().then((_) {
      if (!mounted) return;
      setState(() => _announcementFullscreen = false);
    });
  }

  Widget _announcementFullscreenEnterIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 밝은 글래스 카드 위에서도 확실히 보이도록(이전 0.42는 회색 카드와 구분 불가했다).
    final fg = cs.onSurface.withValues(alpha: 0.72);
    return Tooltip(
      message: '전체 화면',
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(2),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        style: IconButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: Colors.transparent,
        ),
        onPressed: () => _setAnnouncementFullscreen(true),
        icon: Icon(Icons.fullscreen_outlined, size: 21, color: fg),
      ),
    );
  }

  Widget _announcementFullscreenExitIcon(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = cs.onSurface.withValues(alpha: 0.72);
    return Tooltip(
      message: '전체 화면 끝',
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.all(2),
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        style: IconButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: Colors.transparent,
        ),
        onPressed: () => _setAnnouncementFullscreen(false),
        icon: Icon(Icons.close_rounded, size: 21, color: fg),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final setup = ref.read(flightSetupProvider);
    final selected = ref.read(selectedMilestoneProvider);
    var initialPhasePage = 0;
    if (setup != null && setup.milestones.isNotEmpty) {
      final m = selected ?? setup.milestones.first;
      final ix = setup.milestones.indexOf(m);
      if (ix >= 0) {
        initialPhasePage = ix.clamp(0, setup.milestones.length - 1);
      }
    }
    _phasePageController = PageController(initialPage: initialPhasePage);

    _audioPlayer = AudioPlayer();
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed ||
          !state.playing) {
        if (!mounted || _playingAudioTag == null) {
          return;
        }
        setState(() => _playingAudioTag = null);
      }
    });

    _announcementFullscreenController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _announcementFullscreenController.dispose();
    _playerStateSub.cancel();
    _audioPlayer.dispose();
    _phasePageController.dispose();
    super.dispose();
  }

  /// [selectedMilestoneProvider] 또는 비행 설정이 바뀐 뒤에만 호출한다.
  /// 빌드마다 [PageController.jumpToPage] 하면 사용자의 가로 스와이프와 경쟁해
  /// 페이지가 중간에서 멈추고 탭 입력도 불안정해질 수 있다.
  void _jumpPhasePageToSelectionIfMisaligned() {
    final setup = ref.read(flightSetupProvider);
    if (!mounted || setup == null || setup.milestones.isEmpty) {
      return;
    }
    if (!_phasePageController.hasClients) {
      return;
    }

    final selected =
        ref.read(selectedMilestoneProvider) ?? setup.milestones.first;
    final idx = setup.milestones.indexOf(selected);
    if (idx < 0) {
      return;
    }

    final p = _phasePageController.page;
    if (p != null && p.round() == idx) {
      return;
    }

    _phasePageController.jumpToPage(idx);
  }

  void _refreshRoutineScriptTime() {
    HapticFeedback.selectionClick();
    ref.read(routineScriptRefreshTickProvider.notifier).state++;
    final now = DateTime.now();
    final stamp =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('방송문 시간을 새로고침했습니다 ($stamp)'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(flightSetupProvider);
    final selectedMilestone = ref.watch(selectedMilestoneProvider);
    final delayReasons = ref.watch(delayReasonsProvider);
    final selectedReason = ref.watch(selectedDelayReasonProvider);
    final specialFarewellOptions = ref.watch(specialFarewellOptionsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;

    if (setup == null) {
      return const _PendingFlightSetupShell();
    }
    if (setup.milestones.isEmpty) {
      return const Scaffold(body: Center(child: Text('Milestone 데이터가 없습니다.')));
    }

    final currentMilestone = selectedMilestone ?? setup.milestones.first;
    final audioReadyMilestones = <String>{};
    for (final milestone in setup.milestones) {
      final clip =
          ref.watch(phaseAudioForMilestoneProvider(milestone)).valueOrNull ??
          const PhaseAudioClip();
      if (clip.hasAny) {
        audioReadyMilestones.add(milestone);
      }
    }
    final originIata = setup.originIata.trim().toUpperCase();
    final destinationIata = setup.destinationIata.trim().toUpperCase();
    final hlRaw = setup.hlNo?.trim() ?? '';
    final hlDigitsOnly = hlRaw.toUpperCase().startsWith('HL')
        ? hlRaw.substring(2).trim()
        : hlRaw;
    final hlNoText = hlDigitsOnly.isNotEmpty ? hlDigitsOnly : '-';

    ref.listen<String?>(selectedMilestoneProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpPhasePageToSelectionIfMisaligned();
      });
    });

    ref.listen<FlightSetup?>(flightSetupProvider, (previous, next) {
      if (next == null || next.milestones.isEmpty) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpPhasePageToSelectionIfMisaligned();
      });
    });

    final mq = MediaQuery.of(context);
    final fsT = _announcementFullscreenT.value.clamp(0.0, 1.0);
    final appBarDimmed = _showAudioOverlay;

    /// 앱바·마일스톤 접힘량 — 좌우(카드 너비 인셋)는 유지하고 세로만 보간한다.
    final toolbarHeight = (_kHomeAppBarToolbarHeight * (1 - fsT)).clamp(
      0.05,
      _kHomeAppBarToolbarHeight,
    );
    final announcementBodyEdge = _kAnnouncementHorizontalPadding;
    final cardRadius =
        UiConstants.cardRadius - fsT * (UiConstants.cardRadius - 18.0);
    final cardPadding =
        EdgeInsets.lerp(
          const EdgeInsets.fromLTRB(18, 16, 18, 16),
          const EdgeInsets.fromLTRB(14, 12, 14, 12),
          fsT,
        ) ??
        const EdgeInsets.fromLTRB(18, 16, 18, 16);

    final deckTopInset =
        mq.padding.top +
        (_kHomeAppBarToolbarHeight + _kHomeBodyGapBelowAppBar) * (1 - fsT) +
        _kAnnouncementFsTopComfort * fsT;
    final deckBottomInset = 14 * fsT;
    final appBarReveal = (1 - fsT).clamp(0.0, 1.0);

    return PopScope(
      canPop: !_announcementFullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _announcementFullscreen) {
          _setAnnouncementFullscreen(false);
        }
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_announcementFullscreen) {
              _setAnnouncementFullscreen(false);
            }
          },
          const SingleActivator(
            LogicalKeyboardKey.keyE,
            control: true,
            shift: true,
          ): () =>
              _openQuickAccessPopup(context),
          const SingleActivator(
            LogicalKeyboardKey.keyE,
            meta: true,
            shift: true,
          ): () =>
              _openQuickAccessPopup(context),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              toolbarHeight: toolbarHeight,
              titleSpacing: 20,
              backgroundColor: () {
                if (appBarReveal < 0.02 || appBarDimmed) {
                  return Colors.transparent;
                }
                final barTheme = Theme.of(context).appBarTheme;
                final baseBarCol =
                    barTheme.backgroundColor ??
                    Theme.of(context).colorScheme.surface;
                return Color.lerp(Colors.transparent, baseBarCol, appBarReveal);
              }(),
              surfaceTintColor: Theme.of(context).appBarTheme.surfaceTintColor,
              elevation: Theme.of(context).appBarTheme.elevation ?? 0,
              shadowColor: Colors.transparent,
              title: IgnorePointer(
                ignoring: appBarDimmed || appBarReveal < 0.02,
                child: Opacity(
                  opacity: appBarReveal,
                  child: AnimatedOpacity(
                    opacity: appBarDimmed ? 0.18 : 1.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _openSetup(context);
                      },
                      child: Row(
                        children: [
                          const StaticAnncLogo(height: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _FlightInfoStrip(
                              flightNumber: setup.fullFlightNumber,
                              originIata: originIata,
                              destinationIata: destinationIata,
                              hlNoText: hlNoText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                IgnorePointer(
                  ignoring: appBarDimmed || appBarReveal < 0.02,
                  child: Opacity(
                    opacity: appBarReveal,
                    child: AnimatedOpacity(
                      opacity: appBarDimmed ? 0.18 : 1.0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              ref.read(themeModeProvider.notifier).toggle();
                            },
                            icon: Icon(
                              isDarkMode
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                            ),
                            tooltip: isDarkMode ? 'Light mode' : 'Dark mode',
                          ),
                          IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _openSetup(context);
                            },
                            icon: const Icon(Icons.tune_rounded),
                            tooltip: 'Setup',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            body: Stack(
              children: [
                const _AmbientBackground(),
                IgnorePointer(
                  ignoring: true,
                  child: Opacity(
                    opacity: 0.54 * fsT.clamp(0.0, 1.0),
                    child: const SizedBox.expand(
                      child: ColoredBox(color: Colors.black),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      announcementBodyEdge,
                      deckTopInset,
                      announcementBodyEdge,
                      deckBottomInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Opacity(
                          opacity: (1 - fsT).clamp(0.0, 1.0),
                          child: SizedBox(
                            height: math.max(
                              0.0,
                              _kApproxMilestoneBarRailHeight * (1 - fsT),
                            ),
                            child: ClipRect(
                              child: Align(
                                alignment: Alignment.topCenter,
                                heightFactor: 1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    MilestoneBar(
                                      milestones: setup.milestones,
                                      selected: currentMilestone,
                                      audioReadyMilestones:
                                          audioReadyMilestones,
                                      onSelect: (phase) {
                                        HapticFeedback.selectionClick();
                                        ref
                                                .read(
                                                  selectedMilestoneProvider
                                                      .notifier,
                                                )
                                                .state =
                                            phase;
                                        final nextIndex = setup.milestones
                                            .indexOf(phase);
                                        if (nextIndex >= 0 &&
                                            _phasePageController.hasClients) {
                                          // 마일 스와이프 시 애니메이션히면 손가락에 본문이 따라오지 않음 — 즉시 전환.
                                          _phasePageController.jumpToPage(
                                            nextIndex,
                                          );
                                        }
                                        setState(() => _showEnglish = false);
                                      },
                                    ),
                                    const SizedBox(height: 5),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Stack(
                            clipBehavior: Clip.none,
                            fit: StackFit.expand,
                            children: [
                              _buildAnnouncementRoutineLiquidDeck(
                                context: context,
                                setup: setup,
                                delayReasons: delayReasons,
                                selectedReason: selectedReason,
                                specialFarewellOptions: specialFarewellOptions,
                                cardRadius: cardRadius,
                                cardPadding: cardPadding,
                                liquidGlassElevate: fsT,
                                announcementFullscreenT: fsT,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showAudioOverlay)
                  PhaseAudioPlaybackOverlay(
                  player: _audioPlayer,
                  milestone: _overlayMilestone,
                  isJp: _overlayIsJp,
                  onClose: () {
                    unawaited(_closeAudioOverlay());
                  },
                  onTogglePlayback: _togglePlayback,
                  onSeekRelative: _seekRelative,
                  onSeekTo: (position) => _audioPlayer.seek(position),
                  formatDuration: _formatDuration,
                ),
                Opacity(
                  opacity: (1 - fsT).clamp(0.0, 1.0),
                  child: IgnorePointer(
                    ignoring: fsT > 0.98,
                    child: _DraggableTurbulenceFab(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        _openTurbulence(context);
                      },
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: math.max(1e-5, (1 - fsT).clamp(0.0, 1.0)),
                child: QuickDock(
                  highlightCategory: _suggestedCategoryForMilestone(
                    currentMilestone,
                  ),
                  quickAccessAnchorKey: _quickAccessAnchorKey,
                  onCategoryTap: (def) {
                    HapticFeedback.lightImpact();
                    _openCategoryHub(context, def);
                  },
                  onQuickAccessTap: () {
                    HapticFeedback.mediumImpact();
                    _openQuickAccessPopup(context);
                  },
                  onEmergencyTap: () {
                    HapticFeedback.heavyImpact();
                    _openEmergencyScreen(context);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementRoutineLiquidDeck({
    required BuildContext context,
    required FlightSetup setup,
    required List<DelayReasonModel> delayReasons,
    required DelayReasonModel? selectedReason,
    required List<String> specialFarewellOptions,
    required double cardRadius,
    required EdgeInsets cardPadding,

    /// [AnimationController] 진행도에 맞춰 글래스를 더 밝게 한다(전체화면 근처).
    required double liquidGlassElevate,

    /// 0 확대 시작 ~ 1 확대 완료. 헤더 우측에 전환·종료 버튼이 겹치며 교체된다.
    required double announcementFullscreenT,
  }) {
    final chromeT = announcementFullscreenT.clamp(0.0, 1.0);
    return LiquidGlassCard(
      borderRadius: cardRadius,
      padding: cardPadding,
      elevateStrength: liquidGlassElevate,
      child: PageView.builder(
        controller: _phasePageController,
        itemCount: setup.milestones.length,
        onPageChanged: (index) {
          ref.read(selectedMilestoneProvider.notifier).state =
              setup.milestones[index];
          setState(() => _showEnglish = false);
        },
        itemBuilder: (_, index) {
          final milestone = setup.milestones[index];
          final phaseControls = ref.watch(
            uiControlsByMilestoneProvider(milestone),
          );
          final scripts = ref.watch(
            formattedRoutineScriptsByMilestoneProvider(milestone),
          );
          final phaseAudio =
              ref
                  .watch(phaseAudioForMilestoneProvider(milestone))
                  .valueOrNull ??
              const PhaseAudioClip();
          final orderedScripts = [...scripts]
            ..sort((a, b) => a.order.compareTo(b.order));
          final phaseHasAnyEnglish = orderedScripts.any(
            (s) => s.en.trim().isNotEmpty,
          );
          final visibleScripts = _showEnglish
              ? orderedScripts.where((s) => s.en.trim().isNotEmpty).toList()
              : orderedScripts;
          final announcerGuides = collectGuidanceValues(
            visibleScripts,
            (s) => s.announcer,
          );
          final timingGuides = collectGuidanceValues(
            visibleScripts,
            (s) => s.timing,
          );
          final etcGuides = collectGuidanceValues(
            visibleScripts,
            (s) => s.etcNote,
          );
          return LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_showEnglish) {
                    HapticFeedback.selectionClick();
                    setState(() => _showEnglish = false);
                    return;
                  }
                  if (!phaseHasAnyEnglish) {
                    return;
                  }
                  HapticFeedback.selectionClick();
                  setState(() => _showEnglish = true);
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragEnd: (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (!_announcementFullscreen &&
                            v < -_kAnnouncementFsFlingVelocity) {
                          _setAnnouncementFullscreen(true);
                        } else if (_announcementFullscreen &&
                            v > _kAnnouncementFsFlingVelocity) {
                          _setAnnouncementFullscreen(false);
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: _kPhaseHeaderStripHeight,
                            width: constraints.maxWidth,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      padding: EdgeInsets.only(
                                        right: chromeT > 0.02 ? 52 : 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _phaseStripTitleBlock(
                                            context: context,
                                            milestone: milestone,
                                          ),
                                          if (phaseControls.isNotEmpty) ...[
                                            const SizedBox(width: 10),
                                            _PhaseControlsBar(
                                              showEnglish: _showEnglish,
                                              controls: phaseControls,
                                              onChanged: (key, value) {
                                                HapticFeedback.selectionClick();
                                                final next =
                                                    Map<String, String>.from(
                                                      ref.read(
                                                        selectedControlValuesProvider,
                                                      ),
                                                    );
                                                next[key] = value;
                                                ref
                                                        .read(
                                                          selectedControlValuesProvider
                                                              .notifier,
                                                        )
                                                        .state =
                                                    next;
                                              },
                                            ),
                                          ],
                                          if (phaseAudio.hasAny) ...[
                                            const SizedBox(width: 10),
                                            PhaseAudioPillButtons(
                                              hasJp: phaseAudio.hasJp,
                                              hasCn: phaseAudio.hasCn,
                                              activeTag: _playingAudioTag,
                                              onPlayJp: () => _openAudioOverlay(
                                                phaseAudio: phaseAudio,
                                                isJp: true,
                                                milestone: milestone,
                                              ),
                                              onPlayCn: () => _openAudioOverlay(
                                                phaseAudio: phaseAudio,
                                                isJp: false,
                                                milestone: milestone,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  bottom: 0,
                                  width: 52,
                                  child: Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.none,
                                      children: [
                                        IgnorePointer(
                                          ignoring: chromeT > 0.5,
                                          child: Opacity(
                                            opacity: (1 - chromeT).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            child:
                                                _announcementFullscreenEnterIcon(
                                                  context,
                                                ),
                                          ),
                                        ),
                                        IgnorePointer(
                                          ignoring: chromeT < 0.5,
                                          child: Opacity(
                                            opacity: chromeT.clamp(0.0, 1.0),
                                            child:
                                                _announcementFullscreenExitIcon(
                                                  context,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _phaseMilestoneConnectorRail(context),
                          if (announcerGuides.isNotEmpty ||
                              timingGuides.isNotEmpty ||
                              etcGuides.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            PhaseGuidanceInline(
                              announcers: announcerGuides,
                              timings: timingGuides,
                              etcNotes: etcGuides,
                            ),
                          ],
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                    Expanded(
                      child: NotificationListener<OverscrollNotification>(
                        onNotification: (OverscrollNotification n) {
                          if (!_announcementFullscreen ||
                              n.dragDetails == null) {
                            return false;
                          }
                          final atTop =
                              n.metrics.pixels <= n.metrics.minScrollExtent + 1;
                          if (atTop &&
                              n.overscroll < -_kAnnouncementFsExitOverscroll) {
                            _setAnnouncementFullscreen(false);
                            return true;
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          child: Padding(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (visibleScripts.isEmpty)
                                  Text(
                                    _showEnglish
                                        ? '해당 Phase의 영어 방송문이 없습니다.'
                                        : '해당 Phase의 방송문이 없습니다.',
                                  )
                                else
                                  Builder(
                                    builder: (context) {
                                      final segments =
                                          _buildRoutinePhaseSegments(
                                            visibleScripts,
                                          );
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (
                                            var si = 0;
                                            si < segments.length;
                                            si++
                                          ) ...[
                                            _routineAnnouncementSegment(
                                              segments[si],
                                              delayReasons: delayReasons,
                                              selectedReason: selectedReason,
                                              specialFarewellLabels:
                                                  specialFarewellOptions,
                                            ),
                                            if (si != segments.length - 1)
                                              const SizedBox(height: 6),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  SituationalCategoryKind? _suggestedCategoryForMilestone(String milestone) {
    final ms = milestone.toLowerCase();
    if (ms.contains('pushback') ||
        ms.contains('push_back') ||
        ms.contains('boarding') ||
        ms.contains('taxi-out')) {
      return SituationalCategoryKind.delay;
    }
    if (ms.contains('cruise') || ms.contains('flight')) {
      return SituationalCategoryKind.passengerIssue;
    }
    if (ms.contains('land') || ms.contains('arrival') || ms.contains('taxi')) {
      return SituationalCategoryKind.delay;
    }
    return null;
  }

  List<AnnouncementPhaseSegment> _buildRoutinePhaseSegments(
    List<TeleprompterScript> scripts,
  ) => buildAnnouncementPhaseSegments(scripts);

  Widget _routineAnnouncementSegment(
    AnnouncementPhaseSegment segment, {
    required List<DelayReasonModel> delayReasons,
    required DelayReasonModel? selectedReason,
    required List<String> specialFarewellLabels,
  }) {
    return buildAnnouncementSegmentWidget(
      segment,
      showEnglish: _showEnglish,
      delayReasons: delayReasons,
      selectedDelayReason: selectedReason,
      specialFarewellLabels: specialFarewellLabels,
      inlineSelectionByScript: _inlineSelectionByScript,
      onDelayReasonChanged: (reason) {
        HapticFeedback.selectionClick();
        ref.read(selectedDelayReasonProvider.notifier).state = reason;
      },
      onInlineOptionChangedForScript: (script, index) {
        final k = '${script.id}:${script.inlineKey}';
        setState(() {
          _inlineSelectionByScript[k] = index;
        });
      },
      onSpecialFarewellChangedForScript: (script, index) {
        final k = '${script.id}:special_farewell';
        setState(() {
          _inlineSelectionByScript[k] = index;
        });
      },
      onTimeRefresh: _refreshRoutineScriptTime,
    );
  }

  Future<void> _openCategoryHub(
    BuildContext context,
    SituationalCategoryDef category, {
    String? focusScriptId,
  }) async {
    // 풀스크린 push 대신 바텀시트로 띄워서 홈의 로고가 살짝 보이도록 한다.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      // 테마·허브 모두 장식 막대 없음. Flutter 기본 시트 손잡이도 쓰지 않는다.
      showDragHandle: false,
      builder: (_) => SituationalCategoryHubScreen(
        category: category,
        initialFocusScriptId: focusScriptId,
      ),
    );
  }

  /// 도크 Quick Access 버튼 위에 4x4 미니 팝업을 띄운다.
  ///
  /// 16개를 넘어가면 팝업 내부 PageView 로 페이지 인디케이터와 함께 가로 스와이프.
  /// 한 셀을 누르면 기존 흐름과 동일하게 `SituationalCategoryHubScreen` 을
  /// 모달로 열고 해당 시나리오를 포커스한다.
  Future<void> _openQuickAccessPopup(BuildContext context) async {
    await showQuickAccessMiniPopup(
      context: context,
      ref: ref,
      anchorKey: _quickAccessAnchorKey,
      onNavigateToScript: (script) async {
        final def = categoryDefByLabel(script.category);
        if (def == null) return;
        if (!context.mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 80));
        if (!context.mounted) return;
        await _openCategoryHub(context, def, focusScriptId: script.id);
      },
    );
  }

  /// 비상 탭 — `Emergency` 시트 바텀시트.
  Future<void> _openEmergencyScreen(BuildContext context) async {
    await EmergencyScreen.show(context);
  }

  Future<void> _openTurbulence(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      useSafeArea: false,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      sheetAnimationStyle: UiConstants.quickModalSheetAnimationStyle,
      builder: (sheetContext) {
        final viewInsets = MediaQuery.viewInsetsOf(sheetContext);
        final screenH = MediaQuery.sizeOf(sheetContext).height;
        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: QuickModalSheetShell(
            sheetContext: sheetContext,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(
                  UiConstants.quickModalSheetTopCornerRadius,
                ),
              ),
              child: SizedBox(
                height: screenH * UiConstants.quickModalSheetBodyHeightFraction,
                child: Material(
                  color: Colors.transparent,
                  clipBehavior: Clip.antiAlias,
                  child: const TurbulenceScreen(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSetup(BuildContext context) async {
    await showFlightSetupBottomSheet(context);
  }

  Future<void> _openQuickList(
    BuildContext context,
    String title,
    List<Announcement> items,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(UiConstants.pagePadding),
          child: LiquidGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: UiConstants.sectionGap),
                Expanded(
                  child: ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      return ListTile(
                        minVerticalPadding: 10,
                        title: Text(item.title),
                        subtitle: Text(item.contentKR),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _playPhaseAudio({
    required PhaseAudioClip phaseAudio,
    required bool isJp,
  }) async {
    final url = isJp ? phaseAudio.jpUrl : phaseAudio.cnUrl;
    if (url == null || url.trim().isEmpty) {
      return;
    }
    final tag = isJp ? 'jp' : 'cn';

    try {
      await _audioPlayer.stop();
      if (kIsWeb) {
        await _audioPlayer.setUrl(_toWebPlayableUrl(url));
      } else {
        final cachedBytes = isJp ? phaseAudio.jpBytes : phaseAudio.cnBytes;
        final bytes =
            cachedBytes ??
            await ref.read(phaseAudioCacheServiceProvider).getOrDownload(url);
        if (bytes == null || bytes.isEmpty) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('오디오를 불러오지 못했습니다.')));
          return;
        }
        final dataUri = Uri.dataFromBytes(
          bytes,
          mimeType: _guessContentType(url),
        );
        await _audioPlayer.setAudioSource(AudioSource.uri(dataUri));
      }
      await _audioPlayer.play();
      if (mounted) {
        setState(() => _playingAudioTag = tag);
      }
    } catch (e) {
      debugPrint('Audio playback failed: $e');
      if (!mounted) {
        return;
      }
      setState(() => _playingAudioTag = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('오디오 재생에 실패했습니다.')));
    }
  }

  Future<void> _openAudioOverlay({
    required PhaseAudioClip phaseAudio,
    required bool isJp,
    required String milestone,
  }) async {
    HapticFeedback.lightImpact();
    if (mounted) {
      setState(() {
        _showAudioOverlay = true;
        _overlayMilestone = milestone;
        _overlayIsJp = isJp;
      });
    }
    await _playPhaseAudio(phaseAudio: phaseAudio, isJp: isJp);
  }

  Future<void> _closeAudioOverlay() async {
    await _audioPlayer.stop();
    if (!mounted) {
      return;
    }
    setState(() {
      _showAudioOverlay = false;
      _playingAudioTag = null;
    });
  }

  Future<void> _togglePlayback() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
      return;
    }
    await _audioPlayer.play();
  }

  Future<void> _seekRelative(Duration offset) async {
    final current = _audioPlayer.position;
    final duration = _audioPlayer.duration ?? Duration.zero;
    var target = current + offset;
    if (target < Duration.zero) {
      target = Duration.zero;
    }
    if (duration > Duration.zero && target > duration) {
      target = duration;
    }
    await _audioPlayer.seek(target);
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _guessContentType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m4a')) {
      return 'audio/mp4';
    }
    if (lower.contains('.wav')) {
      return 'audio/wav';
    }
    if (lower.contains('.aac')) {
      return 'audio/aac';
    }
    if (lower.contains('.ogg')) {
      return 'audio/ogg';
    }
    return 'audio/mpeg';
  }

  String _toWebPlayableUrl(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl.trim());
    if (uri == null) {
      return sourceUrl;
    }
    if (!uri.host.toLowerCase().contains('dropbox.com')) {
      return sourceUrl;
    }
    final qp = Map<String, String>.from(uri.queryParameters);
    qp.remove('dl');
    qp['raw'] = '1';
    return uri.replace(queryParameters: qp).toString();
  }
}

/// Phase 제목 옆 스트립(제목·컨트롤·오디오) 고정 높이 — 컨트롤 유무와 관계없이 동일.
const double _kPhaseHeaderStripHeight = 44;

/// 알약형 컨트롤·스위치: 스트립 안에서 한 줄로 맞춘다.
class _PhaseControlSlot extends StatelessWidget {
  const _PhaseControlSlot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(alignment: Alignment.center, child: child);
  }
}

bool _isBinaryOnOffPair(List<UiControlOption> options) {
  if (options.length != 2) return false;
  final a = options[0].value.trim().toLowerCase();
  final b = options[1].value.trim().toLowerCase();
  final set = {a, b};
  if (set.containsAll({'on', 'off'})) return true;
  if (set.containsAll({'true', 'false'})) return true;
  if (set.containsAll({'yes', 'no'})) return true;
  if (set.containsAll({'0', '1'})) return true;
  return false;
}

String _phaseControlColumnLabel(UiControlModel c, bool showEnglish) {
  if (showEnglish && c.labelEn.trim().isNotEmpty) {
    return c.labelEn.trim();
  }
  if (c.labelKo.trim().isNotEmpty) return c.labelKo.trim();
  return c.controlKey;
}

class _PhaseControlsBar extends ConsumerWidget {
  const _PhaseControlsBar({
    required this.controls,
    required this.onChanged,
    required this.showEnglish,
  });

  final List<UiControlModel> controls;
  final bool showEnglish;
  final void Function(String key, String value) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedControlValuesProvider);
    return Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final control in controls)
          _PhaseControlChip(
            control: control,
            showEnglish: showEnglish,
            value: selected[control.controlKey] ?? control.defaultValue,
            onChanged: (value) => onChanged(control.controlKey, value),
          ),
      ],
    );
  }
}

class _PhaseControlChip extends StatelessWidget {
  const _PhaseControlChip({
    required this.control,
    required this.showEnglish,
    required this.value,
    required this.onChanged,
  });

  final UiControlModel control;
  final bool showEnglish;
  final String value;
  final ValueChanged<String> onChanged;

  static const EdgeInsets _pillPadding = EdgeInsets.symmetric(
    horizontal: 10,
    vertical: 5,
  );

  /// Situational 허브 알약 드롭다운과 톤을 맞춘 캡슐 + 얇은 테두리.
  BoxDecoration _pillDecoration({required bool highlight}) {
    return BoxDecoration(
      color: highlight
          ? Colors.white.withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: UiConstants.navyInk.withValues(alpha: 0.11)),
      boxShadow: highlight
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  TextStyle _pillTextStyle(BuildContext context) {
    final base =
        Theme.of(context).textTheme.labelMedium ??
        TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: UiConstants.navyInk,
        );
    return base.copyWith(
      fontWeight: FontWeight.w700,
      fontSize: 12.5,
      height: 1.15,
      color: UiConstants.navyInk,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedValue = value.trim().toLowerCase();
    final label = _phaseControlColumnLabel(control, showEnglish);
    final options = control.options;

    if (options.length >= 2 &&
        control.isToggle &&
        _isBinaryOnOffPair(options)) {
      final offValue = options.first.processedValue;
      final onValue = options.last.processedValue;
      final on = selectedValue == onValue;
      final stateLabel = on ? options.last.label : options.first.label;
      return _PhaseControlSlot(
        child: AnimatedContainer(
          duration: UiConstants.softAnimation,
          padding: _pillPadding,
          decoration: _pillDecoration(highlight: on),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  '$label · $stateLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pillTextStyle(context),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 20,
                width: 36,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: Switch.adaptive(
                    value: on,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (next) => onChanged(next ? onValue : offValue),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (options.isEmpty) {
      return const _PhaseControlSlot(child: SizedBox.shrink());
    }

    final choiceLabel = _selectedLabel(options, selectedValue);
    return _PhaseControlSlot(
      child: PopupMenuButton<String>(
        onSelected: onChanged,
        padding: EdgeInsets.zero,
        splashRadius: 16,
        itemBuilder: (context) {
          return options
              .map(
                (opt) => PopupMenuItem<String>(
                  value: opt.processedValue,
                  child: Text(opt.label),
                ),
              )
              .toList();
        },
        child: Container(
          padding: _pillPadding,
          decoration: _pillDecoration(highlight: false),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  '$label · $choiceLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _pillTextStyle(context),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.expand_more_rounded,
                size: 17,
                color: UiConstants.navyInk.withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _selectedLabel(List<UiControlOption> options, String selectedValue) {
    for (final option in options) {
      if (option.processedValue == selectedValue) {
        return option.label;
      }
    }
    return selectedValue;
  }
}

extension on UiControlOption {
  String get processedValue => value.trim().toLowerCase();
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return const AppPremiumBackground();
  }
}

class _FlightInfoStrip extends StatelessWidget {
  const _FlightInfoStrip({
    required this.flightNumber,
    required this.originIata,
    required this.destinationIata,
    required this.hlNoText,
  });

  final String flightNumber;
  final String originIata;
  final String destinationIata;
  final String hlNoText;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final labelStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.9,
      color: onSurface.withValues(alpha: 0.58),
    );
    final hlValueStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.05,
      color: onSurface.withValues(alpha: 0.92),
    );

    /// '-' 는 placeholder — 공간만 먹고 의미 없으면 HL 행을 통째로 생략
    final hasHlNo =
        hlNoText.trim().isNotEmpty &&
        hlNoText.trim() != '-' &&
        hlNoText.trim().toUpperCase() != '-';

    return Row(
      children: [
        Text('FLIGHT INFO', style: labelStyle),
        const SizedBox(width: 10),
        // 노선 알약 우선 확보(HL은 Flexible + 말줄임으로 양보)
        Expanded(
          flex: 3,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: _FlightRoutePill(
                flightNumber: flightNumber,
                originIata: originIata,
                destinationIata: destinationIata,
                isDark: isDark,
              ),
            ),
          ),
        ),
        if (hasHlNo) ...[
          const SizedBox(width: 14),
          Flexible(
            flex: 1,
            child: Row(
              children: [
                Text('HL', style: labelStyle),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hlNoText,
                    style: hlValueStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _FlightRoutePill extends StatelessWidget {
  const _FlightRoutePill({
    required this.flightNumber,
    required this.originIata,
    required this.destinationIata,
    required this.isDark,
  });

  final String flightNumber;
  final String originIata;
  final String destinationIata;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final primary = Theme.of(context).colorScheme.primary;

    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.white.withValues(alpha: 0.92);
    final dividerColor = onSurface.withValues(alpha: isDark ? 0.22 : 0.18);
    final arrowColor = primary;

    final flightStyle = TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w900,
      letterSpacing: -0.1,
      color: onSurface,
      height: 1.1,
    );
    final iataStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.3,
      color: onSurface.withValues(alpha: 0.92),
      height: 1.1,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.32)
                : primary.withValues(alpha: 0.14),
            blurRadius: 12,
            spreadRadius: -3,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(flightNumber, style: flightStyle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(width: 1, height: 14, color: dividerColor),
          ),
          Text(originIata, style: iataStyle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: arrowColor,
            ),
          ),
          Text(destinationIata, style: iataStyle),
        ],
      ),
    );
  }
}

class _DraggableTurbulenceFab extends StatefulWidget {
  const _DraggableTurbulenceFab({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DraggableTurbulenceFab> createState() =>
      _DraggableTurbulenceFabState();
}

class _DraggableTurbulenceFabState extends State<_DraggableTurbulenceFab>
    with TickerProviderStateMixin {
  // Top-left (x, y) within the Stack's box. Null → use default bottom-right.
  Offset? _position;
  Size? _fabSize;
  bool _dragging = false;
  static const double _margin = 12;

  /// Scaffold body 하단 = QuickDock 상단 — 플로팅 버튼과 도크 사이 간격.
  static const double _fabAboveDockGap = 10;

  late final AnimationController _breathController;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  void _onFabSizeMeasured(Size size) {
    if (_fabSize == size) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _fabSize = size);
    });
  }

  Offset _defaultPosition(Size canvas, Size fab) {
    // [canvas]는 Scaffold body(= [bottomNavigationBar] 위쪽)이므로 하단이 QuickDock
    // 상단과 일치한다.
    return Offset(
      canvas.width - fab.width - _margin - 4,
      canvas.height - fab.height - _fabAboveDockGap,
    );
  }

  Offset _clamp(Offset raw, Size canvas, Size fab) {
    final dx = raw.dx.clamp(_margin, canvas.width - fab.width - _margin);
    final dy = raw.dy.clamp(
      _margin,
      canvas.height - fab.height - _fabAboveDockGap,
    );
    return Offset(dx.toDouble(), dy.toDouble());
  }

  Offset _snapToEdge(Offset raw, Size canvas, Size fab) {
    // Horizontal magnetic snap to left/right edges (iOS assistive-touch style)
    final leftX = _margin;
    final rightX = canvas.width - fab.width - _margin;
    final centerX = raw.dx + fab.width / 2;
    final targetX = centerX < canvas.width / 2 ? leftX : rightX;
    return Offset(targetX.toDouble(), raw.dy);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = Size(constraints.maxWidth, constraints.maxHeight);
        final fab = _fabSize ?? const Size(148, 50);
        final position = _position == null
            ? _defaultPosition(canvas, fab)
            : _clamp(_position!, canvas, fab);

        return Stack(
          children: [
            AnimatedPositioned(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              left: position.dx,
              top: position.dy,
              child: _MeasureSize(
                onChange: _onFabSizeMeasured,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onTap,
                  onPanStart: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _dragging = true);
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      final raw =
                          (_position ?? _defaultPosition(canvas, fab)) +
                          details.delta;
                      _position = _clamp(raw, canvas, fab);
                    });
                  },
                  onPanEnd: (_) {
                    setState(() {
                      _dragging = false;
                      final snapped = _snapToEdge(
                        _position ?? _defaultPosition(canvas, fab),
                        canvas,
                        fab,
                      );
                      _position = _clamp(snapped, canvas, fab);
                    });
                    HapticFeedback.lightImpact();
                  },
                  child: AnimatedScale(
                    scale: _dragging ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOut,
                    child: _TurbulenceFabVisual(
                      breathController: _breathController,
                      dragging: _dragging,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TurbulenceFabVisual extends StatelessWidget {
  const _TurbulenceFabVisual({
    required this.breathController,
    required this.dragging,
  });

  final AnimationController breathController;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breathController,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(breathController.value);
        final glow = dragging ? 0.55 : (0.35 + 0.20 * t);
        final spread = dragging ? 5.0 : (1.5 + 2.5 * t);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withValues(alpha: glow),
                blurRadius: dragging ? 26 : 22,
                spreadRadius: spread,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFB547),
                    Color(0xFFFF8A3D),
                    Color(0xFFF97316),
                  ],
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.waves_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'TURBULENCE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Reports the intrinsic size of its [child] to [onChange] whenever it
/// changes. Used to position the FAB precisely regardless of content width.
class _MeasureSize extends StatefulWidget {
  const _MeasureSize({required this.onChange, required this.child});

  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _lastSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = context;
      final box = ctx.findRenderObject();
      if (box is RenderBox && box.hasSize) {
        final size = box.size;
        if (_lastSize != size) {
          _lastSize = size;
          widget.onChange(size);
        }
      }
    });
    return widget.child;
  }
}
