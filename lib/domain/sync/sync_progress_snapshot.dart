/// 스플래시·동기화 UI용 진행 상태 (0.0 ~ 1.0).
enum SyncPhase {
  initializing,
  checkingConfig,
  downloading,
  processing,
  saving,
  loadingApp,
  complete,
  /// URL 미설정 등으로 원격 동기화 생략
  cached,
  /// 네트워크 없음 등
  offline,
  error,
}

class SyncProgressSnapshot {
  const SyncProgressSnapshot({
    required this.phase,
    required this.progress,
    required this.message,
  });

  final SyncPhase phase;
  final double progress;
  final String message;

  static const initial = SyncProgressSnapshot(
    phase: SyncPhase.initializing,
    progress: 0,
    message: '시작 중...',
  );

  SyncProgressSnapshot copyWith({
    SyncPhase? phase,
    double? progress,
    String? message,
  }) {
    return SyncProgressSnapshot(
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      message: message ?? this.message,
    );
  }
}
