import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/models/situational_row_model.dart';
import '../../data/repositories/situational_scripts_repository.dart';
import '../../domain/entities/flight_setup.dart';
import '../../domain/entities/situational_script.dart';
import 'announcement_provider.dart';
import 'flight_setup_provider.dart';

enum SituationalCategoryKind {
  dpAnnc,
  delay,
  diversion,
  passengerIssue,
  paging,
  cabinSafety,
}

class SituationalCategoryDef {
  const SituationalCategoryDef({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.caption,
    required this.icon,
  });

  final SituationalCategoryKind id;

  /// CSV의 Category 컬럼 값과 정확히 일치해야 한다.
  final String label;

  /// 하단 Dock처럼 좁은 공간에서 쓰는 축약 라벨.
  final String shortLabel;

  /// 헤더의 eyebrow caption(영문, all-caps)으로 사용된다.
  final String caption;

  final IconData icon;
}

const situationalCategoryOrder = <SituationalCategoryDef>[
  SituationalCategoryDef(
    id: SituationalCategoryKind.dpAnnc,
    label: 'DP Annc',
    shortLabel: 'DP',
    caption: 'DUTY PURSER',
    icon: Icons.badge_rounded,
  ),
  SituationalCategoryDef(
    id: SituationalCategoryKind.delay,
    label: '지연 및 대기',
    shortLabel: '지연',
    caption: 'DELAY & HOLD',
    icon: Icons.schedule_rounded,
  ),
  SituationalCategoryDef(
    id: SituationalCategoryKind.diversion,
    label: '회항 및 항로 변경',
    shortLabel: '회항',
    caption: 'DIVERSION',
    icon: Icons.u_turn_left_rounded,
  ),
  SituationalCategoryDef(
    id: SituationalCategoryKind.passengerIssue,
    label: '승객 불편',
    shortLabel: '승객 불편',
    caption: 'PASSENGER CARE',
    icon: Icons.sentiment_dissatisfied_rounded,
  ),
  SituationalCategoryDef(
    id: SituationalCategoryKind.paging,
    label: 'Paging',
    shortLabel: 'Paging',
    caption: 'PAGING',
    icon: Icons.campaign_rounded,
  ),
  SituationalCategoryDef(
    id: SituationalCategoryKind.cabinSafety,
    label: '기내 안전',
    shortLabel: '안전',
    caption: 'CABIN SAFETY',
    icon: Icons.shield_outlined,
  ),
];

/// CSV 입력 오타(대소문자, 앞뒤 공백)에 관대하게 매칭하기 위한 정규화.
///
/// 예: "DP ANNC" / "dp annc" / " DP Annc " 모두 "dp annc" 로 정규화되어
/// `SituationalCategoryDef.label` 과 비교된다.
String _normalizeCategoryKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

SituationalCategoryDef? categoryDefByLabel(String label) {
  final target = _normalizeCategoryKey(label);
  for (final def in situationalCategoryOrder) {
    if (_normalizeCategoryKey(def.label) == target) return def;
  }
  return null;
}

final situationalRepositoryProvider = Provider<SituationalScriptsRepository>(
  (ref) => SituationalScriptsRepository(),
);

/// Master bundle에 포함된 Situational raw rows를 파싱해 반환한다.
///
/// 데이터 소스 우선순위:
///   1) Google Sheets 동기화 결과(`masterDataProvider` → bundle.situationalRows)
///   2) 번들이 비어있으면 로컬 에셋 fallback
///
/// `Condition_Tag` 가 있는 행은 Announcements/Emergency 와 동일한 규칙으로 필터되며,
/// 같은 시나리오·같은 Order 안에서는 `none` 폴백 행도 동일하게 정리된다.
final situationalScriptsProvider = FutureProvider<List<SituationalScript>>((
  ref,
) async {
  final repo = ref.watch(situationalRepositoryProvider);
  final csvRepo = ref.watch(masterDataRepositoryProvider);
  final bundle = await ref.watch(masterDataProvider.future);

  final setup =
      ref.watch(flightSetupProvider) ?? FlightSetup.emptyForConditionTags();
  final controlValues = csvRepo.effectiveUiControlValues(
    bundle,
    ref.watch(selectedControlValuesProvider),
  );

  List<SituationalRowModel> filterRows(List<SituationalRowModel> rows) {
    final origin = csvRepo.findAirportByIata(bundle, setup.originIata);
    final destination =
        csvRepo.findAirportByIata(bundle, setup.destinationIata);
    final aircraft = csvRepo.findAircraftByHlNo(bundle, setup.hlNo);
    final route = csvRepo.findRouteBySetup(bundle, setup);

    final matched = rows.where((row) {
      final tag = row.conditionTag.trim();
      if (tag.isEmpty) return true;
      return csvRepo.matchesConditionTag(
        conditionTag: tag,
        setup: setup,
        originAirport: origin,
        destinationAirport: destination,
        aircraft: aircraft,
        route: route,
        controlValues: controlValues,
      );
    }).toList();
    return csvRepo.resolveSituationalNoneConditionFallback(matched);
  }

  var scripts = const <SituationalScript>[];
  var source = 'none';

  if (bundle.situationalRows.isNotEmpty) {
    scripts = repo.parseRows(filterRows(bundle.situationalRows));
    source = 'cache(${bundle.situationalRows.length}rows)';

    // 파싱 진단: 실제로 들어온 첫 row의 값 샘플을 남긴다.
    // 모든 행이 필터링된다면 category/scenario 매핑 이슈를 바로 확인 가능.
    if (scripts.isEmpty) {
      final s = bundle.situationalRows.first;
      // ignore: avoid_print
      print(
        '[Situational] 캐시 rows 파싱 0건. 첫 row: '
        'category="${s.category}", subCategory="${s.subCategory}", '
        'scenario="${s.scenario}", order="${s.order}", title="${s.title}", '
        'optional="${s.optional}", rowType="${s.rowType}", '
        'optionGroup="${s.optionGroup}", koLen=${s.contentKo.length}, '
        'enLen=${s.contentEn.length}',
      );
    }
  }

  // 캐시가 비어있거나 파싱 결과 0건이면 asset에서 직접 재시도.
  if (scripts.isEmpty) {
    final assetRows = await repo.readRowModelsFromAsset();
    scripts = repo.parseRows(filterRows(assetRows));
    source = 'asset_fallback';
  }

  final counts = <String, int>{};
  for (final s in scripts) {
    counts[s.category] = (counts[s.category] ?? 0) + 1;
  }
  // ignore: avoid_print
  print(
    '[Situational] 파싱 완료: source=$source, total=${scripts.length}, byCategory=$counts',
  );
  return scripts;
});

final situationalScriptsByCategoryProvider =
    Provider.family<List<SituationalScript>, SituationalCategoryKind>((
      ref,
      kind,
    ) {
      final all = ref.watch(situationalScriptsProvider).valueOrNull ?? const [];
      final def = situationalCategoryOrder.firstWhere((d) => d.id == kind);
      final target = _normalizeCategoryKey(def.label);
      return all
          .where((s) => _normalizeCategoryKey(s.category) == target)
          .toList();
    });

final situationalSubCategoriesProvider =
    Provider.family<List<String>, SituationalCategoryKind>((ref, kind) {
      final scripts = ref.watch(situationalScriptsByCategoryProvider(kind));
      final seen = <String>{};
      final ordered = <String>[];
      for (final s in scripts) {
        if (seen.add(s.subCategory)) ordered.add(s.subCategory);
      }
      return ordered;
    });

class SituationalPrefsService {
  static const _boxName = 'situational_prefs';
  static const _favKey = 'favorites';
  static const _recentKey = 'recents';

  Future<Box<dynamic>> _open() => Hive.openBox<dynamic>(_boxName);

  Future<Set<String>> getFavorites() async {
    final box = await _open();
    final list = (box.get(_favKey) as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    return list.toSet();
  }

  Future<void> setFavorites(Set<String> ids) async {
    final box = await _open();
    await box.put(_favKey, ids.toList());
  }

  Future<List<String>> getRecents() async {
    final box = await _open();
    return (box.get(_recentKey) as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
  }

  Future<void> pushRecent(String id, {int max = 10}) async {
    final box = await _open();
    final list = (box.get(_recentKey) as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList();
    list.remove(id);
    list.insert(0, id);
    while (list.length > max) {
      list.removeLast();
    }
    await box.put(_recentKey, list);
  }
}

final situationalPrefsProvider = Provider<SituationalPrefsService>(
  (ref) => SituationalPrefsService(),
);

class SituationalFavoritesNotifier extends StateNotifier<Set<String>> {
  SituationalFavoritesNotifier(this._service) : super(<String>{}) {
    _load();
  }

  final SituationalPrefsService _service;

  Future<void> _load() async {
    state = await _service.getFavorites();
  }

  Future<void> toggle(String id) async {
    final next = {...state};
    if (!next.add(id)) {
      next.remove(id);
    }
    state = next;
    await _service.setFavorites(next);
  }

  bool isFavorite(String id) => state.contains(id);
}

final situationalFavoritesProvider =
    StateNotifierProvider<SituationalFavoritesNotifier, Set<String>>((ref) {
      return SituationalFavoritesNotifier(ref.watch(situationalPrefsProvider));
    });

class SituationalRecentsNotifier extends StateNotifier<List<String>> {
  SituationalRecentsNotifier(this._service) : super(const <String>[]) {
    _load();
  }

  final SituationalPrefsService _service;

  Future<void> _load() async {
    state = await _service.getRecents();
  }

  Future<void> push(String id) async {
    await _service.pushRecent(id);
    state = await _service.getRecents();
  }
}

final situationalRecentsProvider =
    StateNotifierProvider<SituationalRecentsNotifier, List<String>>((ref) {
      return SituationalRecentsNotifier(ref.watch(situationalPrefsProvider));
    });
