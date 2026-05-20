/// Situational 시트의 **한 CSV 행**을 표현하는 Hive 친화 모델.
///
/// Announcements/Routes 등 다른 마스터 데이터와 동일한 패턴으로
/// `fromCsvMap` → Hive `toMap` → `fromMap` 파이프라인을 타기 위해 도입.
/// 이렇게 해야 Hive 복원 과정에서 타입/키가 뭉개지는 문제가 사라진다.
class SituationalRowModel {
  const SituationalRowModel({
    required this.category,
    required this.subCategory,
    required this.scenario,
    required this.order,
    required this.title,
    required this.optional,
    required this.rowType,
    required this.optionGroup,
    required this.optionSubGroup,
    required this.contentKo,
    required this.contentEn,
    this.timing = '',
    this.etcNote = '',
    this.linkTarget = '',
    this.conditionTag = '',
  });

  final String category;
  final String subCategory;
  final String scenario;
  final String order;
  final String title;
  final String optional;
  final String rowType;
  final String optionGroup;
  final String optionSubGroup;
  final String contentKo;
  final String contentEn;

  final String timing;
  final String etcNote;
  final String linkTarget;

  /// Announcements/Emergency 와 같은 규칙의 조건 태그. 비어 있으면 항상 포함된다.
  final String conditionTag;

  factory SituationalRowModel.fromCsvMap(Map<String, String> row) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = row[k];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      // 대소문자/공백 차이 방어
      final normalized = <String, String>{
        for (final e in row.entries) e.key.trim().toLowerCase(): e.value,
      };
      for (final k in keys) {
        final v = normalized[k.trim().toLowerCase()];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final conditionRaw =
        pick(const ['Condition_Tag', 'condition_tag', 'ConditionTag']);
    final conditionTag =
        conditionRaw.isEmpty || conditionRaw.toLowerCase() == 'none'
            ? ''
            : conditionRaw;

    return SituationalRowModel(
      category: pick(const ['Category', 'category']),
      subCategory: pick(const ['SubCategory', 'subCategory', 'sub_category']),
      scenario: pick(const ['Scenario', 'scenario']),
      order: pick(const ['Order', 'order']),
      title: pick(const ['Title', 'title']),
      optional: pick(const ['Optional', 'optional']),
      rowType: pick(const ['RowType', 'rowType', 'row_type']),
      optionGroup: pick(const ['OptionGroup', 'optionGroup', 'option_group']),
      optionSubGroup: pick(const [
        'OptionSubGroup',
        'optionSubGroup',
        'option_sub_group',
      ]),
      contentKo: pick(const ['Content_KO', 'content_ko', 'ContentKo']),
      contentEn: pick(const ['Content_EN', 'content_en', 'ContentEn']),
      timing: pick(const ['Timing', 'timing', 'TIMING']),
      etcNote: pick(const ['etc', 'Etc', 'ETC', 'etc_note', 'Etc_Note']),
      linkTarget: pick(const ['Link', 'link', 'LINK', 'link_target']),
      conditionTag: conditionTag,
    );
  }

  factory SituationalRowModel.fromMap(Map<dynamic, dynamic> map) {
    String s(dynamic v) => (v ?? '').toString();
    return SituationalRowModel(
      category: s(map['category']),
      subCategory: s(map['subCategory']),
      scenario: s(map['scenario']),
      order: s(map['order']),
      title: s(map['title']),
      optional: s(map['optional']),
      rowType: s(map['rowType']),
      optionGroup: s(map['optionGroup']),
      optionSubGroup: s(map['optionSubGroup']),
      contentKo: s(map['contentKo']),
      contentEn: s(map['contentEn']),
      timing: s(map['timing']),
      etcNote: s(map['etcNote']),
      linkTarget: s(map['linkTarget']),
      conditionTag: s(map['conditionTag']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'subCategory': subCategory,
      'scenario': scenario,
      'order': order,
      'title': title,
      'optional': optional,
      'rowType': rowType,
      'optionGroup': optionGroup,
      'optionSubGroup': optionSubGroup,
      'contentKo': contentKo,
      'contentEn': contentEn,
      'timing': timing,
      'etcNote': etcNote,
      'linkTarget': linkTarget,
      'conditionTag': conditionTag,
    };
  }

  /// 파싱 로직이 기대하는 원본 CSV-유사 Map 형태로 되돌린다.
  /// (`SituationalScriptsRepository.parseRows` 가 이 헤더 키를 읽도록 맞춰둠.)
  Map<String, String> toCsvMap() {
    return {
      'Category': category,
      'SubCategory': subCategory,
      'Scenario': scenario,
      'Order': order,
      'Title': title,
      'Optional': optional,
      'RowType': rowType,
      'OptionGroup': optionGroup,
      'OptionSubGroup': optionSubGroup,
      'Content_KO': contentKo,
      'Content_EN': contentEn,
      'Timing': timing,
      'Etc': etcNote,
      'Link': linkTarget,
      'Condition_Tag': conditionTag,
    };
  }

  bool get isEmpty =>
      category.isEmpty &&
      subCategory.isEmpty &&
      scenario.isEmpty &&
      order.isEmpty &&
      title.isEmpty &&
      contentKo.isEmpty &&
      contentEn.isEmpty &&
      optionGroup.isEmpty;
}
