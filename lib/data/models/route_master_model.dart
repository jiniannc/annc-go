class RouteMasterModel {
  const RouteMasterModel({
    required this.routeId,
    required this.routeName,
    required this.phaseSequence,
    required this.haul,
    required this.internationalDomestic,
    required this.country,
    required this.outInbound,
    required this.remarks,
  });

  final String routeId;
  final String routeName;
  final List<String> phaseSequence;
  final String haul;
  final String internationalDomestic;
  final String country;
  final String outInbound;
  final String remarks;

  factory RouteMasterModel.fromCsvMap(Map<String, String> row) {
    final sequenceRaw = (row['Phase_Sequence (쉼표로 구분)'] ?? '').trim();
    return RouteMasterModel(
      routeId: (row['Route_ID'] ?? '').trim(),
      routeName: (row['Route_Name'] ?? '').trim(),
      phaseSequence: sequenceRaw
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      haul: _readAny(row, const ['Haul']).trim(),
      internationalDomestic: _readAny(
        row,
        const ['International/domestic', 'International/Domestic'],
      ).trim(),
      country: _readAny(row, const ['Country']).trim(),
      outInbound: _readAny(row, const ['Out/Inbound', 'Out/inbound']).trim(),
      remarks: (row['Remarks'] ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'routeId': routeId,
      'routeName': routeName,
      'phaseSequence': phaseSequence,
      'haul': haul,
      'internationalDomestic': internationalDomestic,
      'country': country,
      'outInbound': outInbound,
      'remarks': remarks,
    };
  }

  factory RouteMasterModel.fromMap(Map<dynamic, dynamic> map) {
    return RouteMasterModel(
      routeId: (map['routeId'] ?? '').toString(),
      routeName: (map['routeName'] ?? '').toString(),
      phaseSequence: (map['phaseSequence'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      haul: (map['haul'] ?? '').toString(),
      internationalDomestic: (map['internationalDomestic'] ?? '').toString(),
      country: (map['country'] ?? '').toString(),
      outInbound: (map['outInbound'] ?? '').toString(),
      remarks: (map['remarks'] ?? '').toString(),
    );
  }
}

String _readAny(Map<String, String> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    if (value != null && value.trim().isNotEmpty) {
      return value;
    }
  }
  return '';
}
