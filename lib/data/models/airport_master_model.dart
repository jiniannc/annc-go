class AirportMasterModel {
  const AirportMasterModel({
    required this.iataCode,
    required this.cityKo,
    required this.cityEn,
    required this.airportKo,
    required this.airportEn,
    required this.isMilitary,
    required this.timeZone,
    required this.specialFarewellItems,
  });

  final String iataCode;
  final String cityKo;
  final String cityEn;
  final String airportKo;
  final String airportEn;
  final bool isMilitary;
  final String timeZone;
  final List<String> specialFarewellItems;

  factory AirportMasterModel.fromCsvMap(Map<String, String> row) {
    return AirportMasterModel(
      iataCode: (row['IATA_Code'] ?? '').trim().toUpperCase(),
      cityKo: (row['City_KO'] ?? '').trim(),
      cityEn: (row['City_EN'] ?? '').trim(),
      airportKo: (row['Airport_KO'] ?? '').trim(),
      airportEn: (row['Airport_EN'] ?? '').trim(),
      isMilitary: _boolFromString(row['is_Military']),
      timeZone: (row['Time_Zone'] ?? '').trim(),
      specialFarewellItems: _splitPipeItems(
        _readCsvValue(
          row,
          const ['special_farewell', 'Special_Farewell', 'specialFarewell'],
        ),
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'iataCode': iataCode,
      'cityKo': cityKo,
      'cityEn': cityEn,
      'airportKo': airportKo,
      'airportEn': airportEn,
      'isMilitary': isMilitary,
      'timeZone': timeZone,
      'specialFarewellItems': specialFarewellItems,
    };
  }

  factory AirportMasterModel.fromMap(Map<dynamic, dynamic> map) {
    return AirportMasterModel(
      iataCode: (map['iataCode'] ?? '').toString(),
      cityKo: (map['cityKo'] ?? '').toString(),
      cityEn: (map['cityEn'] ?? '').toString(),
      airportKo: (map['airportKo'] ?? '').toString(),
      airportEn: (map['airportEn'] ?? '').toString(),
      isMilitary: map['isMilitary'] == true,
      timeZone: (map['timeZone'] ?? '').toString(),
      specialFarewellItems:
          (map['specialFarewellItems'] as List<dynamic>? ?? const [])
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(),
    );
  }
}

bool _boolFromString(String? value) =>
    (value ?? '').trim().toUpperCase() == 'TRUE';

List<String> _splitPipeItems(String raw) {
  if (raw.trim().isEmpty) {
    return const [];
  }
  return raw
      .split('|')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

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
