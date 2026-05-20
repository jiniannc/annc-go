import '../../domain/entities/announcement.dart';

class AnnouncementModel extends Announcement {
  const AnnouncementModel({
    required super.id,
    required super.category,
    required super.flightPhase,
    required super.title,
    required super.contentKR,
    required super.contentEN,
    required this.phaseId,
    super.audioJpUrl,
    super.audioCnUrl,
    super.conditionTag,
    super.order,
    super.isOptional,
    super.optionalStartsCollapsed,
    super.optionalIsSelect,
    super.announcer,
    super.timing,
    super.etcNote,
    this.inlineKey = '',
    this.inlineItemsKo = const [],
    this.inlineItemsEn = const [],
    this.inlineDefaultIndex = 1,
  });

  final String phaseId;
  final String inlineKey;
  final List<String> inlineItemsKo;
  final List<String> inlineItemsEn;
  final int inlineDefaultIndex;

  factory AnnouncementModel.fromMap(Map<dynamic, dynamic> map) {
    return AnnouncementModel(
      id: map['id'] as String,
      category: _categoryFromString(map['category'] as String),
      flightPhase: map['flightPhase'] as String,
      title: map['title'] as String,
      contentKR: map['contentKR'] as String,
      contentEN: map['contentEN'] as String,
      phaseId: map['phaseId'] as String,
      audioJpUrl: (map['audioJpUrl'] as String?)?.trim(),
      audioCnUrl: (map['audioCnUrl'] as String?)?.trim(),
      conditionTag: map['conditionTag'] as String?,
      order: map['order'] as int? ?? 0,
      isOptional: map['isOptional'] == true,
      optionalStartsCollapsed: map['optionalStartsCollapsed'] == true,
      optionalIsSelect: map['optionalIsSelect'] == true,
      announcer: (map['announcer'] ?? '').toString().trim(),
      timing: (map['timing'] ?? '').toString().trim(),
      etcNote: (map['etcNote'] ?? '').toString().trim(),
      inlineKey: (map['inlineKey'] ?? '').toString().trim(),
      inlineItemsKo: (map['inlineItemsKo'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      inlineItemsEn: (map['inlineItemsEn'] as List<dynamic>? ?? const [])
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      inlineDefaultIndex: map['inlineDefaultIndex'] as int? ?? 1,
    );
  }

  /// CSV 한 행을 모델로 변환한다.
  ///
  /// [category] 는 어떤 시트에서 읽었는지에 따라 호출부가 명시한다.
  /// 기본값은 [AnnouncementCategory.routine] (Announcements 시트), Emergency 시트는
  /// [AnnouncementCategory.emergency] 로 호출한다. 컬럼·옵션 처리는 둘 다 동일.
  factory AnnouncementModel.fromCsvMap(
    Map<String, String> row, {
    required int index,
    AnnouncementCategory category = AnnouncementCategory.routine,
  }) {
    final phase = (row['Phase'] ?? '').trim();
    final phaseId = (row['PhaseID'] ?? '').trim();
    final title = (row['Title'] ?? '').trim();
    final conditionTagRaw = (row['Condition_Tag'] ?? '').trim();
    final order = int.tryParse((row['Order'] ?? '').trim()) ?? 0;
    final optionRaw = (row['Option'] ?? '').trim().toLowerCase();
    final isHideOption = optionRaw == 'hide';
    final isSelectOption = optionRaw == 'select';
    final announcer = _readCsvValue(
      row,
      const ['announcer', 'Announcer', 'ANNOUNCER'],
    ).trim();
    final timing = _readCsvValue(
      row,
      const ['timing', 'Timing', 'TIMING'],
    ).trim();
    final etcNote = _readCsvValue(
      row,
      const ['etc', 'Etc', 'ETC', 'etc_note', 'Etc_Note'],
    ).trim();
    final inlineKey = _readCsvValue(
      row,
      const ['Inline_Key', 'inline_key'],
    ).trim();
    final inlineItemsKo = _splitInlineItems(
      _readCsvValue(row, const ['Inline_Items_KO', 'inline_items_ko']),
    );
    final inlineItemsEn = _splitInlineItems(
      _readCsvValue(row, const ['Inline_Items_EN', 'inline_items_en']),
    );
    final inlineDefaultIndexRaw = _readCsvValue(
      row,
      const ['Inline_default_index', 'Inline_Default_Index', 'inline_default_index'],
    ).trim();
    final inlineDefaultIndex = (int.tryParse(inlineDefaultIndexRaw) ?? 1).clamp(
      1,
      inlineItemsKo.isNotEmpty ? inlineItemsKo.length : 9999,
    );

    return AnnouncementModel(
      id: '${phaseId}_${order}_$index',
      category: category,
      flightPhase: phase,
      title: title,
      contentKR: (row['Content_KO'] ?? '').trim(),
      contentEN: (row['Content_EN'] ?? '').trim(),
      phaseId: phaseId,
      audioJpUrl: _normalizeAudioUrl((row['Audio_JP'] ?? '').trim()),
      audioCnUrl: _normalizeAudioUrl((row['Audio_CN'] ?? '').trim()),
      conditionTag: conditionTagRaw.isEmpty || conditionTagRaw == 'None'
          ? null
          : conditionTagRaw,
      order: order,
      isOptional: optionRaw == 'optional' || isHideOption || isSelectOption,
      optionalStartsCollapsed: isHideOption || isSelectOption,
      optionalIsSelect: isSelectOption,
      announcer: announcer,
      timing: timing,
      etcNote: etcNote,
      inlineKey: inlineKey,
      inlineItemsKo: inlineItemsKo,
      inlineItemsEn: inlineItemsEn,
      inlineDefaultIndex: inlineDefaultIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category.name,
      'flightPhase': flightPhase,
      'title': title,
      'contentKR': contentKR,
      'contentEN': contentEN,
      'phaseId': phaseId,
      'audioJpUrl': audioJpUrl,
      'audioCnUrl': audioCnUrl,
      'conditionTag': conditionTag,
      'order': order,
      'isOptional': isOptional,
      'optionalStartsCollapsed': optionalStartsCollapsed,
      'optionalIsSelect': optionalIsSelect,
      'announcer': announcer,
      'timing': timing,
      'etcNote': etcNote,
      'inlineKey': inlineKey,
      'inlineItemsKo': inlineItemsKo,
      'inlineItemsEn': inlineItemsEn,
      'inlineDefaultIndex': inlineDefaultIndex,
    };
  }

  static List<String> _splitInlineItems(String raw) {
    if (raw.trim().isEmpty) {
      return const [];
    }
    return raw
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String _readCsvValue(Map<String, String> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
    final normalized = <String, String>{
      for (final e in row.entries)
        e.key.trim().toLowerCase(): e.value,
    };
    for (final key in keys) {
      final value = normalized[key.trim().toLowerCase()];
      if (value != null && value.trim().isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  static String? _normalizeAudioUrl(String raw) {
    if (raw.trim().isEmpty) {
      return null;
    }
    final source = raw.trim();
    Uri uri;
    try {
      uri = Uri.parse(source);
    } catch (_) {
      return null;
    }
    if (uri.host.toLowerCase().contains('dropbox.com')) {
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['dl'] = '1';
      uri = uri.replace(queryParameters: qp);
    }
    return uri.toString();
  }

  static AnnouncementCategory _categoryFromString(String category) {
    switch (category) {
      case 'situational':
        return AnnouncementCategory.situational;
      case 'emergency':
        return AnnouncementCategory.emergency;
      case 'routine':
      default:
        return AnnouncementCategory.routine;
    }
  }
}
