import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../data/services/google_sheets_sync_service.dart';
import '../../../domain/sync/sync_progress_snapshot.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/app_premium_background.dart';
import '../home/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  late final AnimationController _exitFadeController;
  late final Animation<double> _exitOpacity;
  final Completer<void> _animationDone = Completer<void>();
  var _animationCompletionRegistered = false;
  var _bootstrapStarted = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _exitFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitFadeController, curve: Curves.easeOutCubic),
    );

    _lottieController.addStatusListener(_onLottieStatus);

    // 첫 프레임이 뜬 뒤 동기화를 시작해서 로띠 초기 재생 끊김을 줄인다.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrapAfterFirstFrame());
    });
  }

  Future<void> _bootstrapAfterFirstFrame() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }
    await _bootstrap();
  }

  void _onLottieStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    if (_animationDone.isCompleted) {
      return;
    }
    _animationDone.complete();
  }

  Future<void> _bootstrap() async {
    if (_bootstrapStarted) {
      return;
    }
    _bootstrapStarted = true;

    final dataReady = _loadMasterDataInBackground();

    try {
      await Future.wait([_animationDone.future, dataReady]);
    } catch (_) {
      // defensive
    }

    if (!mounted) {
      return;
    }

    await _exitFadeController.forward();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _loadMasterDataInBackground() async {
    final svc = ref.read(syncServiceProvider) as GoogleSheetsSyncService;
    try {
      await ref.read(syncStateProvider.notifier).syncIfOnlineOnAppStart();
      svc.emitProgress(
        phase: SyncPhase.loadingApp,
        progress: 0.94,
        message: '앱 데이터 준비 중...',
      );
      final bundle = await ref.read(masterDataProvider.future);
      if (!kIsWeb) {
        svc.emitProgress(
          phase: SyncPhase.loadingApp,
          progress: 0.97,
          message: '오디오 파일 준비 중...',
        );
        await ref.read(phaseAudioCacheServiceProvider).prefetchByBundle(bundle);
      }
      svc.emitProgress(
        phase: SyncPhase.complete,
        progress: 1.0,
        message: '준비 완료!',
      );
    } catch (_) {
      try {
        svc.emitProgress(
          phase: SyncPhase.loadingApp,
          progress: 0.94,
          message: '앱 데이터 준비 중...',
        );
        final bundle = await ref.read(masterDataProvider.future);
        if (!kIsWeb) {
          svc.emitProgress(
            phase: SyncPhase.loadingApp,
            progress: 0.97,
            message: '오디오 파일 준비 중...',
          );
          await ref
              .read(phaseAudioCacheServiceProvider)
              .prefetchByBundle(bundle);
        }
      } catch (_) {}
      svc.emitProgress(
        phase: SyncPhase.complete,
        progress: 1.0,
        message: '준비 완료!',
      );
    }
  }

  void _completeAnimationOnceIfNeeded() {
    if (_animationDone.isCompleted || _animationCompletionRegistered) {
      return;
    }
    _animationCompletionRegistered = true;
    _animationDone.complete();
  }

  @override
  void dispose() {
    _lottieController.removeStatusListener(_onLottieStatus);
    _lottieController.dispose();
    _exitFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressListenable = ref.watch(syncProgressNotifierProvider);

    return Scaffold(
      body: FadeTransition(
        opacity: _exitOpacity,
        child: Stack(
          children: [
            const _SplashBackground(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RepaintBoundary(
                    child: SizedBox(
                      width: 240,
                      height: 240,
                      child: Lottie.asset(
                        'lottie/logo_animation.json',
                        controller: _lottieController,
                        repeat: false,
                        fit: BoxFit.contain,
                        onLoaded: (composition) {
                          _lottieController
                            ..duration = composition.duration
                            ..forward(from: 0);
                          if (composition.duration == Duration.zero ||
                              composition.duration.inMilliseconds <= 0) {
                            _completeAnimationOnceIfNeeded();
                          }
                        },
                        errorBuilder: (context, error, stackTrace) {
                          _completeAnimationOnceIfNeeded();
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  ValueListenableBuilder<SyncProgressSnapshot>(
                    valueListenable: progressListenable,
                    builder: (context, snap, _) {
                      return RepaintBoundary(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              snap.message,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w400,
                                    height: 1.35,
                                    letterSpacing: -0.15,
                                    color: UiConstants.navyMuted.withValues(
                                      alpha: 0.88,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 10),
                            _SplashMicroProgressBar(progress: snap.progress),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 가로 150px, 두께 2px, 글래시 배경 + 포인트 컬러 게이지 + 끝 Glow.
class _SplashMicroProgressBar extends StatelessWidget {
  const _SplashMicroProgressBar({required this.progress});

  final double progress;

  static const double _w = 150;
  static const double _h = 2;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: _w,
      height: _h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_h),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _w,
              height: _h,
              color: Colors.white.withValues(alpha: 0.42),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: p),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return SizedBox(
                    width: _w * value,
                    height: _h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  UiConstants.goOrange.withValues(alpha: 0.72),
                                  UiConstants.goOrange,
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (value > 0.02)
                          Positioned(
                            right: -4,
                            top: -5,
                            child: IgnorePointer(
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: UiConstants.goOrange.withValues(
                                        alpha: 0.65,
                                      ),
                                      blurRadius: 10,
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
      ),
    );
  }
}

class _SplashBackground extends StatelessWidget {
  const _SplashBackground();

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(child: AppPremiumBackground());
  }
}
