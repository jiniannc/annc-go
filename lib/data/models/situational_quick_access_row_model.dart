/// `Situational_Quick_Access` 시트의 한 행 — 키워드·아이콘으로 시나리오 바로가기용.
///
/// 스프레드시트 권장 헤더:
/// `Keyword, Icon, Order, Category, SubCategory, Scenario, Title`
/// - **Keyword**: 1단계 그리드에 보이는 키워드(예: 지연).
/// - **Category / SubCategory / Scenario**: `Situational` 시트와 동일한 값으로 매칭.
/// - **Title**: 2단계 목록에 표시할 짧은 라벨(비우면 Scenario 사용).
/// - **Icon**: Material 아이콘 이름(예: `schedule_rounded`). 비우면 기본 아이콘.
/// - **Order**: 같은 Keyword 안 정렬(오름차순).
class SituationalQuickAccessRowModel {
  const SituationalQuickAccessRowModel({
    required this.keyword,
    required this.iconName,
    required this.order,
    required this.situationalCategory,
    required this.subCategory,
    required this.scenario,
    required this.listTitle,
  });

  final String keyword;
  final String iconName;
  final int order;
  final String situationalCategory;
  final String subCategory;
  final String scenario;

  /// 2단계 리스트 라벨. 비어 있으면 UI에서 [scenario]를 쓴다.
  final String listTitle;

  factory SituationalQuickAccessRowModel.fromCsvMap(Map<String, String> row) {
    String pick(List<String> keys) {
      for (final k in keys) {
        final v = row[k];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      final normalized = <String, String>{
        for (final e in row.entries) e.key.trim().toLowerCase(): e.value,
      };
      for (final k in keys) {
        final v = normalized[k.trim().toLowerCase()];
        if (v != null && v.trim().isNotEmpty) return v.trim();
      }
      return '';
    }

    final orderRaw = pick(const ['Order', 'order', 'Sort', 'sort', 'Sort_Order']);
    return SituationalQuickAccessRowModel(
      keyword: pick(const ['Keyword', 'keyword', 'KEY', 'Key']),
      iconName: pick(const ['Icon', 'icon', 'ICON', 'Icon_Name']),
      order: int.tryParse(orderRaw) ?? 0,
      situationalCategory: pick(const [
        'Category',
        'category',
        'CAT',
        'Situational_Category',
        'Target_Category',
      ]),
      subCategory: pick(const [
        'SubCategory',
        'subCategory',
        'sub_category',
        'Sub_Category',
      ]),
      scenario: pick(const ['Scenario', 'scenario', 'Scene']),
      listTitle: pick(const ['Title', 'title', 'Label', 'label', 'List_Title']),
    );
  }

  factory SituationalQuickAccessRowModel.fromMap(Map<dynamic, dynamic> map) {
    String s(dynamic v) => (v ?? '').toString();
    return SituationalQuickAccessRowModel(
      keyword: s(map['keyword']),
      iconName: s(map['iconName']),
      order: int.tryParse(s(map['order'])) ?? 0,
      situationalCategory: s(map['situationalCategory']),
      subCategory: s(map['subCategory']),
      scenario: s(map['scenario']),
      listTitle: s(map['listTitle']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'keyword': keyword,
      'iconName': iconName,
      'order': order,
      'situationalCategory': situationalCategory,
      'subCategory': subCategory,
      'scenario': scenario,
      'listTitle': listTitle,
    };
  }

  bool get isEmpty =>
      situationalCategory.isEmpty || scenario.isEmpty;

  String get effectiveListTitle {
    final t = listTitle.trim();
    return t.isNotEmpty ? t : scenario;
  }

  /// 미니 그리드 셀에 표시할 짧은 라벨 — `Keyword` 컬럼 우선.
  String get gridCellLabel {
    final k = keyword.trim();
    if (k.isNotEmpty) return k;
    return effectiveListTitle;
  }
}
