import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../domain/services/announcement_formatter.dart';
import '../../providers/announcement_provider.dart';
import '../../widgets/phase_audio_ui.dart';
import '../../widgets/phase_guidance_inline.dart';
import '../../widgets/modal_sheet_drag_handle.dart';
import '../../widgets/pick_one_dashed_bridge.dart';

bool _turbulenceScriptIsSelectPickCandidate(TeleprompterScript s) =>
    s.isOptional && s.optionalStartsCollapsed && s.optionalIsSelect;

(Color mid, Color edge, Color rule) _turbulenceOptionalStripColors(bool isDark) {
  final mid = isDark
      ? Colors.white.withValues(alpha: 0.038)
      : const Color(0xFFB85E0A).withValues(alpha: 0.065);
  final edge = mid.withValues(alpha: 0);
  final rule = isDark
      ? Colors.white.withValues(alpha: 0.09)
      : const Color(0xFFB85E0A).withValues(alpha: 0.22);
  return (mid, edge, rule);
}

/// Required / 택1 후보 카드 — 동일 배경·그림자 (필수 방송문 카드 톤).
BoxDecoration _turbulenceRequiredCardDecoration({
  required bool isDark,
  required Color cardBg,
}) {
  return BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: isDark
            ? const Color(0x66000000)
            : const Color(0xFFF97316).withValues(alpha: 0.14),
        blurRadius: 18,
        spreadRadius: -6,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

/// optional / 택1 그룹 상단 중앙 배지 (터뷸런스 오렌지 팔레트).
class _TurbulenceStripCenterBadge extends StatelessWidget {
  const _TurbulenceStripCenterBadge({
    required this.isDark,
    required this.label,
  });

  final bool isDark;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (optionalFillMid, _, _) = _turbulenceOptionalStripColors(isDark);
    final badgeFill = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Color.alphaBlend(
            const Color(0xFFB85E0A).withValues(alpha: 0.07),
            Colors.white.withValues(alpha: 0.97),
          );
    final badgeGradientTop =
        isDark ? const Color(0xFF2E2015) : const Color(0xFFFFF1DC);
    final badgeGradientBottom = Color.alphaBlend(
      optionalFillMid,
      badgeFill,
    );

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
          label,
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
}

abstract class _TurbulenceSegment {}

class _TurbulenceSegmentSelectGroup extends _TurbulenceSegment {
  _TurbulenceSegmentSelectGroup(this.scripts);

  final List<TeleprompterScript> scripts;
}

class _TurbulenceSegmentStandard extends _TurbulenceSegment {
  _TurbulenceSegmentStandard(this.script);

  final TeleprompterScript script;
}

/// Turbulence quick-access screen.
///
/// Triggered by the floating "TURBULENCE" button on the home screen.
/// - T1 (1차) is the default/main phase and shown immediately.
/// - T2 (2차) and T3 (서비스) are reachable via pinned one-tap buttons.
class TurbulenceScreen extends ConsumerStatefulWidget {
  const TurbulenceScreen({
    super.key,
    this.listScrollController,
  });

  /// 선택 시 본문 [ListView]와 동기화하기 위한 컨트롤러. 미전달 시 기본 스크롤.
  final ScrollController? listScrollController;

  @override
  ConsumerState<TurbulenceScreen> createState() => _TurbulenceScreenState();
}

enum _TPhase { t1, t2, t3 }

extension on _TPhase {
  String get label => switch (this) {
    _TPhase.t1 => 'Turbulence: 1차',
    _TPhase.t2 => 'Turbulence: 2차',
    _TPhase.t3 => 'Turbulence: 서비스 중단',
  };

  String get milestone => switch (this) {
    _TPhase.t1 => 'Turbulence: 1차',
    _TPhase.t2 => 'Turbulence: 2차',
    _TPhase.t3 => 'Turbulence: 서비스',
  };

  String get hint => switch (this) {
    _TPhase.t1 => '터뷸런스 시작',
    _TPhase.t2 => '장시간 지속 시',
    _TPhase.t3 => '서비스 중단 필요 시',
  };

  IconData get icon => switch (this) {
    _TPhase.t1 => Icons.waves_rounded,
    _TPhase.t2 => Icons.trending_up_rounded,
    _TPhase.t3 => Icons.no_food_outlined,
  };
}

class _TurbulenceScreenState extends ConsumerState<TurbulenceScreen>
    with SingleTickerProviderStateMixin {
  _TPhase _current = _TPhase.t1;
  late final AnimationController _switchController;

  late final AudioPlayer _audioPlayer;
  late final StreamSubscription<PlayerState> _playerStateSub;
  String? _playingAudioTag;
  bool _showAudioOverlay = false;
  String _overlayMilestone = '';
  bool _overlayIsJp = true;
  bool _showEnglish = false;

  @override
  void initState() {
    super.initState();
    _switchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
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
  }

  @override
  void dispose() {
    _playerStateSub.cancel();
    _audioPlayer.dispose();
    _switchController.dispose();
    super.dispose();
  }

  void _select(_TPhase phase) {
    if (phase == _current) return;
    unawaited(_closeAudioOverlay());
    HapticFeedback.lightImpact();
    setState(() {
      _current = phase;
      _showEnglish = false;
    });
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('오디오를 불러오지 못했습니다.')),
          );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('오디오 재생에 실패했습니다.')),
      );
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
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDark
                        ? const [
                            Color(0xFF1A1410),
                            Color(0xFF231812),
                            Color(0xFF1E1612),
                          ]
                        : const [
                            Color(0xFFFFF8EE),
                            Color(0xFFFFF1DC),
                            Color(0xFFFFE4C0),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.5 : 0.22,
                      ),
                      blurRadius: 28,
                      spreadRadius: -2,
                      offset: const Offset(0, -8),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const ModalSheetDragHandle(
                        padding: EdgeInsets.only(top: 8, bottom: 4),
                      ),
                      _TurbulenceAppBar(
                        phase: _current,
                        isDark: isDark,
                        onClose: () => Navigator.of(context).maybePop(),
                        playingAudioTag: _playingAudioTag,
                        onOpenPhaseAudio: (clip, isJp) => _openAudioOverlay(
                          phaseAudio: clip,
                          isJp: isJp,
                          milestone: _current.milestone,
                        ),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.04),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _showEnglish = !_showEnglish);
                            },
                            child: _TurbulenceContent(
                              key: ValueKey(_current),
                              phase: _current,
                              isDark: isDark,
                              scrollController: widget.listScrollController,
                              showEnglish: _showEnglish,
                            ),
                          ),
                        ),
                      ),
                      _PinnedPhaseButtons(
                        current: _current,
                        isDark: isDark,
                        onSelect: _select,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TurbulenceAppBar extends ConsumerWidget {
  const _TurbulenceAppBar({
    required this.phase,
    required this.isDark,
    required this.onClose,
    required this.playingAudioTag,
    required this.onOpenPhaseAudio,
  });

  final _TPhase phase;
  final bool isDark;
  final VoidCallback onClose;
  final String? playingAudioTag;
  final Future<void> Function(PhaseAudioClip clip, bool isJp) onOpenPhaseAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fg = isDark ? Colors.white : const Color(0xFF4A2B0A);
    final chipFg = isDark
        ? const Color(0xFFFFD489)
        : const Color(0xFFB85E0A);
    final chipBg = isDark
        ? const Color(0xFF3F2A10)
        : const Color(0xFFFFE2BA);

    final shortLabel = switch (phase) {
      _TPhase.t1 => '1차',
      _TPhase.t2 => '2차',
      _TPhase.t3 => '서비스 중단',
    };

    final phaseAudioAsync =
        ref.watch(phaseAudioForMilestoneProvider(phase.milestone));
    final phaseAudio = phaseAudioAsync.valueOrNull ?? const PhaseAudioClip();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: fg),
            tooltip: '닫기',
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                      child: Container(
                        key: ValueKey(phase),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: chipBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.waves_rounded, size: 13, color: chipFg),
                            const SizedBox(width: 5),
                            Text(
                              'TURBULENCE: $shortLabel',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: chipFg,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (phaseAudio.hasAny) ...[
                      const SizedBox(width: 10),
                      PhaseAudioPillButtons(
                        hasJp: phaseAudio.hasJp,
                        hasCn: phaseAudio.hasCn,
                        activeTag: playingAudioTag,
                        onPlayJp: () {
                          if (phaseAudio.hasJp) {
                            unawaited(onOpenPhaseAudio(phaseAudio, true));
                          }
                        },
                        onPlayCn: () {
                          if (phaseAudio.hasCn) {
                            unawaited(onOpenPhaseAudio(phaseAudio, false));
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TurbulenceContent extends ConsumerWidget {
  const _TurbulenceContent({
    super.key,
    required this.phase,
    required this.isDark,
    required this.showEnglish,
    this.scrollController,
  });

  final _TPhase phase;
  final bool isDark;
  final bool showEnglish;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scripts = ref.watch(
      formattedRoutineScriptsByMilestoneProvider(phase.milestone),
    );

    final fg = isDark ? Colors.white : const Color(0xFF2B1A07);
    final cardBg = isDark
        ? const Color(0xFF2E2015).withValues(alpha: 0.70)
        : Colors.white.withValues(alpha: 0.72);

    if (scripts.isEmpty) {
      return Center(
        child: Text(
          '${phase.label} 문안이 없습니다.',
          style: TextStyle(
            fontSize: 15,
            color: fg.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    final segments = _buildTurbulenceScriptSegments(scripts);
    return ListView.separated(
      controller: scrollController,
      primary: scrollController == null,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      itemCount: segments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, idx) {
        final seg = segments[idx];
        if (seg is _TurbulenceSegmentSelectGroup) {
          return _TurbulenceSelectPickOneBlock(
            scripts: seg.scripts,
            showEnglish: showEnglish,
            isDark: isDark,
            cardBg: cardBg,
          );
        }
        final standard = seg as _TurbulenceSegmentStandard;
        final script = standard.script;
        final announcers = collectGuidanceValues([script], (s) => s.announcer);
        final timings = collectGuidanceValues([script], (s) => s.timing);
        final etcNotes = collectGuidanceValues([script], (s) => s.etcNote);
        return _ScriptCard(
          scriptId: script.id,
          title: script.title.trim(),
          ko: _clean(script.ko),
          en: _clean(script.en),
          isOptional: script.isOptional,
          optionalStartsCollapsed: script.optionalStartsCollapsed,
          showEnglish: showEnglish,
          announcers: announcers,
          timings: timings,
          etcNotes: etcNotes,
          isDark: isDark,
          cardBg: cardBg,
        );
      },
    );
  }

  /// CSV Option `select` 연속 구간만 택1 블록으로 묶는다. hide는 개별 카드로 렌더한다.
  static List<_TurbulenceSegment> _buildTurbulenceScriptSegments(
    List<TeleprompterScript> scripts,
  ) {
    final out = <_TurbulenceSegment>[];
    var i = 0;
    while (i < scripts.length) {
      final s = scripts[i];
      if (_turbulenceScriptIsSelectPickCandidate(s)) {
        final group = <TeleprompterScript>[];
        while (i < scripts.length &&
            _turbulenceScriptIsSelectPickCandidate(scripts[i])) {
          group.add(scripts[i]);
          i++;
        }
        out.add(_TurbulenceSegmentSelectGroup(group));
      } else {
        out.add(_TurbulenceSegmentStandard(s));
        i++;
      }
    }
    return out;
  }

  /// Strips formatter sentinels + pause markers for a clean, legible render
  /// inside the turbulence modal (no inline dropdowns / flight-number hints
  /// needed in this context).
  static String _clean(String raw) {
    if (raw.isEmpty) return raw;
    return raw
        .replaceAll(AnnouncementFormatter.kInlineDelayReasonSentinel, '')
        .replaceAll(AnnouncementFormatter.kInlineFlightNumberStart, '')
        .replaceAll(AnnouncementFormatter.kInlineFlightNumberDivider, ' ')
        .replaceAll(AnnouncementFormatter.kInlineFlightNumberEnd, '')
        .replaceAll(AnnouncementFormatter.kInlineSpecialFarewellSentinel, '')
        .replaceAll(AnnouncementFormatter.kVariableEmphasisStart, '')
        .replaceAll(AnnouncementFormatter.kVariableEmphasisEnd, '')
        .replaceAll('^', '');
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// 터뷸런스: CSV `select` 연속 구간 택1 UI (단일 후보는 필수 카드와 동일하게 전개).
class _TurbulenceSelectPickOneBlock extends StatefulWidget {
  const _TurbulenceSelectPickOneBlock({
    required this.scripts,
    required this.showEnglish,
    required this.isDark,
    required this.cardBg,
  });

  final List<TeleprompterScript> scripts;
  final bool showEnglish;
  final bool isDark;
  final Color cardBg;

  @override
  State<_TurbulenceSelectPickOneBlock> createState() =>
      _TurbulenceSelectPickOneBlockState();
}

class _TurbulenceSelectPickOneBlockState extends State<_TurbulenceSelectPickOneBlock> {
  String? _expandedScriptId;

  static String? _firstTitledId(List<TeleprompterScript> scripts) {
    for (final s in scripts) {
      if (s.title.trim().isNotEmpty) {
        return s.id;
      }
    }
    return null;
  }

  void _syncExpandedToTitled(List<TeleprompterScript> filtered) {
    final titledIds =
        filtered.where((s) => s.title.trim().isNotEmpty).map((s) => s.id).toSet();
    if (titledIds.isEmpty) {
      _expandedScriptId = null;
      return;
    }
    if (_expandedScriptId == null || !titledIds.contains(_expandedScriptId)) {
      _expandedScriptId = _firstTitledId(filtered);
    }
  }

  List<TeleprompterScript> _filteredPickOneScripts() {
    return widget.scripts.where((s) {
      final ko = _TurbulenceContent._clean(s.ko);
      final en = _TurbulenceContent._clean(s.en);
      final body = widget.showEnglish ? en : ko;
      return body.trim().isNotEmpty;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _syncExpandedToTitled(_filteredPickOneScripts());
  }

  @override
  void didUpdateWidget(covariant _TurbulenceSelectPickOneBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final f = _filteredPickOneScripts();
    if (f.isEmpty) {
      _expandedScriptId = null;
      return;
    }
    _syncExpandedToTitled(f);
  }

  void _onAccordionHeaderTap(String scriptId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_expandedScriptId == scriptId) {
        _expandedScriptId = null;
      } else {
        _expandedScriptId = scriptId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPickOneScripts();

    if (filtered.isEmpty) return const SizedBox.shrink();

    if (filtered.length == 1) {
      final script = filtered.single;
      final announcers = collectGuidanceValues([script], (s) => s.announcer);
      final timings = collectGuidanceValues([script], (s) => s.timing);
      final etcNotes = collectGuidanceValues([script], (s) => s.etcNote);
      return _ScriptCard(
        scriptId: script.id,
        title: script.title.trim(),
        ko: _TurbulenceContent._clean(script.ko),
        en: _TurbulenceContent._clean(script.en),
        isOptional: false,
        optionalStartsCollapsed: false,
        showEnglish: widget.showEnglish,
        announcers: announcers,
        timings: timings,
        etcNotes: etcNotes,
        isDark: widget.isDark,
        cardBg: widget.cardBg,
      );
    }

    final onSurface = Theme.of(context).colorScheme.onSurface;
    final isDark = widget.isDark;
    final mainReadable = isDark
        ? onSurface.withValues(alpha: 0.96)
        : const Color(0xFF111111);
    final secondaryReadable = isDark
        ? onSurface.withValues(alpha: 0.86)
        : const Color(0xFF262626);

    final pickOneLabel = widget.showEnglish ? 'Pick 1' : '택 1';
    final bridgeLabel = widget.showEnglish ? 'or' : '또는';

    final (mid, edge, rule) = _turbulenceOptionalStripColors(isDark);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  edge,
                  mid,
                  mid,
                  edge,
                ],
                stops: const [0.0, 0.08, 0.92, 1.0],
              ),
              border: Border(
                top: BorderSide(color: rule),
                bottom: BorderSide(color: rule),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < filtered.length; i++) ...[
                    if (i > 0)
                      PickOneOrDashedBridge(
                        ruleColor: rule,
                        label: bridgeLabel,
                        labelStyle:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.06,
                                  color: mainReadable.withValues(alpha: 0.48),
                                ),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _PickOneOrdinalOrb(
                            ordinal: i + 1,
                            isDark: isDark,
                          ),
                        ),
                        Expanded(
                          child: Container(
                              decoration: _turbulenceRequiredCardDecoration(
                                isDark: isDark,
                                cardBg: widget.cardBg,
                              ),
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                              child: _hideTile(
                                context,
                                script: filtered[i],
                                mainReadable: mainReadable,
                                secondaryReadable: secondaryReadable,
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 1,
          child: Center(
            child: _TurbulenceStripCenterBadge(
              isDark: isDark,
              label: pickOneLabel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _hideTile(
    BuildContext context, {
    required TeleprompterScript script,
    required Color mainReadable,
    required Color secondaryReadable,
    required bool isDark,
  }) {
    final ko = _TurbulenceContent._clean(script.ko);
    final en = _TurbulenceContent._clean(script.en);
    final bodyText = widget.showEnglish ? en : ko;
    final announcers = collectGuidanceValues([script], (s) => s.announcer);
    final timings = collectGuidanceValues([script], (s) => s.timing);
    final etcNotes = collectGuidanceValues([script], (s) => s.etcNote);
    final hasGuidance =
        announcers.isNotEmpty || timings.isNotEmpty || etcNotes.isNotEmpty;

    final bodyStyle = TextStyle(
      fontSize: 20,
      height: 1.65,
      fontWeight: widget.showEnglish
          ? FontWeight.w500
          : (isDark ? FontWeight.w600 : FontWeight.w500),
      letterSpacing: widget.showEnglish ? -0.28 : -0.06,
      color: widget.showEnglish ? secondaryReadable : mainReadable,
      fontStyle: widget.showEnglish ? FontStyle.italic : FontStyle.normal,
    );

    final titleText = script.title.trim();
    if (titleText.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasGuidance) ...[
            PhaseGuidanceInline(
              announcers: announcers,
              timings: timings,
              etcNotes: etcNotes,
            ),
            const SizedBox(height: 12),
          ],
          Text(bodyText, style: bodyStyle),
        ],
      );
    }

    final expanded = script.id == _expandedScriptId;

    final headerRowCore = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            titleText,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                  letterSpacing: -0.28,
                  color: mainReadable.withValues(alpha: isDark ? 0.62 : 0.52),
                ),
          ),
        ),
        const SizedBox(width: 2),
        AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: UiConstants.softAnimation,
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.expand_more_rounded,
              size: 22,
              color: mainReadable.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onAccordionHeaderTap(script.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: headerRowCore,
            ),
          ),
        ),
        AnimatedSize(
          duration: UiConstants.softAnimation,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasGuidance) ...[
                        PhaseGuidanceInline(
                          announcers: announcers,
                          timings: timings,
                          etcNotes: etcNotes,
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(bodyText, style: bodyStyle),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _PickOneOrdinalOrb extends StatelessWidget {
  const _PickOneOrdinalOrb({
    required this.ordinal,
    required this.isDark,
  });

  final int ordinal;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Text(
      '$ordinal.',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 11.25,
            fontWeight: FontWeight.w600,
            height: 1.35,
            letterSpacing: -0.02,
            color: ink.withValues(alpha: isDark ? 0.38 : 0.42),
          ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PinnedPhaseButtons extends StatelessWidget {
  const _PinnedPhaseButtons({
    required this.current,
    required this.isDark,
    required this.onSelect,
  });

  final _TPhase current;
  final bool isDark;
  final ValueChanged<_TPhase> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Row(
        children: [
          for (var i = 0; i < _TPhase.values.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _PhaseSwitchButton(
                phase: _TPhase.values[i],
                isActive: _TPhase.values[i] == current,
                isDark: isDark,
                onTap: () => onSelect(_TPhase.values[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhaseSwitchButton extends StatelessWidget {
  const _PhaseSwitchButton({
    required this.phase,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  final _TPhase phase;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accentFg = isDark
        ? const Color(0xFFFFD489)
        : const Color(0xFFB85E0A);
    final idleFg = isDark ? Colors.white : const Color(0xFF4A2B0A);
    final idleSubFg = idleFg.withValues(alpha: 0.6);
    final idleBg = isDark
        ? const Color(0xFF2E2015).withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.90);
    final idleBorder = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFB85E0A).withValues(alpha: 0.18);

    // 1차 / 2차 / 서비스 중단 중 짧은 표기
    final shortLabel = switch (phase) {
      _TPhase.t1 => '1차',
      _TPhase.t2 => '2차',
      _TPhase.t3 => '서비스 중단',
    };

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isActive ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          decoration: BoxDecoration(
            gradient: isActive
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFB547),
                      Color(0xFFFF8A3D),
                      Color(0xFFF97316),
                    ],
                  )
                : null,
            color: isActive ? null : idleBg,
            borderRadius: BorderRadius.circular(14),
            border: isActive
                ? null
                : Border.all(color: idleBorder, width: 1),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.36),
                      blurRadius: 14,
                      spreadRadius: -2,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: isDark
                          ? const Color(0x33000000)
                          : const Color(0x14C28B3E),
                      blurRadius: 10,
                      spreadRadius: -4,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    phase.icon,
                    size: 14,
                    color: isActive ? Colors.white : accentFg,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      shortLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                        color: isActive ? Colors.white : idleFg,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                phase.hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.05,
                  color: isActive
                      ? Colors.white.withValues(alpha: 0.88)
                      : idleSubFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TurbulenceOptionalLeadingIcon extends StatelessWidget {
  const _TurbulenceOptionalLeadingIcon({
    required this.useCollapsedCue,
    required this.color,
  });

  final bool useCollapsedCue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      useCollapsedCue
          ? Icons.unfold_more_rounded
          : Icons.info_outline_rounded,
      size: 18,
      color: color,
    );
  }
}

/// 터뷸런스 모달: required / optional(필요 시). hide 는 접힘 스트립. 단일 select 는 택1 블록에서 필수 카드로 전개.
class _ScriptCard extends StatefulWidget {
  const _ScriptCard({
    required this.scriptId,
    required this.title,
    required this.ko,
    required this.en,
    required this.isOptional,
    required this.optionalStartsCollapsed,
    required this.showEnglish,
    required this.announcers,
    required this.timings,
    required this.etcNotes,
    required this.isDark,
    required this.cardBg,
  });

  final String scriptId;
  final String title;
  final String ko;
  final String en;
  final bool isOptional;
  final bool optionalStartsCollapsed;
  final bool showEnglish;
  final List<String> announcers;
  final List<String> timings;
  final List<String> etcNotes;
  final bool isDark;
  final Color cardBg;

  @override
  State<_ScriptCard> createState() => _ScriptCardState();
}

class _ScriptCardState extends State<_ScriptCard> {
  late bool _optionalExpanded;

  @override
  void initState() {
    super.initState();
    _optionalExpanded = !widget.optionalStartsCollapsed;
  }

  @override
  void didUpdateWidget(covariant _ScriptCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scriptId != widget.scriptId ||
        oldWidget.optionalStartsCollapsed != widget.optionalStartsCollapsed) {
      _optionalExpanded = !widget.optionalStartsCollapsed;
    }
  }

  void _toggleOptionalExpand() {
    HapticFeedback.selectionClick();
    setState(() => _optionalExpanded = !_optionalExpanded);
  }

  bool get _hasGuidance =>
      widget.announcers.isNotEmpty ||
      widget.timings.isNotEmpty ||
      widget.etcNotes.isNotEmpty;

  Widget _guidanceBlock() {
    return PhaseGuidanceInline(
      announcers: widget.announcers,
      timings: widget.timings,
      etcNotes: widget.etcNotes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final mainReadable = isDark
        ? onSurface.withValues(alpha: 0.96)
        : const Color(0xFF111111);
    final secondaryReadable = isDark
        ? onSurface.withValues(alpha: 0.86)
        : const Color(0xFF262626);

    final body = widget.showEnglish ? widget.en : widget.ko;
    if (body.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final bodyStyle = TextStyle(
      fontSize: 20,
      height: 1.65,
      fontWeight: widget.showEnglish
          ? FontWeight.w500
          : (isDark ? FontWeight.w600 : FontWeight.w500),
      letterSpacing: widget.showEnglish ? -0.28 : -0.06,
      color: widget.showEnglish ? secondaryReadable : mainReadable,
      fontStyle: widget.showEnglish ? FontStyle.italic : FontStyle.normal,
    );

    final scriptBody = Text(body, style: bodyStyle);

    if (!widget.isOptional) {
      return _buildRequiredCard(context, mainReadable, scriptBody);
    }

    return widget.optionalStartsCollapsed
        ? _buildOptionalCollapsedStrip(
            context,
            mainReadable,
            scriptBody,
          )
        : _buildOptionalExpandedStrip(
            context,
            mainReadable,
            scriptBody,
          );
  }

  BoxDecoration _requiredDecoration() {
    return _turbulenceRequiredCardDecoration(
      isDark: widget.isDark,
      cardBg: widget.cardBg,
    );
  }

  Widget _buildRequiredCard(
    BuildContext context,
    Color mainReadable,
    Widget scriptBody,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: _requiredDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.title.isNotEmpty) ...[
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: -0.38,
                color: mainReadable,
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (_hasGuidance) ...[
            _guidanceBlock(),
            const SizedBox(height: 12),
          ],
          scriptBody,
        ],
      ),
    );
  }

  Widget _buildOptionalExpandedStrip(
    BuildContext context,
    Color mainReadable,
    Widget scriptBody,
  ) {
    final titleText = widget.title.trim();
    final optionalLabel = widget.showEnglish ? 'As needed' : '필요 시';
    final (optionalFillMid, optionalFillEdge, optionalRuleColor) =
        _turbulenceOptionalStripColors(widget.isDark);

    final headerRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titleText.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _TurbulenceOptionalLeadingIcon(
              useCollapsedCue: false,
              color: mainReadable.withValues(alpha: 0.38),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              titleText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
                letterSpacing: -0.28,
                color: mainReadable.withValues(
                  alpha: widget.isDark ? 0.62 : 0.52,
                ),
              ),
            ),
          ),
        ],
      ],
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: DecoratedBox(
            decoration: BoxDecoration(
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
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (titleText.isNotEmpty) headerRow,
                  SizedBox(height: titleText.isNotEmpty ? 9 : 0),
                  if (_hasGuidance) ...[
                    _guidanceBlock(),
                    const SizedBox(height: 12),
                  ],
                  scriptBody,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 1,
          child: Center(
            child: _TurbulenceStripCenterBadge(
              isDark: widget.isDark,
              label: optionalLabel,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalCollapsedStrip(
    BuildContext context,
    Color mainReadable,
    Widget scriptBody,
  ) {
    final titleText = widget.title.trim();
    final optionalLabel = widget.showEnglish ? 'As needed' : '필요 시';
    final (optionalFillMid, optionalFillEdge, optionalRuleColor) =
        _turbulenceOptionalStripColors(widget.isDark);

    final headerRowCore = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _TurbulenceOptionalLeadingIcon(
            useCollapsedCue: true,
            color: mainReadable.withValues(alpha: 0.38),
          ),
        ),
        const SizedBox(width: 8),
        if (titleText.isNotEmpty)
          Expanded(
            child: Text(
              titleText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.35,
                letterSpacing: -0.28,
                color: mainReadable.withValues(
                  alpha: widget.isDark ? 0.62 : 0.52,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: Text(
              widget.showEnglish ? 'Tap to show script' : '탭하여 방송문 보기',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.35,
                color: mainReadable.withValues(alpha: 0.46),
              ),
            ),
          ),
        const SizedBox(width: 2),
        AnimatedRotation(
          turns: _optionalExpanded ? 0.5 : 0,
          duration: UiConstants.softAnimation,
          curve: Curves.easeOutCubic,
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.expand_more_rounded,
              size: 22,
              color: mainReadable.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );

    final Widget headerRow = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleOptionalExpand,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: headerRowCore,
        ),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 13),
          child: DecoratedBox(
            decoration: BoxDecoration(
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
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  headerRow,
                  AnimatedSize(
                    duration: UiConstants.softAnimation,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _optionalExpanded
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 9),
                              if (_hasGuidance) ...[
                                _guidanceBlock(),
                                const SizedBox(height: 12),
                              ],
                              scriptBody,
                            ],
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 1,
          child: Center(
            child: _TurbulenceStripCenterBadge(
              isDark: widget.isDark,
              label: optionalLabel,
            ),
          ),
        ),
      ],
    );
  }
}
