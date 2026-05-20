import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/situational_quick_access_row_model.dart';
import 'announcement_provider.dart';

/// `Situational_Quick_Access` 시트 행 목록 (동기화 번들 또는 로컬 에셋).
final situationalQuickAccessRowsProvider =
    Provider<List<SituationalQuickAccessRowModel>>((ref) {
      final bundle = ref.watch(masterDataProvider).valueOrNull;
      return bundle?.situationalQuickAccessRows ?? const [];
    });

/// Situational 허브가 열린 상태에서 바로가기로 도착한 시나리오 id (소비 후 null).
final situationalQuickAccessTargetIdProvider =
    StateProvider<String?>((ref) => null);
