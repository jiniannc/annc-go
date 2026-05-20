class GoogleSheetUrls {
  GoogleSheetUrls._();

  /// 앱에 번들링된 기본 공유 마스터(시트 이름은 [GoogleSheetLinkConverter.defaultTabNames]와 일치해야 함).
  ///
  /// 링크: https://docs.google.com/spreadsheets/d/1ktTyJI3Cc19Wh8uIhtBsMvgXr3fRDsti9Qqj39k_1RY/edit
  static const canonicalSpreadsheetUrl =
      'https://docs.google.com/spreadsheets/d/1ktTyJI3Cc19Wh8uIhtBsMvgXr3fRDsti9Qqj39k_1RY/edit';

  /// 저장된 설정이 비어 있을 때 기본 스프레드시트 대신 다른 문서를 쓰려면:
  /// `flutter run --dart-define=GSHEET_SPREADSHEET_URL=https://...`
  static const spreadsheetFromEnvironment = String.fromEnvironment(
    'GSHEET_SPREADSHEET_URL',
    defaultValue: '',
  );

  /// 필수 마스터 CSV 중 하나라도 `dart-define`으로 지정되어 있으면, 구성된 URL만 쓰고
  /// [canonicalSpreadsheetUrl] 폴백은 쓰지 않는다(기존 CI/배포 스크립트와 충돌 방지).
  static bool get hasAnyLegacyDartDefineCsvUrl =>
      announcements.isNotEmpty ||
      routes.isNotEmpty ||
      airports.isNotEmpty ||
      aircraft.isNotEmpty ||
      delayReasons.isNotEmpty;

  // pub.dev 실행 예시:
  // flutter run --dart-define=GSHEET_ANNOUNCEMENTS_URL=https://...
  static const announcements = String.fromEnvironment(
    'GSHEET_ANNOUNCEMENTS_URL',
    defaultValue: '',
  );
  static const routes = String.fromEnvironment(
    'GSHEET_ROUTES_URL',
    defaultValue: '',
  );
  static const airports = String.fromEnvironment(
    'GSHEET_AIRPORTS_URL',
    defaultValue: '',
  );
  static const aircraft = String.fromEnvironment(
    'GSHEET_AIRCRAFT_URL',
    defaultValue: '',
  );
  static const delayReasons = String.fromEnvironment(
    'GSHEET_DELAY_REASONS_URL',
    defaultValue: '',
  );
  static const uiControls = String.fromEnvironment(
    'GSHEET_UI_CONTROLS_URL',
    defaultValue: '',
  );
  static const situational = String.fromEnvironment(
    'GSHEET_SITUATIONAL_URL',
    defaultValue: '',
  );
  static const situationalQuickAccess = String.fromEnvironment(
    'GSHEET_SITUATIONAL_QUICK_ACCESS_URL',
    defaultValue: '',
  );
  static const emergency = String.fromEnvironment(
    'GSHEET_EMERGENCY_URL',
    defaultValue: '',
  );
}
