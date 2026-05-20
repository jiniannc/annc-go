class UiControlOption {
  const UiControlOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

class UiControlModel {
  const UiControlModel({
    required this.controlKey,
    required this.phaseId,
    required this.type,
    required this.labelKo,
    required this.labelEn,
    required this.defaultValue,
    required this.optionsRaw,
    required this.order,
    required this.visibleWhen,
  });

  final String controlKey;
  final String phaseId;
  final String type;
  final String labelKo;
  final String labelEn;
  final String defaultValue;
  final String optionsRaw;
  final int order;
  final String visibleWhen;

  bool get isToggle => type.toLowerCase() == 'toggle';
  bool get isSelect => type.toLowerCase() == 'select';

  List<UiControlOption> get options {
    final chunks = optionsRaw
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (chunks.isEmpty) {
      return const [];
    }
    return chunks.map((chunk) {
      final idx = chunk.indexOf(':');
      if (idx < 0) {
        return UiControlOption(value: chunk, label: chunk);
      }
      final value = chunk.substring(0, idx).trim();
      final label = chunk.substring(idx + 1).trim();
      return UiControlOption(
        value: value,
        label: label.isEmpty ? value : label,
      );
    }).toList();
  }

  factory UiControlModel.fromCsvMap(Map<String, String> row) {
    return UiControlModel(
      controlKey: (row['ControlKey'] ?? '').trim().toLowerCase(),
      phaseId: (row['PhaseID'] ?? '').trim(),
      type: (row['Type'] ?? '').trim().toLowerCase(),
      labelKo: (row['Label_KO'] ?? '').trim(),
      labelEn: (row['Label_EN'] ?? '').trim(),
      defaultValue: (row['DefaultValue'] ?? '').trim().toLowerCase(),
      optionsRaw: (row['Options'] ?? '').trim(),
      order: int.tryParse((row['Order'] ?? '').trim()) ?? 0,
      visibleWhen: (row['Visible_When'] ?? '').trim(),
    );
  }

  factory UiControlModel.fromMap(Map<dynamic, dynamic> map) {
    return UiControlModel(
      controlKey: (map['controlKey'] ?? '').toString(),
      phaseId: (map['phaseId'] ?? '').toString(),
      type: (map['type'] ?? '').toString(),
      labelKo: (map['labelKo'] ?? '').toString(),
      labelEn: (map['labelEn'] ?? '').toString(),
      defaultValue: (map['defaultValue'] ?? '').toString(),
      optionsRaw: (map['optionsRaw'] ?? '').toString(),
      order: map['order'] as int? ?? 0,
      visibleWhen: (map['visibleWhen'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'controlKey': controlKey,
      'phaseId': phaseId,
      'type': type,
      'labelKo': labelKo,
      'labelEn': labelEn,
      'defaultValue': defaultValue,
      'optionsRaw': optionsRaw,
      'order': order,
      'visibleWhen': visibleWhen,
    };
  }
}
