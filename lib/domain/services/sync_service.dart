abstract class SyncService {
  Future<void> syncFromGoogleSheets();
  Future<DateTime?> getLastSyncedAt();
}
