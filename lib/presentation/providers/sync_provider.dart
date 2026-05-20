import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sync_config_repository.dart';
import '../../data/services/google_sheets_sync_service.dart';
import '../../domain/services/sync_service.dart';
import '../../domain/sync/sync_progress_snapshot.dart';
import 'announcement_provider.dart';

final syncConfigRepositoryProvider = Provider<SyncConfigRepository>((ref) {
  return SyncConfigRepository();
});

final syncServiceProvider = Provider<SyncService>((ref) {
  final repository = ref.watch(masterDataRepositoryProvider);
  final configRepository = ref.watch(syncConfigRepositoryProvider);
  return GoogleSheetsSyncService(repository, configRepository);
});

/// [GoogleSheetsSyncService.syncProgress] — 스플래시 등에서 진행률 표시.
final syncProgressNotifierProvider =
    Provider<ValueNotifier<SyncProgressSnapshot>>((ref) {
  final service = ref.watch(syncServiceProvider);
  return (service as GoogleSheetsSyncService).syncProgress;
});

final syncStateProvider =
    StateNotifierProvider<SyncStateNotifier, AsyncValue<DateTime?>>(
      (ref) => SyncStateNotifier(ref),
    );

class SyncStateNotifier extends StateNotifier<AsyncValue<DateTime?>> {
  SyncStateNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadLastSyncedAt();
  }

  final Ref ref;

  Future<void> _loadLastSyncedAt() async {
    final service = ref.read(syncServiceProvider);
    try {
      final lastSyncedAt = await service.getLastSyncedAt();
      state = AsyncValue.data(lastSyncedAt);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> syncIfOnlineOnAppStart() async {
    final service = ref.read(syncServiceProvider);
    if (service is GoogleSheetsSyncService) {
      service.emitProgress(
        phase: SyncPhase.checkingConfig,
        progress: 0.06,
        message: '기재 정보 확인 중...',
      );
      if (!await service.hasConfiguredUrls()) {
        service.emitProgress(
          phase: SyncPhase.cached,
          progress: 0.85,
          message: '스프레드시트 미설정 — 저장된 데이터 사용',
        );
        state = AsyncValue.data(await service.getLastSyncedAt());
        return;
      }
      final online = await service.hasNetwork();
      if (!online) {
        service.emitProgress(
          phase: SyncPhase.offline,
          progress: 0.85,
          message: '오프라인 — 저장된 데이터 사용',
        );
        state = AsyncValue.data(await service.getLastSyncedAt());
        return;
      }
    }
    await syncNow();
  }

  Future<void> syncNow() async {
    final service = ref.read(syncServiceProvider);
    if (service is GoogleSheetsSyncService) {
      service.emitProgress(
        phase: SyncPhase.initializing,
        progress: 0,
        message: '동기화를 준비하는 중...',
      );
    }
    state = const AsyncValue.loading();
    try {
      await service.syncFromGoogleSheets();
      final lastSyncedAt = await service.getLastSyncedAt();
      ref.invalidate(masterDataProvider);
      state = AsyncValue.data(lastSyncedAt);
    } catch (e, st) {
      if (service is GoogleSheetsSyncService) {
        service.emitProgress(
          phase: SyncPhase.error,
          progress: 0.88,
          message: '동기화 실패 — 저장된 데이터로 계속합니다',
        );
      }
      state = AsyncValue.error(e, st);
    }
  }
}
