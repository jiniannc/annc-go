class SyncSheetLinks {
  const SyncSheetLinks({
    required this.spreadsheetUrl,
    required this.announcementsCsvUrl,
    required this.routesCsvUrl,
    required this.airportsCsvUrl,
    required this.aircraftCsvUrl,
    required this.delayReasonsCsvUrl,
    this.uiControlsCsvUrl = '',
    this.situationalCsvUrl = '',
    this.situationalQuickAccessCsvUrl = '',
    this.emergencyCsvUrl = '',
  });

  final String spreadsheetUrl;
  final String announcementsCsvUrl;
  final String routesCsvUrl;
  final String airportsCsvUrl;
  final String aircraftCsvUrl;
  final String delayReasonsCsvUrl;
  final String uiControlsCsvUrl;
  final String situationalCsvUrl;
  final String situationalQuickAccessCsvUrl;
  final String emergencyCsvUrl;

  bool get isComplete =>
      announcementsCsvUrl.isNotEmpty &&
      routesCsvUrl.isNotEmpty &&
      airportsCsvUrl.isNotEmpty &&
      aircraftCsvUrl.isNotEmpty &&
      delayReasonsCsvUrl.isNotEmpty;

  /// 스프레드시트 단일 주소 없이 과거 형식으로 시트별 CSV URL만 저장되어 있는 경우.
  /// 이 경우 내장 기본 스프레드시트 폴백을 사용하면 안 된다.
  bool get hasPerSheetCsvWithoutSpreadsheet =>
      spreadsheetUrl.trim().isEmpty &&
      (announcementsCsvUrl.trim().isNotEmpty ||
          routesCsvUrl.trim().isNotEmpty ||
          airportsCsvUrl.trim().isNotEmpty ||
          aircraftCsvUrl.trim().isNotEmpty ||
          delayReasonsCsvUrl.trim().isNotEmpty ||
          uiControlsCsvUrl.trim().isNotEmpty ||
          situationalCsvUrl.trim().isNotEmpty ||
          situationalQuickAccessCsvUrl.trim().isNotEmpty ||
          emergencyCsvUrl.trim().isNotEmpty);

  Map<String, String> toMap() {
    return {
      'spreadsheetUrl': spreadsheetUrl,
      'announcementsCsvUrl': announcementsCsvUrl,
      'routesCsvUrl': routesCsvUrl,
      'airportsCsvUrl': airportsCsvUrl,
      'aircraftCsvUrl': aircraftCsvUrl,
      'delayReasonsCsvUrl': delayReasonsCsvUrl,
      'uiControlsCsvUrl': uiControlsCsvUrl,
      'situationalCsvUrl': situationalCsvUrl,
      'situationalQuickAccessCsvUrl': situationalQuickAccessCsvUrl,
      'emergencyCsvUrl': emergencyCsvUrl,
    };
  }

  factory SyncSheetLinks.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const SyncSheetLinks(
        spreadsheetUrl: '',
        announcementsCsvUrl: '',
        routesCsvUrl: '',
        airportsCsvUrl: '',
        aircraftCsvUrl: '',
        delayReasonsCsvUrl: '',
        uiControlsCsvUrl: '',
        situationalCsvUrl: '',
        situationalQuickAccessCsvUrl: '',
        emergencyCsvUrl: '',
      );
    }
    return SyncSheetLinks(
      spreadsheetUrl: (map['spreadsheetUrl'] ?? '').toString(),
      announcementsCsvUrl: (map['announcementsCsvUrl'] ?? '').toString(),
      routesCsvUrl: (map['routesCsvUrl'] ?? '').toString(),
      airportsCsvUrl: (map['airportsCsvUrl'] ?? '').toString(),
      aircraftCsvUrl: (map['aircraftCsvUrl'] ?? '').toString(),
      delayReasonsCsvUrl: (map['delayReasonsCsvUrl'] ?? '').toString(),
      uiControlsCsvUrl: (map['uiControlsCsvUrl'] ?? '').toString(),
      situationalCsvUrl: (map['situationalCsvUrl'] ?? '').toString(),
      situationalQuickAccessCsvUrl:
          (map['situationalQuickAccessCsvUrl'] ?? '').toString(),
      emergencyCsvUrl: (map['emergencyCsvUrl'] ?? '').toString(),
    );
  }
}
