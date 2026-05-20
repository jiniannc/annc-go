import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../core/constants/google_sheet_urls.dart';
import '../../core/utils/google_sheet_link_converter.dart';
import '../../domain/entities/announcement.dart';
import '../../domain/services/sync_service.dart';
import '../../domain/sync/sync_progress_snapshot.dart';
import '../models/aircraft_master_model.dart';
import '../models/airport_master_model.dart';
import '../models/announcement_model.dart';
import '../models/delay_reason_model.dart';
import '../models/master_data_bundle.dart';
import '../models/route_master_model.dart';
import '../models/sync_sheet_links.dart';
import '../models/situational_quick_access_row_model.dart';
import '../models/situational_row_model.dart';
import '../models/ui_control_model.dart';
import '../repositories/csv_master_data_repository.dart';
import '../repositories/sync_config_repository.dart';

class GoogleSheetsSyncService implements SyncService {
  GoogleSheetsSyncService(this._repository, this._configRepository);

  final CsvMasterDataRepository _repository;
  final SyncConfigRepository _configRepository;

  /// 스플래시·동기화 화면에서 실시간 진행률 표시용.
  final ValueNotifier<SyncProgressSnapshot> syncProgress =
      ValueNotifier<SyncProgressSnapshot>(SyncProgressSnapshot.initial);
  SyncProgressSnapshot _lastEmitted = SyncProgressSnapshot.initial;
  DateTime _lastEmitAt = DateTime.fromMillisecondsSinceEpoch(0);

  void _emit(SyncProgressSnapshot snapshot) {
    syncProgress.value = snapshot;
  }

  void emitProgress({
    required SyncPhase phase,
    required double progress,
    required String message,
  }) {
    final p = progress.clamp(0.0, 1.0);
    final next = SyncProgressSnapshot(
      phase: phase,
      progress: p,
      message: message,
    );
    final now = DateTime.now();
    final samePhase = next.phase == _lastEmitted.phase;
    final sameMessage = next.message == _lastEmitted.message;
    final progressDelta = (next.progress - _lastEmitted.progress).abs();
    final elapsedMs = now.difference(_lastEmitAt).inMilliseconds;
    final allowByProgress = progressDelta >= 0.015;
    final allowByTime = elapsedMs >= 120;
    final isMeaningfulChange = !samePhase || !sameMessage || allowByProgress;

    if (!isMeaningfulChange && !allowByTime) {
      return;
    }
    if (samePhase && sameMessage && !allowByProgress && !allowByTime) {
      return;
    }

    _lastEmitted = next;
    _lastEmitAt = now;
    _emit(next);
  }

  /// 긴 동기화 파이프라인 중 UI 프레임이 숨 쉴 수 있게 이벤트 루프에 양보.
  Future<void> _yieldForUi() async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }

  Future<bool> hasNetwork() async {
    final results = await Connectivity().checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  @override
  Future<void> syncFromGoogleSheets() async {
    emitProgress(
      phase: SyncPhase.initializing,
      progress: 0.04,
      message: '초기화 중...',
    );
    if (!await hasNetwork()) {
      emitProgress(
        phase: SyncPhase.offline,
        progress: 0.9,
        message: '오프라인 — 저장된 데이터를 사용합니다',
      );
      return;
    }

    emitProgress(
      phase: SyncPhase.checkingConfig,
      progress: 0.08,
      message: '기재 정보 확인 중...',
    );
    final urls = await _resolveUrls();
    if (urls.values.any((v) => v.trim().isEmpty)) {
      throw Exception('Google Sheet CSV URL이 설정되지 않았습니다.');
    }

    emitProgress(
      phase: SyncPhase.downloading,
      progress: 0.12,
      message: '최신 방송문 동기화 중...',
    );
    await _yieldForUi();
    final announcementsRows = await _fetchCsvRows(urls['announcements']!);
    emitProgress(
      phase: SyncPhase.downloading,
      progress: 0.28,
      message: '최신 방송문 동기화 중...',
    );
    await _yieldForUi();
    final routesRows = await _fetchCsvRows(urls['routes']!);
    emitProgress(
      phase: SyncPhase.downloading,
      progress: 0.4,
      message: '최신 방송문 동기화 중...',
    );
    await _yieldForUi();
    final airportsRows = await _fetchCsvRows(urls['airports']!);
    emitProgress(
      phase: SyncPhase.downloading,
      progress: 0.52,
      message: '최신 방송문 동기화 중...',
    );
    await _yieldForUi();
    final aircraftRows = await _fetchCsvRows(urls['aircraft']!);
    emitProgress(
      phase: SyncPhase.downloading,
      progress: 0.64,
      message: '최신 방송문 동기화 중...',
    );
    await _yieldForUi();
    final delayRows = await _fetchCsvRows(urls['delayReasons']!);
    emitProgress(
      phase: SyncPhase.downloading,
      progress: 0.74,
      message: '최신 방송문 동기화 중...',
    );
    await _yieldForUi();
    final uiControlsRows = await _fetchCsvRowsOptional(
      urls['uiControls'] ?? '',
    );
    emitProgress(
      phase: SyncPhase.downloading,
      progress: 0.76,
      message: '최신 방송문 동기화 중...',
    );
    await _yieldForUi();
    final situationalRawRows = await _fetchCsvRowsOptional(
      urls['situational'] ?? '',
    );
    await _yieldForUi();
    final situationalQuickAccessRawRows = await _fetchCsvRowsOptional(
      urls['situationalQuickAccess'] ?? '',
    );
    await _yieldForUi();
    final emergencyRawRows = await _fetchCsvRowsOptional(
      urls['emergency'] ?? '',
    );
    // Announcements 등 다른 시트와 동일하게, raw Map을 Model로 한 번 감싼다.
    // Hive 라운드트립에서 key/타입이 뭉개지는 문제를 원천 차단.
    final situationalRows = situationalRawRows
        .map(SituationalRowModel.fromCsvMap)
        .where((r) => !r.isEmpty)
        .toList();
    final situationalQuickAccessRows = situationalQuickAccessRawRows
        .map(SituationalQuickAccessRowModel.fromCsvMap)
        .where((r) => !r.isEmpty)
        .toList();
    // ignore: avoid_print
    print(
      '[Sync] situational raw=${situationalRawRows.length} '
      'models=${situationalRows.length} '
      'firstKeys=${situationalRawRows.isEmpty ? '-' : situationalRawRows.first.keys.toList()}',
    );

    emitProgress(
      phase: SyncPhase.processing,
      progress: 0.8,
      message: '데이터 정리 중...',
    );
    await _yieldForUi();
    final bundle = MasterDataBundle(
      announcements: [
        for (var i = 0; i < announcementsRows.length; i++)
          AnnouncementModel.fromCsvMap(announcementsRows[i], index: i + 1),
      ],
      routes: routesRows.map(RouteMasterModel.fromCsvMap).toList(),
      airports: airportsRows.map(AirportMasterModel.fromCsvMap).toList(),
      aircraft: aircraftRows.map(AircraftMasterModel.fromCsvMap).toList(),
      delayReasons: [
        for (var i = 0; i < delayRows.length; i++)
          DelayReasonModel.fromCsvMap(delayRows[i], index: i + 1),
      ],
      uiControls: uiControlsRows.map(UiControlModel.fromCsvMap).toList(),
      situationalRows: situationalRows,
      situationalQuickAccessRows: situationalQuickAccessRows,
      emergencyAnnouncements: [
        for (var i = 0; i < emergencyRawRows.length; i++)
          AnnouncementModel.fromCsvMap(
            emergencyRawRows[i],
            index: i + 1,
            category: AnnouncementCategory.emergency,
          ),
      ],
    );

    emitProgress(
      phase: SyncPhase.saving,
      progress: 0.84,
      message: '기기에 저장 중...',
    );
    await _repository.saveBundleToCache(bundle, syncedAt: DateTime.now());
    emitProgress(phase: SyncPhase.saving, progress: 0.92, message: '동기화 저장 완료');
  }

  @override
  Future<DateTime?> getLastSyncedAt() {
    return _repository.readLastSyncedAt();
  }

  Future<bool> hasConfiguredUrls() async {
    final urls = await _resolveUrls();
    const requiredKeys = [
      'announcements',
      'routes',
      'airports',
      'aircraft',
      'delayReasons',
    ];
    return requiredKeys.every((key) => (urls[key] ?? '').trim().isNotEmpty);
  }

  Future<Map<String, String>> _resolveUrls() async {
    final saved = await _configRepository.readSheetLinks();
    final spreadsheetUrl = _effectiveSpreadsheetUrl(saved);

    if (spreadsheetUrl.isNotEmpty) {
      return {
        'announcements': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['announcements']!,
        ),
        'routes': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['routes']!,
        ),
        'airports': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['airports']!,
        ),
        'aircraft': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['aircraft']!,
        ),
        'delayReasons': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['delayReasons']!,
        ),
        'uiControls': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['uiControls']!,
        ),
        'situational': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['situational']!,
        ),
        'situationalQuickAccess': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['situationalQuickAccess']!,
        ),
        'emergency': GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['emergency']!,
        ),
      };
    }
    return {
      'announcements': _pick(
        saved.announcementsCsvUrl,
        GoogleSheetUrls.announcements,
      ),
      'routes': _pick(saved.routesCsvUrl, GoogleSheetUrls.routes),
      'airports': _pick(saved.airportsCsvUrl, GoogleSheetUrls.airports),
      'aircraft': _pick(saved.aircraftCsvUrl, GoogleSheetUrls.aircraft),
      'delayReasons': _pick(
        saved.delayReasonsCsvUrl,
        GoogleSheetUrls.delayReasons,
      ),
      'uiControls': _pick(saved.uiControlsCsvUrl, GoogleSheetUrls.uiControls),
      'situational': _pick(
        saved.situationalCsvUrl,
        GoogleSheetUrls.situational,
      ),
      'situationalQuickAccess': _pick(
        saved.situationalQuickAccessCsvUrl,
        GoogleSheetUrls.situationalQuickAccess,
      ),
      'emergency': _pick(saved.emergencyCsvUrl, GoogleSheetUrls.emergency),
    };
  }

  /// 사용자 저장 값 → `--dart-define=GSHEET_SPREADSHEET_URL=` → 레거시 CSV define이 하나도 없을 때만
  /// 앱 내장 [GoogleSheetUrls.canonicalSpreadsheetUrl].
  String _effectiveSpreadsheetUrl(SyncSheetLinks saved) {
    final user = saved.spreadsheetUrl.trim();
    if (user.isNotEmpty) {
      return user;
    }
    final fromEnv = GoogleSheetUrls.spreadsheetFromEnvironment.trim();
    if (fromEnv.isNotEmpty) {
      return fromEnv;
    }
    if (GoogleSheetUrls.hasAnyLegacyDartDefineCsvUrl ||
        saved.hasPerSheetCsvWithoutSpreadsheet) {
      return '';
    }
    return GoogleSheetUrls.canonicalSpreadsheetUrl;
  }

  String _pick(String preferred, String fallback) {
    return preferred.trim().isNotEmpty ? preferred.trim() : fallback.trim();
  }

  Future<List<Map<String, String>>> _fetchCsvRows(String url) async {
    // Google Sheets gviz/export 엔드포인트는 응답을 1~수십 초 캐싱한다.
    // 사용자가 시트를 수정한 직후 동기화해도 옛 데이터가 돌아오는 문제를
    // 막기 위해 매 요청마다 cache-buster query를 붙이고, HTTP 측에서도
    // no-store/no-cache 를 명시한다.
    final separator = url.contains('?') ? '&' : '?';
    final bustedUrl =
        '$url${separator}_cb=${DateTime.now().millisecondsSinceEpoch}';
    final response = await http.get(
      Uri.parse(bustedUrl),
      headers: const {
        'Cache-Control': 'no-cache, no-store, max-age=0',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed to fetch csv: $url');
    }
    final text = response.body;

    // 진단 로그: 응답 첫 줄과 길이. 동기화 이상 시 1순위 단서.
    final firstLine = () {
      final i = text.indexOf('\n');
      return i < 0 ? text : text.substring(0, i);
    }();
    // ignore: avoid_print
    print(
      '[Sync] url=${_tailUrl(url)} status=${response.statusCode} '
      'bytes=${text.length} firstLine=${firstLine.substring(
        0,
        firstLine.length.clamp(0, 160),
      )}',
    );

    // 공유 설정 문제로 로그인/에러 HTML 페이지로 리다이렉트된 경우 감지.
    final leading = text.trimLeft().toLowerCase();
    if (leading.startsWith('<!doctype') || leading.startsWith('<html')) {
      throw Exception(
        'CSV 대신 HTML이 돌아왔습니다. 시트 공유를 "링크가 있는 모든 사용자(뷰어)"로 바꿔주세요. ($url)',
      );
    }

    if (!kIsWeb && text.length > 120000) {
      return compute(_parseRowsIsolate, text);
    }
    await _yieldForUi();
    return _parseRows(text);
  }

  String _tailUrl(String url) {
    if (url.length <= 80) return url;
    return '...${url.substring(url.length - 80)}';
  }

  Future<List<Map<String, String>>> _fetchCsvRowsOptional(String url) async {
    if (url.trim().isEmpty) {
      return const [];
    }
    try {
      return await _fetchCsvRows(url);
    } catch (_) {
      return const [];
    }
  }

  List<Map<String, String>> _parseRows(String csvText) {
    return _parseRowsIsolate(csvText);
  }
}

List<Map<String, String>> _parseRowsIsolate(String csvText) {
  // Google Sheets (gviz/export)는 거의 항상 CRLF로 행을 끝낸다.
  // csv 6.0의 CsvToListConverter는 eol이 실제 줄바꿈과 정확히 일치해야
  // 따옴표/멀티라인 필드를 안전하게 분리한다. 불일치 시 모든 데이터가
  // 한 필드로 뭉쳐지는 증상이 발생하므로, LF로 선정규화 후 파싱한다.
  var text = csvText;
  if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
    text = text.substring(1); // UTF-8 BOM 제거
  }
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  final matrix = const CsvToListConverter(
    eol: '\n',
    shouldParseNumbers: false,
  ).convert(text);
  if (matrix.isEmpty) {
    return const [];
  }
  final header = matrix.first.map((e) {
    var s = e.toString();
    if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
      s = s.substring(1);
    }
    return s.trim();
  }).toList();
  final rows = <Map<String, String>>[];
  for (var rowIndex = 1; rowIndex < matrix.length; rowIndex++) {
    final row = matrix[rowIndex];
    if (row.every((cell) => cell.toString().trim().isEmpty)) {
      continue;
    }
    final map = <String, String>{};
    for (var col = 0; col < header.length; col++) {
      map[header[col]] = col < row.length ? row[col].toString().trim() : '';
    }
    rows.add(map);
  }
  return rows;
}
