/// 옵션 그룹의 표시 모드.
///
/// CSV의 `RowType` 값으로 결정된다:
/// - `option`         → [OptionDisplayMode.sheet]  : 바텀시트 picker
///                       (옵션이 많거나 SubGroup으로 분류되는 경우 적합)
/// - `option_inline`  → [OptionDisplayMode.inline] : 인라인 드롭다운
///                       (옵션 개수가 적어 본문 흐름에서 바로 고를 수 있는 경우)
///
/// 동일한 OptionGroup 안의 모든 row는 같은 mode를 가져야 한다.
/// (행마다 다르면 처음 등장한 mode를 그룹의 mode로 채택한다.)
enum OptionDisplayMode { inline, sheet }

/// 한 섹션(Title 단위) 안에서 특정 토큰의 후보가 되는 옵션 한 건.
///
/// 예: "지연 사유" 그룹(`REASON`)의 여러 후보 중 하나 —
/// "승객 탑승이 늦어져서", "기상 관련" 등.
class SituationalOption {
  const SituationalOption({
    required this.group,
    required this.subGroup,
    required this.contentKo,
    required this.contentEn,
  });

  final String group;
  final String subGroup;
  final String contentKo;
  final String contentEn;
}

/// Scenario 안에서 실제 방송되는 한 라인/섹션.
///
/// Announcements CSV의 `Phase → Order → Title → Optional → Content` 구조와 1:1로
/// 대응된다. 한 Section은 자체 토큰(`{{TOKEN}}`)과 그 후보인 OptionGroup을 가질
/// 수 있다.
class SituationalSection {
  const SituationalSection({
    required this.order,
    required this.title,
    required this.isOptional,
    required this.contentKo,
    required this.contentEn,
    required this.optionGroups,
    required this.optionGroupModes,
    required this.tokens,
  });

  /// 같은 Scenario 내부에서의 정렬 기준.
  final int order;

  /// 섹션 이름. 비어 있을 수 있음(단일 섹션 Scenario).
  final String title;

  /// true 이면 "필요시" 배지가 표시되고 기본적으로 미포함 상태로 시작한다.
  final bool isOptional;

  final String contentKo;
  final String contentEn;

  /// 이 섹션 안에서 유효한 옵션 그룹 맵.
  final Map<String, List<SituationalOption>> optionGroups;

  /// 옵션 그룹별 표시 모드. CSV의 `RowType` 값에 의해 결정된다.
  /// 키가 없으면 UI에서 옵션 개수/SubGroup 여부 등을 보고 자동 분기한다.
  final Map<String, OptionDisplayMode> optionGroupModes;

  /// 이 섹션의 본문(KO/EN 둘 다)에 등장한 토큰을 등장 순서로.
  final List<String> tokens;

  bool get hasOptions => optionGroups.isNotEmpty;
  bool get isStub => contentKo.trim().isEmpty && contentEn.trim().isEmpty;
}

/// 하나의 "상황" 단위(Announcements의 Phase 자리에 대응).
///
/// 한 Scenario는 순서대로 방송될 여러 [SituationalSection]으로 구성된다.
/// UI에서는 이 단위가 카드 하나가 되고, 섹션들이 세로로 쌓인다.
class SituationalScript {
  const SituationalScript({
    required this.id,
    required this.category,
    required this.subCategory,
    required this.scenario,
    required this.sections,
    this.timing = '',
    this.etcNote = '',
    this.linkTarget = '',
  });

  final String id;
  final String category;
  final String subCategory;

  /// 기존 CSV의 `Title` 자리. Scenario 이름(예: "출발 지연: General").
  final String scenario;

  /// Order 오름차순으로 정렬된 섹션들.
  final List<SituationalSection> sections;

  /// 타이밍 안내(홈 루틴의 `timing`과 동일 용도). `|` 로 여러 개 가능.
  final String timing;

  /// 기타 비고(홈 `etcNote`과 동일). `|` 로 여러 개 가능.
  final String etcNote;

  /// `Link` — 연결 대상(시나리오명·id·`카테고리|시나리오` 등). `|` 로 여러 개 지정.
  final String linkTarget;

  /// 카드 헤더/제목에 쓰는 대표 라벨 — Scenario 이름.
  String get displayTitle => scenario;

  bool get hasAnyContent => sections.any((s) => !s.isStub);
  bool get hasAnyOptions => sections.any((s) => s.hasOptions);

  /// [includeOptional] 을 반영해 한국어 본문이 실제로 보이는 섹션에 한해,
  /// [SituationalSection.contentEn](스프레드시트의 `Content_EN` 칸)이
  /// 비어 있지 않은 항목이 있는지.
  ///
  /// `필요 시` 블록을 끈 섹션(스크립트 미표시)은 제외한다.
  /// (항공 변수 치환 적용 전 원문 기준.)
  bool hasRenderableContentEnForKoAlignedSections(
    Map<int, bool> includeOptional,
  ) {
    for (var i = 0; i < sections.length; i++) {
      final s = sections[i];
      if (s.isOptional && !(includeOptional[i] ?? false)) continue;
      if (s.contentKo.trim().isEmpty && s.optionGroups.isEmpty) continue;
      if (s.contentEn.trim().isNotEmpty) return true;
    }
    return false;
  }

  /// 전체(필수 + 포함된 선택) 섹션의 토큰 수 합.
  int get totalOptionGroupCount =>
      sections.fold(0, (acc, s) => acc + s.optionGroups.length);

  static final RegExp tokenPattern = RegExp(r'\{\{([A-Z][A-Z0-9_]*)\}\}');

  static List<String> extractTokens(String text) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final m in tokenPattern.allMatches(text)) {
      final key = m.group(1) ?? '';
      if (key.isEmpty) continue;
      if (seen.add(key)) ordered.add(key);
    }
    return ordered;
  }

  /// 선택 상태를 반영하여 최종 문구를 조합한다.
  /// 선택되지 않은 토큰은 [placeholder]로 치환된다.
  static String compose({
    required String template,
    required Map<String, String> selections,
    String placeholder = '(선택 필요)',
  }) {
    return template.replaceAllMapped(tokenPattern, (m) {
      final key = m.group(1) ?? '';
      final value = selections[key];
      if (value == null || value.trim().isEmpty) {
        return placeholder;
      }
      return value;
    });
  }
}
