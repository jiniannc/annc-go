import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:hive/hive.dart';

import '../../core/utils/condition_tag_utils.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/entities/flight_setup.dart';
import '../models/aircraft_master_model.dart';
import '../models/airport_master_model.dart';
import '../models/announcement_model.dart';
import '../models/delay_reason_model.dart';
import '../models/master_data_bundle.dart';
import '../models/route_master_model.dart';
import '../models/situational_quick_access_row_model.dart';
import '../models/situational_row_model.dart';
import '../models/ui_control_model.dart';

class CsvMasterDataRepository {
  static const cacheBoxName = 'master_cache';
  static const cacheBundleKey = 'bundle';
  static const lastSyncedAtKey = 'last_synced_at';

  Future<MasterDataBundle> loadMasterData({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await readBundleFromCache();
      if (cached != null) {
        // 자가치유: 이전 세션에서 asset 로드 실패(예: Flutter Web asset 매니페스트
        // 미갱신으로 인한 404) 등의 이유로 situationalRows 가 비어 캐시된 경우,
        // 현재 세션에서 asset 재시도해 복구한다. 성공 시 캐시도 함께 갱신.
        if (cached.situationalRows.isEmpty) {
          final recovered = await _readSituationalRows();
          if (recovered.isNotEmpty) {
            final patched = MasterDataBundle(
              announcements: cached.announcements,
              routes: cached.routes,
              airports: cached.airports,
              aircraft: cached.aircraft,
              delayReasons: cached.delayReasons,
              uiControls: cached.uiControls,
              situationalRows: recovered,
              situationalQuickAccessRows: cached.situationalQuickAccessRows,
              emergencyAnnouncements: cached.emergencyAnnouncements,
            );
            await saveBundleToCache(patched);
            return patched;
          }
        }
        if (cached.situationalQuickAccessRows.isEmpty) {
          final recoveredQa = await _readSituationalQuickAccessRows();
          if (recoveredQa.isNotEmpty) {
            final patched = MasterDataBundle(
              announcements: cached.announcements,
              routes: cached.routes,
              airports: cached.airports,
              aircraft: cached.aircraft,
              delayReasons: cached.delayReasons,
              uiControls: cached.uiControls,
              situationalRows: cached.situationalRows,
              situationalQuickAccessRows: recoveredQa,
              emergencyAnnouncements: cached.emergencyAnnouncements,
            );
            await saveBundleToCache(patched);
            return patched;
          }
        }
        if (cached.emergencyAnnouncements.isEmpty) {
          final recoveredEmg = await _readEmergencyAnnouncements();
          if (recoveredEmg.isNotEmpty) {
            final patched = MasterDataBundle(
              announcements: cached.announcements,
              routes: cached.routes,
              airports: cached.airports,
              aircraft: cached.aircraft,
              delayReasons: cached.delayReasons,
              uiControls: cached.uiControls,
              situationalRows: cached.situationalRows,
              situationalQuickAccessRows: cached.situationalQuickAccessRows,
              emergencyAnnouncements: recoveredEmg,
            );
            await saveBundleToCache(patched);
            return patched;
          }
        }
        return cached;
      }
    }

    final announcements = await _readAnnouncements();
    final routes = await _readRoutes();
    final airports = await _readAirports();
    final aircraft = await _readAircraft();
    final delayReasons = await _readDelayReasons();
    final uiControls = await _readUiControls();
    final situationalRows = await _readSituationalRows();
    final situationalQuickAccessRows = await _readSituationalQuickAccessRows();
    final emergencyAnnouncements = await _readEmergencyAnnouncements();
    final bundle = MasterDataBundle(
      announcements: announcements,
      routes: routes,
      airports: airports,
      aircraft: aircraft,
      delayReasons: delayReasons,
      uiControls: uiControls,
      situationalRows: situationalRows,
      situationalQuickAccessRows: situationalQuickAccessRows,
      emergencyAnnouncements: emergencyAnnouncements,
    );

    await saveBundleToCache(bundle);
    return bundle;
  }

  Future<void> saveBundleToCache(
    MasterDataBundle bundle, {
    DateTime? syncedAt,
  }) async {
    final box = await Hive.openBox(cacheBoxName);
    await box.put(cacheBundleKey, _bundleToCache(bundle));
    if (syncedAt != null) {
      await box.put(lastSyncedAtKey, syncedAt.toIso8601String());
    }
  }

  Future<MasterDataBundle?> readBundleFromCache() async {
    final box = await Hive.openBox(cacheBoxName);
    if (!box.containsKey(cacheBundleKey)) {
      return null;
    }
    return _bundleFromCache(box.get(cacheBundleKey));
  }

  Future<DateTime?> readLastSyncedAt() async {
    final box = await Hive.openBox(cacheBoxName);
    final raw = box.get(lastSyncedAtKey);
    if (raw == null) {
      return null;
    }
    return DateTime.tryParse(raw.toString());
  }

  AirportMasterModel? findAirportByIata(
    MasterDataBundle bundle,
    String iataCode,
  ) {
    final key = iataCode.trim().toUpperCase();
    if (key.isEmpty) {
      return null;
    }
    for (final item in bundle.airports) {
      if (item.iataCode == key) {
        return item;
      }
    }
    return null;
  }

  AircraftMasterModel? findAircraftByHlNo(
    MasterDataBundle bundle,
    String? hlNo,
  ) {
    final key = (hlNo ?? '').trim().toUpperCase();
    if (key.isEmpty) {
      return null;
    }
    for (final item in bundle.aircraft) {
      if (item.hlNo == key) {
        return item;
      }
    }
    return null;
  }

  /// UI_Controls 기본값 + 사용자 선택값을 시트 Condition_Tag (`ctrl:` 등) 평가용으로 합친다.
  Map<String, String> effectiveUiControlValues(
    MasterDataBundle bundle,
    Map<String, String> selectedOverrides,
  ) {
    final values = <String, String>{};
    for (final c in bundle.uiControls) {
      final key = c.controlKey.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      values.putIfAbsent(key, () => c.defaultValue.trim().toLowerCase());
    }
    for (final entry in selectedOverrides.entries) {
      values[entry.key.trim().toLowerCase()] = entry.value.trim().toLowerCase();
    }
    return values;
  }

  List<String> resolveMilestones(
    MasterDataBundle bundle, {
    required String originIata,
    required String destinationIata,
  }) {
    final route = findRouteByIatas(bundle, originIata, destinationIata);
    final phaseIdToPhase = {
      for (final a in bundle.announcements) a.phaseId: a.flightPhase,
    };

    if (route != null && route.phaseSequence.isNotEmpty) {
      final mapped = route.phaseSequence
          .map((phaseId) => phaseIdToPhase[phaseId] ?? phaseId)
          .toList();
      final hasResolved = mapped.any(
        (phase) => phaseIdToPhase.containsValue(phase),
      );
      if (hasResolved) {
        return mapped;
      }
    }

    final sorted = [...bundle.announcements]
      ..sort((a, b) {
        final phase = a.phaseId.compareTo(b.phaseId);
        if (phase != 0) return phase;
        return a.order.compareTo(b.order);
      });
    final unique = <String>[];
    for (final item in sorted) {
      if (!unique.contains(item.flightPhase)) {
        unique.add(item.flightPhase);
      }
    }
    return unique;
  }

  RouteMasterModel? findRouteByIatas(
    MasterDataBundle bundle,
    String originIata,
    String destinationIata,
  ) {
    final routeId = 'R_${originIata.trim().toUpperCase()}${destinationIata.trim().toUpperCase()}';
    for (final item in bundle.routes) {
      if (item.routeId == routeId) {
        return item;
      }
    }
    return null;
  }

  RouteMasterModel? findRouteBySetup(MasterDataBundle bundle, FlightSetup setup) {
    return findRouteByIatas(bundle, setup.originIata, setup.destinationIata);
  }

  List<AnnouncementModel> buildRoutineAnnouncements(
    MasterDataBundle bundle,
    FlightSetup setup, {
    Map<String, String> controlValues = const {},
  }) {
    return buildAnnouncementsForCategory(
      bundle,
      setup,
      category: AnnouncementCategory.routine,
      controlValues: controlValues,
    );
  }

  /// 카테고리(`routine` / `emergency`)에 해당하는 행만 골라 condition tag 필터·
  /// `None` 폴백 해소·`(phaseId, order)` 정렬까지 한 번에 처리한다.
  ///
  /// 같은 파이프(`_matchCondition` + `_resolveNoneFallbackWithinSameOrder`)를
  /// Emergency도 그대로 통과시켜, 두 시트의 UX·필터 규칙을 완전히 동일하게 유지.
  List<AnnouncementModel> buildAnnouncementsForCategory(
    MasterDataBundle bundle,
    FlightSetup setup, {
    required AnnouncementCategory category,
    Map<String, String> controlValues = const {},
  }) {
    final originAirport = findAirportByIata(bundle, setup.originIata);
    final destinationAirport = findAirportByIata(bundle, setup.destinationIata);
    final aircraft = findAircraftByHlNo(bundle, setup.hlNo);
    final route = findRouteBySetup(bundle, setup);
    final source = category == AnnouncementCategory.emergency
        ? bundle.emergencyAnnouncements
        : bundle.announcements.where(
            (a) => a.category == category,
          );
    final matched = source.where((item) {
      return _matchCondition(
        announcement: item,
        setup: setup,
        originAirport: originAirport,
        destinationAirport: destinationAirport,
        aircraft: aircraft,
        route: route,
        controlValues: controlValues,
      );
    }).toList();
    final resolved = _resolveNoneFallbackWithinSameOrder(matched);
    final withTitles = _backfillTitlesFromSameOrderPeers(resolved, source);
    return withTitles..sort((a, b) {
      final p = a.phaseId.compareTo(b.phaseId);
      if (p != 0) return p;
      return a.order.compareTo(b.order);
    });
  }

  /// `Condition_Tag` 필터 때문에 `none` 등 형제 행이 빠져 Title 만 비게 된 행은,
  /// 같은 [phaseId · order · flightPhase] 에서 카탈로그에 존재하는 **아무 행이라도**
  /// 비어 있지 않은 Title 을 차용한다.
  ///
  /// (예: 필수 행에는 Title 이 있고, 기종 태그 select 행만 남았을 때 Title 컬럼이
  /// 비어 있으면 헤더/아이콘이 안 그려졌던 문제.)
  List<AnnouncementModel> _backfillTitlesFromSameOrderPeers(
    List<AnnouncementModel> matched,
    Iterable<AnnouncementModel> fullCatalog,
  ) {
    String groupKey(AnnouncementModel a) =>
        '${a.phaseId.trim()}::${a.order}::${a.flightPhase.trim()}';

    final titleByGroup = <String, String>{};
    for (final item in fullCatalog) {
      final t = item.title.trim();
      if (t.isEmpty) continue;
      titleByGroup.putIfAbsent(groupKey(item), () => t);
    }

    return matched.map((item) {
      if (item.title.trim().isNotEmpty) return item;
      final borrowed = titleByGroup[groupKey(item)];
      if (borrowed == null || borrowed.trim().isEmpty) return item;
      return AnnouncementModel(
        id: item.id,
        category: item.category,
        flightPhase: item.flightPhase,
        title: borrowed,
        contentKR: item.contentKR,
        contentEN: item.contentEN,
        phaseId: item.phaseId,
        audioJpUrl: item.audioJpUrl,
        audioCnUrl: item.audioCnUrl,
        conditionTag: item.conditionTag,
        order: item.order,
        isOptional: item.isOptional,
        optionalStartsCollapsed: item.optionalStartsCollapsed,
        optionalIsSelect: item.optionalIsSelect,
        announcer: item.announcer,
        timing: item.timing,
        etcNote: item.etcNote,
        inlineKey: item.inlineKey,
        inlineItemsKo: item.inlineItemsKo,
        inlineItemsEn: item.inlineItemsEn,
        inlineDefaultIndex: item.inlineDefaultIndex,
      );
    }).toList();
  }

  /// 같은 `phaseId + order`(및 같은 `flightPhase`) 묶음에서 `none`/빈 태그가
  /// 구체 태그 행과 **동시에** 살아남았을 때만 `none` 쪽을 제거한다.
  ///
  /// `flightPhase`(시트 Phase 컬럼) 까지 키에 넣어야 한다. 안 그러면
  /// `비상 착륙` 7번 `none` 행과 `비상 착수` 7번 `is_b737` 행처럼
  /// **페이즈가 다른데도** 동일 PhaseID·Order를 재사용한 경우 한쪽 목록만
  /// 통째로 사라지는(전역 교차 제거) 문제가 발생한다.
  List<AnnouncementModel> _resolveNoneFallbackWithinSameOrder(
    List<AnnouncementModel> items,
  ) {
    String noneFallbackGroupKey(AnnouncementModel a) =>
        '${a.phaseId.trim()}::${a.order}::${a.flightPhase.trim()}';

    final hasSpecificConditionByGroup = <String, bool>{};
    for (final item in items) {
      final key = noneFallbackGroupKey(item);
      if (!isNoneLikeConditionTag(item.conditionTag)) {
        hasSpecificConditionByGroup[key] = true;
      }
    }

    return items.where((item) {
      final key = noneFallbackGroupKey(item);
      final hasSpecificCondition = hasSpecificConditionByGroup[key] == true;
      if (!hasSpecificCondition) {
        return true;
      }
      return !isNoneLikeConditionTag(item.conditionTag);
    }).toList();
  }

  bool matchesConditionTag({
    required String? conditionTag,
    required FlightSetup setup,
    required AirportMasterModel? originAirport,
    required AirportMasterModel? destinationAirport,
    required AircraftMasterModel? aircraft,
    RouteMasterModel? route,
    Map<String, String> controlValues = const {},
  }) {
    final pseudo = AnnouncementModel(
      id: '_condition_check',
      category: AnnouncementCategory.routine,
      flightPhase: '',
      title: '',
      contentKR: '',
      contentEN: '',
      phaseId: '',
      conditionTag: conditionTag,
      order: 0,
      isOptional: false,
    );
    return _matchCondition(
      announcement: pseudo,
      setup: setup,
      originAirport: originAirport,
      destinationAirport: destinationAirport,
      aircraft: aircraft,
      route: route,
      controlValues: controlValues,
    );
  }

  /// [Situational] 시트: 같은 시나리오·같은 [Order] 에서 조건 매칭 후 `none`/빈 태그
  /// 행과 구체 태그 행이 **함께** 남아 있으면 `none` 쪽만 제거한다.
  ///
  /// Announcements [_resolveNoneFallbackWithinSameOrder] 와 같은 의도이다.
  List<SituationalRowModel> resolveSituationalNoneConditionFallback(
    List<SituationalRowModel> rows,
  ) {
    String scenarioForKey(SituationalRowModel r) {
      final scenarioRaw = r.scenario.trim();
      final sectionTitleRaw = r.title.trim();
      return scenarioRaw.isNotEmpty ? scenarioRaw : sectionTitleRaw;
    }

    String groupKey(SituationalRowModel r) =>
        '${r.category.trim()}::${r.subCategory.trim()}::'
        '${scenarioForKey(r)}::${r.order.trim()}';

    final hasSpecificConditionByGroup = <String, bool>{};
    for (final row in rows) {
      final key = groupKey(row);
      if (!isNoneLikeConditionTag(row.conditionTag)) {
        hasSpecificConditionByGroup[key] = true;
      }
    }

    return rows.where((row) {
      final key = groupKey(row);
      final hasSpecificCondition = hasSpecificConditionByGroup[key] == true;
      if (!hasSpecificCondition) {
        return true;
      }
      return !isNoneLikeConditionTag(row.conditionTag);
    }).toList();
  }

  bool _matchCondition({
    required AnnouncementModel announcement,
    required FlightSetup setup,
    required AirportMasterModel? originAirport,
    required AirportMasterModel? destinationAirport,
    required AircraftMasterModel? aircraft,
    required RouteMasterModel? route,
    required Map<String, String> controlValues,
  }) {
    final selectedSpecialTag = normalizeConditionTag(setup.specialWelcomeTag);
    final hasSpecialWelcomeSelected =
        selectedSpecialTag.isNotEmpty && selectedSpecialTag != 'none';

    // 스페셜 웰컴이 선택되면 기본 환영 인사는 제외한다.
    if (hasSpecialWelcomeSelected && _isDefaultWelcomeGreeting(announcement)) {
      return false;
    }

    final tags = _splitCompositeTags(announcement.conditionTag);
    if (tags.isEmpty) {
      return true;
    }
    for (final tag in tags) {
      if (!_matchSingleCondition(
        tag: tag,
        setup: setup,
        originAirport: originAirport,
        destinationAirport: destinationAirport,
        aircraft: aircraft,
        route: route,
        controlValues: controlValues,
      )) {
        return false;
      }
    }
    return true;
  }

  List<String> _splitCompositeTags(String? rawConditionTag) {
    final raw = (rawConditionTag ?? '').trim();
    if (raw.isEmpty || raw.toLowerCase() == 'none') {
      return const [];
    }
    final joinedByOperator = raw
        .split(RegExp(r'\s*(?:&&|&|,|\+)\s*'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (joinedByOperator.length > 1) {
      return joinedByOperator;
    }

    // 예: is_SeatbeltSign_Off_is_ISPS -> [is_seatbeltsign_off, is_isps]
    final glued = raw
        .split(RegExp(r'_(?=(?:is|has)_)'))
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (glued.length > 1) {
      return glued;
    }
    return [raw];
  }

  bool _matchSingleCondition({
    required String tag,
    required FlightSetup setup,
    required AirportMasterModel? originAirport,
    required AirportMasterModel? destinationAirport,
    required AircraftMasterModel? aircraft,
    required RouteMasterModel? route,
    required Map<String, String> controlValues,
  }) {
    final rawTag = tag.trim();
    if (rawTag.isEmpty) {
      return true;
    }

    final ctrl = _parseControlCondition(rawTag);
    if (ctrl != null) {
      final key = ctrl.$1;
      final expected = ctrl.$2;
      final selected = controlValues[key]?.trim().toLowerCase();
      return selected == expected;
    }

    final normalizedTag = normalizeConditionTag(rawTag);
    switch (normalizedTag) {
      case 'is_codeshare':
        return setup.isCodeshare;
      case 'is_notcodeshare':
        return !setup.isCodeshare;
      case 'is_military':
      case 'is_destination_military':
        return destinationAirport?.isMilitary == true;
      case 'is_origin_military':
        return originAirport?.isMilitary == true;
      case 'is_any_military':
        return (originAirport?.isMilitary == true) ||
            (destinationAirport?.isMilitary == true);
      case 'is_both_military':
        return (originAirport?.isMilitary == true) &&
            (destinationAirport?.isMilitary == true);
      case 'is_guam':
        return setup.destinationIata.toUpperCase() == 'GUM';
      case 'is_shorthaul':
        return _normalizeToken(route?.haul) == 'short';
      case 'is_mediumhaul':
        return _normalizeToken(route?.haul) == 'medium';
      case 'is_longhaul':
        return _normalizeToken(route?.haul) == 'long';
      case 'is_international':
        return _normalizeToken(route?.internationalDomestic) == 'international';
      case 'is_domestic':
        return _normalizeToken(route?.internationalDomestic) == 'domestic';
      case 'is_outbound':
        return _normalizeToken(route?.outInbound) == 'outbound';
      case 'is_inbound':
        return _normalizeToken(route?.outInbound) == 'inbound';
      case 'is_timezone_diff':
      case 'is_timezonediff':
        return _hasTimezoneDifference(originAirport, destinationAirport);
      case 'is_same_timezone':
      case 'is_timezone_same':
        return _hasSameTimezone(originAirport, destinationAirport);
      case 'is_delayed':
        return true;
      case 'has_footrest':
        return aircraft?.hasFootrest == true;
      case 'has_isps':
      case 'is_isps':
        return aircraft?.hasIsps == true;
      case 'has_wifi':
        return aircraft?.hasWifi == true;
      case 'is_one_chamber':
        return aircraft != null &&
            parseLifevestKind(aircraft.lifevest) == LifevestChamberKind.oneChamber;
      case 'is_two_chamber':
        return aircraft != null &&
            parseLifevestKind(aircraft.lifevest) == LifevestChamberKind.twoChamber;
      case 'is_seatbeltsign_on':
      case 'is_seatbelt_sign_on':
        return (controlValues['seatbelt_sign'] ?? 'on') == 'on';
      case 'is_seatbeltsign_off':
      case 'is_seatbelt_sign_off':
        return (controlValues['seatbelt_sign'] ?? 'on') == 'off';
      default:
        if (isSpecialWelcomeTag(tag)) {
          return normalizeConditionTag(setup.specialWelcomeTag) == normalizedTag;
        }
        final aircraftMatch = _tryMatchAircraftModelConditionTag(
          normalizedTag,
          aircraft,
        );
        if (aircraftMatch != null) {
          return aircraftMatch;
        }
        final countryTag = 'is_${_normalizeToken(route?.country)}';
        if (_normalizeToken(route?.country).isNotEmpty &&
            normalizedTag.startsWith('is_')) {
          return normalizedTag == countryTag;
        }
        return true;
    }
  }

  /// `is_b737`, `is_b777_200` 등 — 기종명을 [_normalizeToken] 했을 때 접두·전체 일치로 매칭한다.
  ///
  /// 접미사에 숫자가 있을 때만 기종 태그로 간주해 `is_delayed` 등과 충돌하지 않게 한다.
  bool? _tryMatchAircraftModelConditionTag(
    String normalizedTag,
    AircraftMasterModel? aircraft,
  ) {
    if (!normalizedTag.startsWith('is_') || normalizedTag.length <= 3) {
      return null;
    }
    final suffix = normalizedTag.substring(3);
    if (suffix.isEmpty || !RegExp(r'\d').hasMatch(suffix)) {
      return null;
    }

    if (aircraft == null) return false;

    final modelNorm = _normalizeToken(aircraft.model);
    if (modelNorm.isEmpty) return false;

    if (modelNorm == suffix) return true;
    if (modelNorm.startsWith('${suffix}_')) return true;
    if (suffix.startsWith('${modelNorm}_')) return true;
    return false;
  }

  String _normalizeToken(String? value) {
    final raw = (value ?? '').trim().toLowerCase();
    if (raw.isEmpty) {
      return '';
    }
    return raw
        .replaceAll(RegExp(r'[\s\-/]+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  (String, String)? _parseControlCondition(String rawTag) {
    final lower = rawTag.trim().toLowerCase();
    final m = RegExp(r'^ctrl:([a-z0-9_]+)\s*=\s*([a-z0-9_]+)$').firstMatch(
      lower,
    );
    if (m == null) {
      return null;
    }
    final key = m.group(1)!.trim();
    final value = m.group(2)!.trim();
    return (key, value);
  }

  bool _hasTimezoneDifference(
    AirportMasterModel? originAirport,
    AirportMasterModel? destinationAirport,
  ) {
    final origin = _parseTimezoneOffset(originAirport?.timeZone);
    final destination = _parseTimezoneOffset(destinationAirport?.timeZone);
    if (origin == null || destination == null) {
      return false;
    }
    return origin != destination;
  }

  bool _hasSameTimezone(
    AirportMasterModel? originAirport,
    AirportMasterModel? destinationAirport,
  ) {
    final origin = _parseTimezoneOffset(originAirport?.timeZone);
    final destination = _parseTimezoneOffset(destinationAirport?.timeZone);
    if (origin == null || destination == null) {
      return false;
    }
    return origin == destination;
  }

  Duration? _parseTimezoneOffset(String? rawTz) {
    final raw = (rawTz ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    final normalized = raw
        .toUpperCase()
        .replaceAll('UTC', '')
        .replaceAll('GMT', '')
        .replaceAll(' ', '');
    final signed = RegExp(r'^([+-])(\d{1,2})(?::?(\d{2}))?$').firstMatch(
      normalized,
    );
    if (signed != null) {
      final sign = signed.group(1) == '-' ? -1 : 1;
      final hour = int.tryParse(signed.group(2) ?? '') ?? 0;
      final minute = int.tryParse(signed.group(3) ?? '0') ?? 0;
      return Duration(hours: sign * hour, minutes: sign * minute);
    }
    final onlyHour = RegExp(r'^(\d{1,2})$').firstMatch(normalized);
    if (onlyHour != null) {
      final hour = int.tryParse(onlyHour.group(1) ?? '') ?? 0;
      return Duration(hours: hour);
    }
    return null;
  }

  bool _isDefaultWelcomeGreeting(AnnouncementModel announcement) {
    final phase = announcement.flightPhase.trim().toLowerCase();
    final title = announcement.title.trim().toLowerCase();
    if (phase != 'welcome') {
      return false;
    }
    return title.contains('환영 인사') && title.contains('기본');
  }

  Future<List<AnnouncementModel>> _readAnnouncements() async {
    final rows = await _readCsvRows('assets/data/annc_go - Announcements.csv');
    final list = <AnnouncementModel>[];
    for (var i = 0; i < rows.length; i++) {
      list.add(AnnouncementModel.fromCsvMap(rows[i], index: i + 1));
    }
    return list;
  }

  /// `Emergency` 시트 (Announcements와 동일 컬럼). asset이 아직 없을 수도 있어
  /// `_readCsvRowsOptional` 로 안전하게 로드한다.
  Future<List<AnnouncementModel>> _readEmergencyAnnouncements() async {
    final rows = await _readCsvRowsOptional('assets/data/annc_go - Emergency.csv');
    final list = <AnnouncementModel>[];
    for (var i = 0; i < rows.length; i++) {
      list.add(
        AnnouncementModel.fromCsvMap(
          rows[i],
          index: i + 1,
          category: AnnouncementCategory.emergency,
        ),
      );
    }
    return list;
  }

  Future<List<RouteMasterModel>> _readRoutes() async {
    final rows = await _readCsvRows('assets/data/annc_go - Route_Master.csv');
    return rows.map(RouteMasterModel.fromCsvMap).toList();
  }

  Future<List<AirportMasterModel>> _readAirports() async {
    final rows = await _readCsvRows(
      'assets/data/annc_go - Airports_Master.csv',
    );
    return rows.map(AirportMasterModel.fromCsvMap).toList();
  }

  Future<List<AircraftMasterModel>> _readAircraft() async {
    final rows = await _readCsvRows(
      'assets/data/annc_go - Aircraft_Master.csv',
    );
    return rows.map(AircraftMasterModel.fromCsvMap).toList();
  }

  Future<List<DelayReasonModel>> _readDelayReasons() async {
    final rows = await _readCsvRows(
      'assets/data/annc_go - Delay_Reasons(routine).csv',
    );
    return [
      for (var i = 0; i < rows.length; i++)
        DelayReasonModel.fromCsvMap(rows[i], index: i + 1),
    ];
  }

  Future<List<UiControlModel>> _readUiControls() async {
    final rows = await _readCsvRowsOptional('assets/data/annc_go - UI_Controls.csv');
    return rows
        .map(UiControlModel.fromCsvMap)
        .where((c) => c.controlKey.isNotEmpty && c.phaseId.isNotEmpty)
        .toList()
      ..sort((a, b) {
        final p = a.phaseId.compareTo(b.phaseId);
        if (p != 0) return p;
        return a.order.compareTo(b.order);
      });
  }

  Future<List<SituationalRowModel>> _readSituationalRows() async {
    const assetPath = 'assets/data/annc_go - Situational.csv';
    try {
      final maps = await _readCsvRows(assetPath);
      final rows = maps.map(SituationalRowModel.fromCsvMap).toList();
      // ignore: avoid_print
      print('[Situational] asset 로드 성공: ${rows.length} rows');
      return rows;
    } catch (e) {
      // ignore: avoid_print
      print('[Situational] asset 로드 실패 ($assetPath): $e');
      return const [];
    }
  }

  Future<List<SituationalQuickAccessRowModel>>
  _readSituationalQuickAccessRows() async {
    const assetPath = 'assets/data/annc_go - Situational_Quick_Access.csv';
    try {
      final maps = await _readCsvRows(assetPath);
      return maps
          .map(SituationalQuickAccessRowModel.fromCsvMap)
          .where((r) => !r.isEmpty)
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('[SituationalQuickAccess] asset 로드 실패 ($assetPath): $e');
      return const [];
    }
  }

  Future<List<Map<String, String>>> _readCsvRows(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final csv = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(raw);
    if (csv.isEmpty) {
      return const [];
    }

    final header = csv.first.map((e) {
      var s = e.toString();
      // Google Sheets 등에서 export된 CSV 첫 셀에 UTF-8 BOM(\uFEFF)이 붙으면
      // row['Category'] 같은 key 접근이 전부 null로 빠져서 모든 행이 무시된다.
      if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
        s = s.substring(1);
      }
      return s.trim();
    }).toList();
    final rows = <Map<String, String>>[];
    for (var rowIndex = 1; rowIndex < csv.length; rowIndex++) {
      final row = csv[rowIndex];
      if (row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }
      final map = <String, String>{};
      for (var col = 0; col < header.length; col++) {
        final key = header[col];
        final value = col < row.length ? row[col].toString() : '';
        map[key] = value.trim();
      }
      rows.add(map);
    }
    return rows;
  }

  Future<List<Map<String, String>>> _readCsvRowsOptional(String assetPath) async {
    try {
      return await _readCsvRows(assetPath);
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic> _bundleToCache(MasterDataBundle bundle) {
    return {
      'announcements': bundle.announcements.map((e) => e.toMap()).toList(),
      'routes': bundle.routes.map((e) => e.toMap()).toList(),
      'airports': bundle.airports.map((e) => e.toMap()).toList(),
      'aircraft': bundle.aircraft.map((e) => e.toMap()).toList(),
      'delayReasons': bundle.delayReasons.map((e) => e.toMap()).toList(),
      'uiControls': bundle.uiControls.map((e) => e.toMap()).toList(),
      // Announcements와 동일한 Model toMap 패턴. Hive 라운드트립에서 타입/키
      // 가 안전하게 복원된다.
      'situationalRows': bundle.situationalRows.map((e) => e.toMap()).toList(),
      'situationalQuickAccessRows':
          bundle.situationalQuickAccessRows.map((e) => e.toMap()).toList(),
      'emergencyAnnouncements':
          bundle.emergencyAnnouncements.map((e) => e.toMap()).toList(),
    };
  }

  MasterDataBundle _bundleFromCache(dynamic raw) {
    final map = raw as Map<dynamic, dynamic>;
    final situationalRows = (map['situationalRows'] as List<dynamic>? ?? const [])
        .map((e) => SituationalRowModel.fromMap(e as Map<dynamic, dynamic>))
        .toList();
    final situationalQuickAccessRows =
        (map['situationalQuickAccessRows'] as List<dynamic>? ?? const [])
            .map(
              (e) => SituationalQuickAccessRowModel.fromMap(
                e as Map<dynamic, dynamic>,
              ),
            )
            .toList();
    final emergencyAnnouncements =
        (map['emergencyAnnouncements'] as List<dynamic>? ?? const [])
            .map((e) => AnnouncementModel.fromMap(e as Map<dynamic, dynamic>))
            .toList();
    return MasterDataBundle(
      announcements: (map['announcements'] as List<dynamic>? ?? const [])
          .map((e) => AnnouncementModel.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      routes: (map['routes'] as List<dynamic>? ?? const [])
          .map((e) => RouteMasterModel.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      airports: (map['airports'] as List<dynamic>? ?? const [])
          .map((e) => AirportMasterModel.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      aircraft: (map['aircraft'] as List<dynamic>? ?? const [])
          .map((e) => AircraftMasterModel.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      delayReasons: (map['delayReasons'] as List<dynamic>? ?? const [])
          .map((e) => DelayReasonModel.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      uiControls: (map['uiControls'] as List<dynamic>? ?? const [])
          .map((e) => UiControlModel.fromMap(e as Map<dynamic, dynamic>))
          .toList(),
      situationalRows: situationalRows,
      situationalQuickAccessRows: situationalQuickAccessRows,
      emergencyAnnouncements: emergencyAnnouncements,
    );
  }
}
