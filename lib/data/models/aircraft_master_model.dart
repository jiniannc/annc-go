/// `aircraft_master.Lifevest` 값 파싱 결과 — 구명조끼 챔버 구분용 태그 매칭에 사용.
enum LifevestChamberKind { unknown, oneChamber, twoChamber }

/// 예: `Two Chamber`, `one chamber`, `2 chamber` 등 시트 표기 변형 허용.
LifevestChamberKind parseLifevestKind(String raw) {
  final s = raw.trim().toLowerCase();
  if (s.isEmpty || s == '-' || s == 'n/a' || s == 'na') {
    return LifevestChamberKind.unknown;
  }
  final compact = s.replaceAll(RegExp(r'[\s\-]+'), '');
  final mentionsChamber = s.contains('chamber');
  final twoish = compact.contains('twochamber') ||
      compact.contains('2chamber') ||
      (mentionsChamber && RegExp(r'\b2\b').hasMatch(s)) ||
      compact.contains('dualchamber') ||
      compact == 'dual';
  final oneish = compact.contains('onechamber') ||
      compact.contains('1chamber') ||
      (mentionsChamber && RegExp(r'\b1\b').hasMatch(s)) ||
      compact.contains('singlechamber');
  if (twoish && !oneish) return LifevestChamberKind.twoChamber;
  if (oneish && !twoish) return LifevestChamberKind.oneChamber;
  if (twoish && oneish) return LifevestChamberKind.unknown;
  if (mentionsChamber) {
    if (s.contains('two')) return LifevestChamberKind.twoChamber;
    if (s.contains('one')) return LifevestChamberKind.oneChamber;
  }
  return LifevestChamberKind.unknown;
}

class AircraftMasterModel {
  const AircraftMasterModel({
    required this.hlNo,
    required this.model,
    required this.hasFootrest,
    required this.hasIsps,
    required this.hasWifi,
    required this.remarks,
    this.lifevest = '',
  });

  final String hlNo;
  final String model;
  final bool hasFootrest;
  final bool hasIsps;
  final bool hasWifi;
  final String remarks;

  /// 구명조끼 챔버 구분 원문 (예: Two Chamber / One Chamber).
  final String lifevest;

  LifevestChamberKind get lifevestKind => parseLifevestKind(lifevest);

  factory AircraftMasterModel.fromCsvMap(Map<String, String> row) {
    return AircraftMasterModel(
      hlNo: _readCsvValue(row, const ['HL_No (기번)', 'HL_No', 'hl_no'])
          .trim()
          .toUpperCase(),
      model: _readCsvValue(row, const ['Model (기종)', 'Model', 'model']).trim(),
      hasFootrest: _boolFromString(
        _readCsvValue(row, const ['has_Footrest', 'has_footrest']),
      ),
      hasIsps: _boolFromString(
        _readCsvValue(
          row,
          const ['has_ISPS (전원)', 'has_ISPS', 'has_isps'],
        ),
      ),
      hasWifi: _boolFromString(
        _readCsvValue(row, const ['has_WiFi', 'has_wifi']),
      ),
      lifevest: _readCsvValue(row, const [
        'Lifevest',
        'lifevest',
        'Life vest',
        'Life_Vest',
      ]).trim(),
      remarks: _readCsvValue(row, const ['Remarks', 'remarks']).trim(),
    );
  }

  List<String> get featureLabelsKo {
    final labels = <String>[];
    if (hasFootrest) {
      labels.add('풋레스트');
    }
    if (hasIsps) {
      labels.add('전원');
    }
    if (hasWifi) {
      labels.add('와이파이');
    }
    return labels;
  }

  Map<String, dynamic> toMap() {
    return {
      'hlNo': hlNo,
      'model': model,
      'hasFootrest': hasFootrest,
      'hasIsps': hasIsps,
      'hasWifi': hasWifi,
      'remarks': remarks,
      'lifevest': lifevest,
    };
  }

  factory AircraftMasterModel.fromMap(Map<dynamic, dynamic> map) {
    return AircraftMasterModel(
      hlNo: (map['hlNo'] ?? '').toString(),
      model: (map['model'] ?? '').toString(),
      hasFootrest: map['hasFootrest'] == true,
      hasIsps: map['hasIsps'] == true,
      hasWifi: map['hasWifi'] == true,
      remarks: (map['remarks'] ?? '').toString(),
      lifevest: (map['lifevest'] ?? '').toString(),
    );
  }
}

bool _boolFromString(String? value) =>
    (value ?? '').trim().toUpperCase() == 'TRUE';

String _readCsvValue(Map<String, String> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }
  }
  final normalized = <String, String>{
    for (final e in row.entries) e.key.trim().toLowerCase(): e.value,
  };
  for (final key in keys) {
    final value = normalized[key.trim().toLowerCase()];
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }
  }
  return '';
}
