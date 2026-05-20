import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/constants/ui_constants.dart';

/// 홈 Phase 스트립·터뷸런스 시트 등에서 쓰는 JP/CN 오디오 캡슐 버튼 묶음.
class PhaseAudioPillButtons extends StatelessWidget {
  const PhaseAudioPillButtons({
    super.key,
    required this.hasJp,
    required this.hasCn,
    required this.activeTag,
    required this.onPlayJp,
    required this.onPlayCn,
  });

  final bool hasJp;
  final bool hasCn;
  final String? activeTag;
  final VoidCallback onPlayJp;
  final VoidCallback onPlayCn;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (hasJp)
          _PhaseAudioPillButton(
            label: 'JP',
            playing: activeTag == 'jp',
            gradientStart: const Color(0xFFFF5E7E),
            gradientEnd: const Color(0xFFFF2D55),
            onTap: onPlayJp,
          ),
        if (hasCn)
          _PhaseAudioPillButton(
            label: 'CN',
            playing: activeTag == 'cn',
            gradientStart: const Color(0xFFFFB547),
            gradientEnd: const Color(0xFFF97316),
            onTap: onPlayCn,
          ),
      ],
    );
  }
}

class _PhaseAudioPillButton extends StatelessWidget {
  const _PhaseAudioPillButton({
    required this.label,
    required this.playing,
    required this.gradientStart,
    required this.gradientEnd,
    required this.onTap,
  });

  final String label;
  final bool playing;
  final Color gradientStart;
  final Color gradientEnd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final idleFill = isDark
        ? const Color(0xFF253142).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.92);
    final idleFg = isDark ? Colors.white : gradientEnd;
    final idleBorder = gradientEnd.withValues(alpha: isDark ? 0.45 : 0.30);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: playing
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [gradientStart, gradientEnd],
                  )
                : null,
            color: playing ? null : idleFill,
            borderRadius: BorderRadius.circular(12),
            border: playing ? null : Border.all(color: idleBorder, width: 1.1),
            boxShadow: playing
                ? [
                    BoxShadow(
                      color: gradientEnd.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 0.2,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                size: 15,
                color: playing ? Colors.white : idleFg,
              ),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: playing ? Colors.white : idleFg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phase JP/CN 오디오 재생 전체 화면 오버레이.
class PhaseAudioPlaybackOverlay extends StatelessWidget {
  const PhaseAudioPlaybackOverlay({
    super.key,
    required this.player,
    required this.milestone,
    required this.isJp,
    required this.onClose,
    required this.onTogglePlayback,
    required this.onSeekRelative,
    required this.onSeekTo,
    required this.formatDuration,
  });

  final AudioPlayer player;
  final String milestone;
  final bool isJp;
  final VoidCallback onClose;
  final Future<void> Function() onTogglePlayback;
  final Future<void> Function(Duration offset) onSeekRelative;
  final Future<void> Function(Duration position) onSeekTo;
  final String Function(Duration duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final accentColor = isJp
        ? const Color(0xFF5C88FF)
        : const Color(0xFF4FA9FF);
    final accentSoft = isJp ? const Color(0x335C88FF) : const Color(0x334FA9FF);
    final overlaySecondTone = isJp
        ? const Color(0xFF0D1A38)
        : const Color(0xFF0A1B36);
    final cardTailColor = isJp
        ? const Color(0xFFEFF4FF)
        : const Color(0xFFEFF7FF);

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.black.withValues(alpha: 0.66),
                        overlaySecondTone.withValues(alpha: 0.62),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.94),
                              cardTailColor.withValues(alpha: 0.91),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.65),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 40,
                              spreadRadius: -6,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: StreamBuilder<PlayerState>(
                          stream: player.playerStateStream,
                          builder: (context, stateSnapshot) {
                            final playerState = stateSnapshot.data;
                            final playing = playerState?.playing ?? false;
                            final processing =
                                playerState?.processingState ??
                                ProcessingState.idle;
                            final isBusy =
                                processing == ProcessingState.loading ||
                                processing == ProcessingState.buffering;

                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: accentSoft,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        isJp
                                            ? '🇯🇵 일본어 방송 재생'
                                            : '🇨🇳 중국어 방송 재생',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: accentColor,
                                            ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      onPressed: onClose,
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.white
                                            .withValues(alpha: 0.7),
                                      ),
                                      icon: const Icon(Icons.close_rounded),
                                      tooltip: '닫기',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  milestone,
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontSize: 30,
                                        fontWeight: FontWeight.w800,
                                        color: UiConstants.navyInk,
                                      ),
                                ),
                                const SizedBox(height: 16),
                                StreamBuilder<Duration?>(
                                  stream: player.durationStream,
                                  builder: (context, durationSnapshot) {
                                    final totalDuration =
                                        durationSnapshot.data ??
                                        player.duration ??
                                        Duration.zero;
                                    return StreamBuilder<Duration>(
                                      stream: player.positionStream,
                                      builder: (context, positionSnapshot) {
                                        final position =
                                            positionSnapshot.data ??
                                            Duration.zero;
                                        final maxSeconds =
                                            totalDuration.inMilliseconds > 0
                                            ? totalDuration.inMilliseconds /
                                                  1000.0
                                            : 0.0;
                                        final currentSeconds = maxSeconds > 0
                                            ? (position.inMilliseconds / 1000.0)
                                                  .clamp(0.0, maxSeconds)
                                            : 0.0;

                                        return Column(
                                          children: [
                                            SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                    activeTrackColor:
                                                        accentColor,
                                                    inactiveTrackColor:
                                                        UiConstants.navyMuted
                                                            .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                    thumbColor: accentColor,
                                                    trackHeight: 4,
                                                  ),
                                              child: Slider(
                                                value: currentSeconds,
                                                max: maxSeconds <= 0
                                                    ? 1
                                                    : maxSeconds,
                                                onChanged: maxSeconds <= 0
                                                    ? null
                                                    : (nextSeconds) {
                                                        onSeekTo(
                                                          Duration(
                                                            milliseconds:
                                                                (nextSeconds *
                                                                        1000)
                                                                    .round(),
                                                          ),
                                                        );
                                                      },
                                              ),
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  formatDuration(position),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color: UiConstants
                                                            .navyMuted,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                                const Spacer(),
                                                Text(
                                                  formatDuration(totalDuration),
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
                                                        color: UiConstants
                                                            .navyMuted,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    IconButton(
                                      onPressed: isBusy
                                          ? null
                                          : () {
                                              onSeekRelative(
                                                const Duration(seconds: -10),
                                              );
                                            },
                                      icon: const Icon(Icons.replay_10_rounded),
                                      iconSize: 28,
                                    ),
                                    const SizedBox(width: 10),
                                    FilledButton(
                                      onPressed: isBusy
                                          ? null
                                          : onTogglePlayback,
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(74, 74),
                                        shape: const CircleBorder(),
                                        backgroundColor: accentColor,
                                      ),
                                      child: isBusy
                                          ? const SizedBox(
                                              width: 26,
                                              height: 26,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.4,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Icon(
                                              playing
                                                  ? Icons.pause_rounded
                                                  : Icons.play_arrow_rounded,
                                              size: 34,
                                            ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      onPressed: isBusy
                                          ? null
                                          : () {
                                              onSeekRelative(
                                                const Duration(seconds: 10),
                                              );
                                            },
                                      icon: const Icon(
                                        Icons.forward_10_rounded,
                                      ),
                                      iconSize: 28,
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
