import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ui_constants.dart';
import '../../domain/sync/sync_progress_snapshot.dart';
import '../providers/sync_provider.dart';

/// [syncProgressNotifierProvider] 기반 진행률·단계 표시 (설정 화면 동기화 등).
class SyncProgressPanel extends ConsumerWidget {
  const SyncProgressPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listenable = ref.watch(syncProgressNotifierProvider);
    return ValueListenableBuilder<SyncProgressSnapshot>(
      valueListenable: listenable,
      builder: (context, snap, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhaseGlyph(phase: snap.phase),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Text(
                      snap.message,
                      key: ValueKey<String>(snap.message),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.2,
                        color: Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.72),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SetupSyncProgressBar(progress: snap.progress),
            const SizedBox(height: 4),
            Text(
              '${(snap.progress * 100).clamp(0, 100).round()}%',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: 0.45,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PhaseGlyph extends StatelessWidget {
  const _PhaseGlyph({required this.phase});

  final SyncPhase phase;

  IconData get _icon {
    switch (phase) {
      case SyncPhase.initializing:
        return Icons.bolt_outlined;
      case SyncPhase.checkingConfig:
        return Icons.link_outlined;
      case SyncPhase.downloading:
        return Icons.cloud_download_outlined;
      case SyncPhase.processing:
        return Icons.account_tree_outlined;
      case SyncPhase.saving:
        return Icons.save_outlined;
      case SyncPhase.loadingApp:
        return Icons.dashboard_customize_outlined;
      case SyncPhase.complete:
        return Icons.check_circle_outline;
      case SyncPhase.cached:
        return Icons.folder_open_outlined;
      case SyncPhase.offline:
        return Icons.wifi_off_rounded;
      case SyncPhase.error:
        return Icons.error_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: _MaybeSpin(
          active: phase == SyncPhase.downloading,
          child: Icon(
            _icon,
            size: 20,
            color: scheme.primary.withValues(alpha: 0.92),
          ),
        ),
      ),
    );
  }
}

class _MaybeSpin extends StatefulWidget {
  const _MaybeSpin({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_MaybeSpin> createState() => _MaybeSpinState();
}

class _MaybeSpinState extends State<_MaybeSpin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    if (widget.active) {
      _c.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _MaybeSpin oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _c.repeat();
    } else if (!widget.active && oldWidget.active) {
      _c
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return widget.child;
    }
    return RotationTransition(
      turns: _c,
      child: widget.child,
    );
  }
}

class _SetupSyncProgressBar extends StatelessWidget {
  const _SetupSyncProgressBar({required this.progress});

  final double progress;

  static const double _h = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = progress.clamp(0.0, 1.0);
    final track = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.35 : 0.42,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(_h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return SizedBox(
            height: _h,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ColoredBox(color: track),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: p),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      final vw = (w * value.clamp(0.0, 1.0)).clamp(0.0, w);
                      return SizedBox(
                        width: vw,
                        height: _h,
                        child: Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.expand,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    UiConstants.goOrange.withValues(
                                      alpha: 0.75,
                                    ),
                                    scheme.primary.withValues(alpha: 0.95),
                                  ],
                                ),
                              ),
                            ),
                            if (value > 0.03)
                              Positioned(
                                right: -3,
                                top: -4,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: UiConstants.goOrange
                                              .withValues(alpha: 0.55),
                                          blurRadius: 8,
                                          spreadRadius: 0.2,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
