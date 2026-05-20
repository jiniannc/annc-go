import 'aircraft_master_model.dart';
import 'airport_master_model.dart';
import 'announcement_model.dart';
import 'delay_reason_model.dart';
import 'route_master_model.dart';
import 'situational_quick_access_row_model.dart';
import 'situational_row_model.dart';
import 'ui_control_model.dart';

class MasterDataBundle {
  const MasterDataBundle({
    required this.announcements,
    required this.routes,
    required this.airports,
    required this.aircraft,
    required this.delayReasons,
    required this.uiControls,
    this.situationalRows = const [],
    this.situationalQuickAccessRows = const [],
    this.emergencyAnnouncements = const [],
  });

  final List<AnnouncementModel> announcements;
  final List<RouteMasterModel> routes;
  final List<AirportMasterModel> airports;
  final List<AircraftMasterModel> aircraft;
  final List<DelayReasonModel> delayReasons;
  final List<UiControlModel> uiControls;

  /// `Emergency` 시트 — Announcements와 동일 컬럼/로직(`Phase / PhaseID / Order /
  /// Title / Content_KO / Content_EN / Condition_Tag / Option / Inline_*` 등)을
  /// 그대로 따르되, `category`만 [AnnouncementCategory.emergency] 로 분리 보관.
  final List<AnnouncementModel> emergencyAnnouncements;

  /// Situational 시트의 CSV row 목록 (Model 래핑).
  ///
  /// 단일 `SituationalScript` 하나가 여러 CSV row(base + option*)로 구성되므로
  /// 여기서는 row 단위 모델(`SituationalRowModel`) 리스트로 보관한다.
  /// Announcements 등 다른 마스터와 동일하게 `toMap`/`fromMap` 라운드트립을
  /// 거쳐 Hive 저장 시 타입이 뭉개지지 않도록 한다. UI 계층에서는
  /// `SituationalScriptsRepository.parseRows()` 로 파싱해 사용.
  final List<SituationalRowModel> situationalRows;

  /// `Situational_Quick_Access` 시트 — 키워드·아이콘으로 시나리오 바로가기.
  final List<SituationalQuickAccessRowModel> situationalQuickAccessRows;
}
