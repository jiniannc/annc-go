import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../../core/constants/ui_constants.dart';
import '../../../core/navigation/app_page_route.dart';
import '../../../data/services/google_sheets_sync_service.dart';
import '../../../domain/sync/sync_progress_snapshot.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/app_premium_background.dart';
import '../../widgets/static_annc_logo.dart';
import '../../widgets/sync_micro_progress_bar.dart';
import '../home/home_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  final Completer<void> _animationDone = Completer<void>();
  var _animationCompletionRegistered = false;
  var _bootstrapStarted = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);

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

    // 스플래시 자체 fade-out 은 제거 — SharedAxisTransition 이 페이지 레벨
    // 페이드를 처리하고, 로고만 [Hero] 로 따로 *날아가도록* 한다. 이렇게 하면
    // 배경·텍스트는 자연스럽게 fade through 되고 브랜드마크는 splash 중앙에서
    // home 헤더 좌측까지 끊김 없이 이어진다.
    Navigator.of(context).pushReplacement(
      appSharedAxisRoute<void>(
        builder: (_) => const HomeScreen(),
        duration: const Duration(milliseconds: 520),
        reverseDuration: const Duration(milliseconds: 360),
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progressListenable = ref.watch(syncProgressNotifierProvider);

    return Scaffold(
      body: Stack(
        children: [
          const _SplashBackground(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hero 로 home 헤더 [StaticAnncLogo] 와 연결된다. flight 동안
                // 공통 shuttle 이 *destination 로고* 를 FittedBox 안에서 렌더링
                // 하기 때문에, 인트로 Lottie 마지막 프레임 → looped StaticLogo
                // 첫 프레임의 swap 이 인지되지 않고 위치·크기만 매끄럽게 보간된다.
                Hero(
                  tag: 'annc-logo',
                  flightShuttleBuilder: anncLogoFlightShuttle,
                  child: RepaintBoundary(
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
                          Hero(
                            tag: SyncMicroProgressBar.heroTag,
                            flightShuttleBuilder: syncProgressHeroShuttle,
                            child: SyncMicroProgressBar(
                              progress: snap.progress,
                            ),
                          ),
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
