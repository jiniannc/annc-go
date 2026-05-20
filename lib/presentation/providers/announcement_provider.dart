import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/condition_tag_utils.dart';
import '../../data/models/aircraft_master_model.dart';
import '../../data/models/airport_master_model.dart';
import '../../data/models/announcement_model.dart';
import '../../data/models/delay_reason_model.dart';
import '../../data/models/master_data_bundle.dart';
import '../../data/models/ui_control_model.dart';
import '../../data/repositories/csv_master_data_repository.dart';
import '../../data/services/phase_audio_cache_service.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/services/announcement_formatter.dart';
import 'flight_setup_provider.dart';

class SpecialWelcomeOption {
  const SpecialWelcomeOption({required this.label, required this.conditionTag});

  final String label;
  final String conditionTag;
}

class TeleprompterScript {
  const TeleprompterScript({
    required this.id,
    required this.title,
    required this.ko,
    required this.en,
    required this.order,
    required this.isOptional,
    this.optionalStartsCollapsed = false,
    this.optionalIsSelect = false,
    required this.inlineKey,
    required this.inlineItemsKo,
    required this.inlineItemsEn,
    required this.inlineDefaultIndex,
    required this.announcer,
    required this.timing,
    required this.etcNote,
    this.hasTimeToken,
  });

  final String id;
  final String title;
  final String ko;
  final String en;
  final int order;
  final bool isOptional;
  /// CSV Option `hide` — 필요시 카드이지만 기본 접힘.
  final bool optionalStartsCollapsed;
  /// CSV Option `select` — 연속 시 택1 그룹(단독은 hide와 동일).
  final bool optionalIsSelect;
  final String inlineKey;
  final List<String> inlineItemsKo;
  final List<String> inlineItemsEn;
  final int inlineDefaultIndex;
  final String announcer;
  final String timing;
  final String etcNote;
  final bool? hasTimeToken;
}

class PhaseAudioClip {
  const PhaseAudioClip({
    this.phaseId,
    this.jpUrl,
    this.cnUrl,
    this.jpBytes,
    this.cnBytes,
  });

  final String? phaseId;
  final String? jpUrl;
  final String? cnUrl;
  final Uint8List? jpBytes;
  final Uint8List? cnBytes;

  bool get hasJp => jpUrl != null && jpUrl!.trim().isNotEmpty;
  bool get hasCn => cnUrl != null && cnUrl!.trim().isNotEmpty;
  bool get hasAny => hasJp || hasCn;
}

const noSpecialWelcomeTag = 'none';

final masterDataRepositoryProvider = Provider<CsvMasterDataRepository>((ref) {
  return CsvMasterDataRepository();
});

final phaseAudioCacheServiceProvider = Provider<PhaseAudioCacheService>((ref) {
  return PhaseAudioCacheService();
});

final masterDataProvider = FutureProvider<MasterDataBundle>((ref) async {
  final repository = ref.watch(masterDataRepositoryProvider);
  return repository.loadMasterData();
});

final allAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  final setup = ref.watch(flightSetupProvider);
  final selectedControls = ref.watch(selectedControlValuesProvider);
  if (bundle == null || setup == null) {
    return const [];
  }
  final repository = ref.watch(masterDataRepositoryProvider);
  final controlValues = ref.watch(masterDataRepositoryProvider).effectiveUiControlValues(
        bundle,
        selectedControls,
      );
  return repository.buildRoutineAnnouncements(
    bundle,
    setup,
    controlValues: controlValues,
  );
});

final selectedAnnouncementProvider = StateProvider<Announcement?>(
  (ref) => null,
);
final selectedDelayReasonProvider = StateProvider<DelayReasonModel?>(
  (ref) => null,
);
final selectedControlValuesProvider = StateProvider<Map<String, String>>((
  ref,
) {
  return const {};
});
final routineScriptRefreshTickProvider = StateProvider<int>((ref) => 0);

final uiControlsByMilestoneProvider =
    Provider.family<List<UiControlModel>, String>((ref, milestone) {
      final bundle = ref.watch(masterDataProvider).valueOrNull;
      final setup = ref.watch(flightSetupProvider);
      if (bundle == null || setup == null) {
        return const [];
      }
      final repository = ref.watch(masterDataRepositoryProvider);
      final origin = ref.watch(originAirportProvider);
      final destination = ref.watch(destinationAirportProvider);
      final aircraft = ref.watch(currentAircraftProvider);
      final route = repository.findRouteBySetup(bundle, setup);
      final selected = ref.watch(selectedControlValuesProvider);
      final controlValues =
          repository.effectiveUiControlValues(bundle, selected);
      final phaseIdsForMilestone = bundle.announcements
          .where((a) => a.flightPhase == milestone)
          .map((a) => a.phaseId)
          .toSet();
      final controls = bundle.uiControls
          .where((c) => phaseIdsForMilestone.contains(c.phaseId))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return controls.where((c) {
        if (c.visibleWhen.trim().isEmpty) {
          return true;
        }
        return repository.matchesConditionTag(
          conditionTag: c.visibleWhen,
          setup: setup,
          originAirport: origin,
          destinationAirport: destination,
          aircraft: aircraft,
          route: route,
          controlValues: controlValues,
        );
      }).toList();
    });

final routineAnnouncementsForSelectedMilestoneProvider =
    Provider<List<Announcement>>((ref) {
      final selectedMilestone = ref.watch(selectedMilestoneProvider);
      final allAnnouncements = ref.watch(allAnnouncementsProvider);
      return allAnnouncements
          .where(
            (item) =>
                item.category == AnnouncementCategory.routine &&
                item.flightPhase == selectedMilestone,
          )
          .toList();
    });

final routineAnnouncementsByMilestoneProvider =
    Provider.family<List<Announcement>, String>((ref, milestone) {
      final allAnnouncements = ref.watch(allAnnouncementsProvider);
      final list =
          allAnnouncements
              .where(
                (item) =>
                    item.category == AnnouncementCategory.routine &&
                    item.flightPhase == milestone,
              )
              .toList()
            ..sort((a, b) => a.order.compareTo(b.order));
      return list;
    });

final phaseAudioForMilestoneProvider =
    FutureProvider.family<PhaseAudioClip, String>((ref, milestone) async {
      final bundle = await ref.watch(masterDataProvider.future);
      final service = ref.watch(phaseAudioCacheServiceProvider);
      final linksByPhaseId = service.buildPhaseAudioLinksByPhaseId(bundle);
      final phaseIds = <String>[];
      for (final item in bundle.announcements) {
        if (item.flightPhase != milestone) {
          continue;
        }
        if (!phaseIds.contains(item.phaseId)) {
          phaseIds.add(item.phaseId);
        }
      }
      String? targetPhaseId;
      String? jpUrl;
      String? cnUrl;
      for (final phaseId in phaseIds) {
        final links = linksByPhaseId[phaseId];
        if (links == null || !links.hasAny) {
          continue;
        }
        targetPhaseId ??= phaseId;
        jpUrl ??= links.jpUrl;
        cnUrl ??= links.cnUrl;
        if (jpUrl != null && cnUrl != null) {
          break;
        }
      }
      if ((jpUrl?.isEmpty ?? true) && (cnUrl?.isEmpty ?? true)) {
        return const PhaseAudioClip();
      }
      final jpBytes = jpUrl == null ? null : await service.getCachedBytes(jpUrl);
      final cnBytes = cnUrl == null ? null : await service.getCachedBytes(cnUrl);
      return PhaseAudioClip(
        phaseId: targetPhaseId,
        jpUrl: jpUrl,
        cnUrl: cnUrl,
        jpBytes: jpBytes,
        cnBytes: cnBytes,
      );
    });

final delayReasonsProvider = Provider<List<DelayReasonModel>>((ref) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  return bundle?.delayReasons ?? const [];
});

final specialWelcomeOptionsProvider = Provider<List<SpecialWelcomeOption>>((
  ref,
) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  final announcements = bundle?.announcements ?? const [];
  final seen = <String>{};
  final options = <SpecialWelcomeOption>[
    const SpecialWelcomeOption(
      label: '해당없음',
      conditionTag: noSpecialWelcomeTag,
    ),
  ];

  for (final item in announcements) {
    final tag = normalizeConditionTag(item.conditionTag);
    if (!isSpecialWelcomeTag(tag)) {
      continue;
    }
    if (seen.contains(tag)) {
      continue;
    }
    seen.add(tag);
    options.add(
      SpecialWelcomeOption(
        label: _displayWelcomeTitle(item.title),
        conditionTag: tag,
      ),
    );
  }
  return options;
});

final destinationAirportProvider = Provider<AirportMasterModel?>((ref) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  final setup = ref.watch(flightSetupProvider);
  if (bundle == null || setup == null) {
    return null;
  }
  final repository = ref.watch(masterDataRepositoryProvider);
  return repository.findAirportByIata(bundle, setup.destinationIata);
});

final specialFarewellOptionsProvider = Provider<List<String>>((ref) {
  final destination = ref.watch(destinationAirportProvider);
  return destination?.specialFarewellItems ?? const [];
});

final originAirportProvider = Provider<AirportMasterModel?>((ref) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  final setup = ref.watch(flightSetupProvider);
  if (bundle == null || setup == null) {
    return null;
  }
  final repository = ref.watch(masterDataRepositoryProvider);
  return repository.findAirportByIata(bundle, setup.originIata);
});

final currentAircraftProvider = Provider<AircraftMasterModel?>((ref) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  final setup = ref.watch(flightSetupProvider);
  if (bundle == null || setup == null) {
    return null;
  }
  final repository = ref.watch(masterDataRepositoryProvider);
  return repository.findAircraftByHlNo(bundle, setup.hlNo);
});

final draftAircraftProvider = Provider<AircraftMasterModel?>((ref) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  final draftHlNo = ref.watch(draftHlNoProvider);
  if (bundle == null || draftHlNo.trim().isEmpty) {
    return null;
  }
  final repository = ref.watch(masterDataRepositoryProvider);
  return repository.findAircraftByHlNo(bundle, draftHlNo);
});

final announcementFormatterProvider = Provider(
  (ref) => AnnouncementFormatter(),
);

final formattedSelectedAnnouncementProvider =
    Provider<({String ko, String en})?>((ref) {
      final selected = ref.watch(selectedAnnouncementProvider);
      final setup = ref.watch(flightSetupProvider);
      if (selected == null || setup == null) {
        return null;
      }
      final formatter = ref.watch(announcementFormatterProvider);
      final origin = ref.watch(originAirportProvider);
      final destination = ref.watch(destinationAirportProvider);
      final aircraft = ref.watch(currentAircraftProvider);
      final selectedReason = ref.watch(selectedDelayReasonProvider);
      final delayReasons = ref.watch(delayReasonsProvider);
      final reason =
          selectedReason ??
          (delayReasons.isNotEmpty ? delayReasons.first : null);

      final ko = formatter.format(
        template: selected.contentKR,
        setup: setup,
        originAirport: origin,
        destinationAirport: destination,
        aircraft: aircraft,
        selectedDelayReason: reason,
      );
      final en = formatter.format(
        template: selected.contentEN,
        setup: setup,
        originAirport: origin,
        destinationAirport: destination,
        aircraft: aircraft,
        selectedDelayReason: reason,
      );
      return (ko: ko, en: en);
    });

final formattedRoutineScriptsByMilestoneProvider =
    Provider.family<List<TeleprompterScript>, String>((ref, milestone) {
      ref.watch(routineScriptRefreshTickProvider);
      final setup = ref.watch(flightSetupProvider);
      if (setup == null) {
        return const [];
      }
      final scripts = ref.watch(
        routineAnnouncementsByMilestoneProvider(milestone),
      );
      final formatter = ref.watch(announcementFormatterProvider);
      final origin = ref.watch(originAirportProvider);
      final destination = ref.watch(destinationAirportProvider);
      final aircraft = ref.watch(currentAircraftProvider);
      final selectedReason = ref.watch(selectedDelayReasonProvider);
      final delayReasons = ref.watch(delayReasonsProvider);
      final reason =
          selectedReason ??
          (delayReasons.isNotEmpty ? delayReasons.first : null);

      return scripts
          .map(
            (item) {
              final model = item is AnnouncementModel ? item : null;
              return TeleprompterScript(
                id: item.id,
                title: item.title,
                ko: formatter.format(
                  template: item.contentKR,
                  setup: setup,
                  originAirport: origin,
                  destinationAirport: destination,
                  aircraft: aircraft,
                  selectedDelayReason: reason,
                  inlineDelayReasonSlot: true,
                  inlineSpecialFarewellSlot: true,
                  inlineFlightNumberHint: true,
                  emphasizeResolvedPlaceholders: true,
                ),
                en: formatter.format(
                  template: item.contentEN,
                  setup: setup,
                  originAirport: origin,
                  destinationAirport: destination,
                  aircraft: aircraft,
                  selectedDelayReason: reason,
                  inlineDelayReasonSlot: true,
                  inlineSpecialFarewellSlot: true,
                  inlineFlightNumberHint: true,
                  emphasizeResolvedPlaceholders: true,
                ),
                order: item.order,
                isOptional: item.isOptional,
                optionalStartsCollapsed: item.optionalStartsCollapsed,
                optionalIsSelect: item.optionalIsSelect,
                inlineKey: model?.inlineKey ?? '',
                inlineItemsKo: model?.inlineItemsKo ?? const [],
                inlineItemsEn: model?.inlineItemsEn ?? const [],
                inlineDefaultIndex: model?.inlineDefaultIndex ?? 1,
                announcer: model?.announcer ?? '',
                timing: model?.timing ?? '',
                etcNote: model?.etcNote ?? '',
                hasTimeToken: _containsTimeToken(item.contentKR) ||
                    _containsTimeToken(item.contentEN),
              );
            },
          )
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    });

final situationalAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  return const [];
});

/// `Emergency` 시트 전체 행을 condition tag 필터·정렬까지 거친 결과.
///
/// Announcements와 동일한 [CsvMasterDataRepository.buildRoutineAnnouncements]
/// 파이프를 통과시키되, 입력 카테고리만 `emergency` 로 지정한다. 빈 setup 일
/// 때는 안전하게 빈 리스트.
final emergencyAnnouncementsProvider = Provider<List<AnnouncementModel>>((ref) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  final setup = ref.watch(flightSetupProvider);
  final selectedControls = ref.watch(selectedControlValuesProvider);
  if (bundle == null || setup == null) {
    return const [];
  }
  final repository = ref.watch(masterDataRepositoryProvider);
  final controlValues = ref.watch(masterDataRepositoryProvider).effectiveUiControlValues(
        bundle,
        selectedControls,
      );
  return repository.buildAnnouncementsForCategory(
    bundle,
    setup,
    category: AnnouncementCategory.emergency,
    controlValues: controlValues,
  );
});

/// Emergency 시트에 등장하는 Phase 이름들(중복 제거·CSV 순서 보존).
///
/// 사용자가 시트에서 "비상 착륙" / "비상 착수" 같은 한국어 Phase 라벨을 그대로
/// 적으면, UI 상단의 split-button 토글에 그대로 노출된다.
final emergencyPhasesProvider = Provider<List<String>>((ref) {
  final all = ref.watch(emergencyAnnouncementsProvider);
  final seen = <String>{};
  final ordered = <String>[];
  for (final item in all) {
    final phase = item.flightPhase.trim();
    if (phase.isEmpty) continue;
    if (seen.add(phase)) ordered.add(phase);
  }
  return ordered;
});

/// Emergency 토글에서 현재 선택된 Phase 이름. null이면 첫 번째 Phase 사용.
final selectedEmergencyPhaseProvider = StateProvider<String?>((ref) => null);

/// 선택된 Phase 하나에 속하는 Emergency 방송문을 KO/EN 포맷팅까지 마친 결과.
///
/// `formattedRoutineScriptsByMilestoneProvider` 와 동일한 인터페이스
/// ([TeleprompterScript])라서 기존 announcement UI 블록을 그대로 사용 가능.
final formattedEmergencyScriptsByPhaseProvider =
    Provider.family<List<TeleprompterScript>, String>((ref, phase) {
      ref.watch(routineScriptRefreshTickProvider);
      final setup = ref.watch(flightSetupProvider);
      if (setup == null) {
        return const [];
      }
      final all = ref.watch(emergencyAnnouncementsProvider);
      final scripts = all
          .where((item) => item.flightPhase == phase)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final formatter = ref.watch(announcementFormatterProvider);
      final origin = ref.watch(originAirportProvider);
      final destination = ref.watch(destinationAirportProvider);
      final aircraft = ref.watch(currentAircraftProvider);
      final selectedReason = ref.watch(selectedDelayReasonProvider);
      final delayReasons = ref.watch(delayReasonsProvider);
      final reason =
          selectedReason ??
          (delayReasons.isNotEmpty ? delayReasons.first : null);

      // Emergency 본문도 Announcements 와 동일하게 인라인 sentinel(지연 사유,
      // 특별 작별인사, 항공편 번호 hint) 을 그대로 만들어 둔다. 시트에 해당
      // 토큰이 없으면 단순히 표출되지 않아 안전. AnnouncementScriptBlock 이
      // sentinel 을 dropdown 위젯으로 치환한다.
      return scripts
          .map(
            (item) => TeleprompterScript(
              id: item.id,
              title: item.title,
              ko: formatter.format(
                template: item.contentKR,
                setup: setup,
                originAirport: origin,
                destinationAirport: destination,
                aircraft: aircraft,
                selectedDelayReason: reason,
                inlineDelayReasonSlot: true,
                inlineSpecialFarewellSlot: true,
                inlineFlightNumberHint: true,
                emphasizeResolvedPlaceholders: true,
              ),
              en: formatter.format(
                template: item.contentEN,
                setup: setup,
                originAirport: origin,
                destinationAirport: destination,
                aircraft: aircraft,
                selectedDelayReason: reason,
                inlineDelayReasonSlot: true,
                inlineSpecialFarewellSlot: true,
                inlineFlightNumberHint: true,
                emphasizeResolvedPlaceholders: true,
              ),
              order: item.order,
              isOptional: item.isOptional,
              optionalStartsCollapsed: item.optionalStartsCollapsed,
              optionalIsSelect: item.optionalIsSelect,
              inlineKey: item.inlineKey,
              inlineItemsKo: item.inlineItemsKo,
              inlineItemsEn: item.inlineItemsEn,
              inlineDefaultIndex: item.inlineDefaultIndex,
              announcer: item.announcer,
              timing: item.timing,
              etcNote: item.etcNote,
              hasTimeToken: _containsTimeToken(item.contentKR) ||
                  _containsTimeToken(item.contentEN),
            ),
          )
          .toList();
    });

final airportByIataProvider = Provider.family<AirportMasterModel?, String>((
  ref,
  iataCode,
) {
  final bundle = ref.watch(masterDataProvider).valueOrNull;
  if (bundle == null) {
    return null;
  }
  final repository = ref.watch(masterDataRepositoryProvider);
  return repository.findAirportByIata(bundle, iataCode);
});

String _displayWelcomeTitle(String rawTitle) {
  final title = rawTitle.trim();
  final match = RegExp(r'환영 인사\s*\((.+)\)').firstMatch(title);
  if (match != null) {
    return match.group(1)!.trim();
  }
  return title.isEmpty ? '특별 환영' : title;
}

bool _containsTimeToken(String template) {
  /// 목적지 **현재 시각** 치환만 — `flight_time_en` 등에 `time_en`이 부분 문자열로
  /// 들어가면 안 되므로 `{…}` / `〔…〕` 안의 토큰만 본다.
  const keys = [
    'month_ko',
    'date_ko',
    'hour_ko',
    'minute_ko',
    'time_en',
    'month_en',
    'date_en',
  ];
  final t = template.trim();
  if (t.isEmpty) {
    return false;
  }
  for (final key in keys) {
    final re = RegExp(
      '[\\{｛\\[]\\s*${RegExp.escape(key)}\\s*[\\}｝\\]]',
      caseSensitive: false,
    );
    if (re.hasMatch(t)) {
      return true;
    }
  }
  return false;
}
