class GoogleSheetLinkConverter {
  static const defaultTabNames = <String, String>{
    'announcements': 'Announcements',
    'routes': 'Route_Master',
    'airports': 'Airports_Master',
    'aircraft': 'Aircraft_Master',
    'delayReasons': 'Delay_Reasons(routine)',
    'uiControls': 'UI_Controls',
    'situational': 'Situational',
    'situationalQuickAccess': 'Situational_Quick_Access',
    'emergency': 'Emergency',
  };

  static String toCsvExportUrl(String input, {int defaultGid = 0}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      throw FormatException('유효하지 않은 URL입니다.');
    }

    // 이미 CSV export URL이면 그대로 사용
    if (uri.path.contains('/export') &&
        (uri.queryParameters['format'] == 'csv')) {
      return trimmed;
    }

    final id = extractSheetId(uri);
    if (id == null || id.isEmpty) {
      throw FormatException('Google Sheets 문서 ID를 찾을 수 없습니다.');
    }

    final gid = _extractGid(uri) ?? defaultGid;
    return 'https://docs.google.com/spreadsheets/d/$id/export?format=csv&gid=$gid';
  }

  static String toCsvBySheetName(String spreadsheetUrl, String sheetName) {
    final trimmed = spreadsheetUrl.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      throw FormatException('유효하지 않은 스프레드시트 URL입니다.');
    }
    final sheetId = extractSheetId(uri);
    if (sheetId == null || sheetId.isEmpty) {
      throw FormatException('Google Sheets 문서 ID를 찾을 수 없습니다.');
    }
    // `headers=1` 매우 중요: 명시 안 하면 gviz가 자동으로 헤더 행 수를 추측해
    // 데이터 패턴에 따라 첫 N개 행을 통째로 헤더 한 줄로 합쳐버린다
    // (Situational 시트에서 헤더 키가 "Category DP ANNC DP ANNC..." 식으로
    // 뭉쳐 모든 row가 매핑 실패하던 사태의 원인). 항상 1로 고정한다.
    return Uri.https('docs.google.com', '/spreadsheets/d/$sheetId/gviz/tq', {
      'tqx': 'out:csv',
      'sheet': sheetName,
      'headers': '1',
    }).toString();
  }

  static String? extractSheetId(Uri uri) {
    final segments = uri.pathSegments;
    final dIndex = segments.indexOf('d');
    if (dIndex >= 0 && dIndex + 1 < segments.length) {
      return segments[dIndex + 1];
    }
    return null;
  }

  static int? _extractGid(Uri uri) {
    final gidQuery = uri.queryParameters['gid'];
    if (gidQuery != null) {
      return int.tryParse(gidQuery);
    }
    if (uri.fragment.startsWith('gid=')) {
      return int.tryParse(uri.fragment.replaceFirst('gid=', ''));
    }
    return null;
  }
}
