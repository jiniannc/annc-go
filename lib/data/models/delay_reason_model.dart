class DelayReasonModel {
  const DelayReasonModel({
    required this.id,
    required this.reasonKo,
    required this.reasonEn,
    required this.note,
  });

  final String id;
  final String reasonKo;
  final String reasonEn;
  final String note;

  factory DelayReasonModel.fromCsvMap(
    Map<String, String> row, {
    required int index,
  }) {
    return DelayReasonModel(
      id: ((row['ID'] ?? '').trim().isEmpty
          ? 'delay_$index'
          : row['ID']!.trim()),
      reasonKo: (row['Reason_KO (한국어)'] ?? '').trim(),
      reasonEn: (row['Reason_EN (영어)'] ?? '').trim(),
      note: (row['비고'] ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'reasonKo': reasonKo, 'reasonEn': reasonEn, 'note': note};
  }

  factory DelayReasonModel.fromMap(Map<dynamic, dynamic> map) {
    return DelayReasonModel(
      id: (map['id'] ?? '').toString(),
      reasonKo: (map['reasonKo'] ?? '').toString(),
      reasonEn: (map['reasonEn'] ?? '').toString(),
      note: (map['note'] ?? '').toString(),
    );
  }
}
