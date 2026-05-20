import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../domain/entities/situational_script.dart';
import '../models/situational_row_model.dart';

class SituationalScriptsRepository {
  /// 최초 실행 / 동기화 실패 시의 fallback용 로컬 에셋.
  static const String assetPath = 'assets/data/annc_go - Situational.csv';

  /// Row 모델(`SituationalRowModel`) 목록을 `SituationalScript` 리스트로 파싱.
  ///
  /// CSV 스키마:
  ///   Category, SubCategory, Scenario, Order, Title, Optional,
  ///   RowType, OptionGroup, OptionSubGroup, Content_KO, Content_EN,
  ///   Timing, Etc, Link (선택 — 시나리오 단위 메타, 임의 행에 기입.
  ///   `Link` 는 `|` 로 여러 대상을 한 칸에 나열할 수 있음)
  ///   Condition_Tag (선택 — Announcements `Condition_Tag` 와 동일 규칙)
  ///
  /// - `Scenario` = 하나의 방송 단위(Announcements의 Phase에 대응).
  /// - `Order`    = 같은 Scenario 내부에서 섹션들이 낭독되는 순서.
  ///                **섹션 식별은 `Scenario + Order` 로 충분하다.**
  /// - `Title`    = 섹션 이름(표시용). option 행에선 비워둬도 되고,
  ///                같은 Order의 base 행이 가진 Title이 섹션 이름으로 사용된다.
  /// - `Optional` = 'optional' / 'y' / 'true' 이면 "필요시" 섹션.
  ///
  /// 하위 호환: `Scenario`가 비어 있는 row는 `Title` 값을 Scenario로 간주하고
  /// 섹션 Title을 빈 문자열로 처리한다(기존 단일 섹션 데이터).
  List<SituationalScript> parseRows(List<SituationalRowModel> rows) {
    if (rows.isEmpty) return const [];

    final scenarioById = <String, _ScenarioBuilder>{};
    final scenarioOrderedIds = <String>[];

    for (final row in rows) {
      final category = row.category;
      final sub = row.subCategory;
      final scenarioRaw = row.scenario;
      final sectionTitleRaw = row.title;

      // Scenario 컬럼이 비어 있으면 기존 Title 값을 Scenario로 간주(하위 호환).
      final scenario = scenarioRaw.isNotEmpty ? scenarioRaw : sectionTitleRaw;
      final sectionTitle = scenarioRaw.isNotEmpty ? sectionTitleRaw : '';

      if (category.isEmpty || scenario.isEmpty) continue;

      final order = int.tryParse(row.order) ?? 0;
      final optionalRaw = row.optional.toLowerCase();
      final isOptional = optionalRaw == 'optional' ||
          optionalRaw == 'y' ||
          optionalRaw == 'yes' ||
          optionalRaw == 'true' ||
          optionalRaw == '1';
      final rowType = row.rowType.toLowerCase();

      final scenarioId = '$category::$sub::$scenario';
      final scenarioBuilder = scenarioById.putIfAbsent(scenarioId, () {
        scenarioOrderedIds.add(scenarioId);
        return _ScenarioBuilder(
          id: scenarioId,
          category: category,
          subCategory: sub,
          scenario: scenario,
        );
      });

      // 섹션은 Scenario 내부에서 `Order` 하나로 유니크하게 식별된다.
      // option 행이 Title을 비워두고 같은 Order에만 맞춰 넣어도 base 행과
      // 자연스럽게 한 섹션으로 묶이도록 한다.
      final sectionKey = '$order';
      final sectionBuilder =
          scenarioBuilder.sections.putIfAbsent(sectionKey, () {
        return _SectionBuilder(order: order);
      });

      if (sectionTitle.isNotEmpty && sectionBuilder.title.isEmpty) {
        sectionBuilder.title = sectionTitle;
      }
      if (isOptional) sectionBuilder.isOptional = true;

      if (row.timing.isNotEmpty) {
        scenarioBuilder.timing = row.timing;
      }
      if (row.etcNote.isNotEmpty) {
        scenarioBuilder.etcNote = row.etcNote;
      }
      if (row.linkTarget.isNotEmpty) {
        scenarioBuilder.linkTarget = row.linkTarget;
      }

      if (rowType == 'base' || rowType.isEmpty) {
        if (row.contentKo.isNotEmpty) sectionBuilder.contentKo = row.contentKo;
        if (row.contentEn.isNotEmpty) sectionBuilder.contentEn = row.contentEn;
      } else if (rowType == 'option' ||
          rowType == 'option_inline' ||
          rowType == 'inline_option' ||
          rowType == 'inline' ||
          rowType == 'dropdown') {
        final group = row.optionGroup;
        if (group.isEmpty) continue;

        // RowType별 표시 모드 결정. 기본값(`option`)은 바텀시트.
        final mode = (rowType == 'option_inline' ||
                rowType == 'inline_option' ||
                rowType == 'inline' ||
                rowType == 'dropdown')
            ? OptionDisplayMode.inline
            : OptionDisplayMode.sheet;
        // 같은 그룹의 첫 번째 mode를 채택한다(섞여 들어온 경우 첫 mode 우선).
        sectionBuilder.optionModes.putIfAbsent(group, () => mode);

        sectionBuilder.options
            .putIfAbsent(group, () => <SituationalOption>[])
            .add(
              SituationalOption(
                group: group,
                subGroup: row.optionSubGroup,
                contentKo: row.contentKo,
                contentEn: row.contentEn,
              ),
            );
      }
    }

    // 사용자가 시트에 본문/옵션 한 줄도 안 적어둔 시나리오(= scenario 이름만
    // 있고 base/option content가 전부 비어있는 stub)는 카드로 만들지 않는다.
    // "category 외에는 내가 시트에 적은 것만 보여라"라는 방침을 충실히 따른다.
    return [
      for (final id in scenarioOrderedIds)
        scenarioById[id]!.build(),
    ].where((s) => s.hasAnyContent || s.hasAnyOptions).toList();
  }

  /// 로컬 에셋에서 row 모델 목록을 읽어 파싱.
  Future<List<SituationalRowModel>> readRowModelsFromAsset() async {
    final raw = await rootBundle.loadString(assetPath);
    final maps = _parseCsvToRows(raw);
    return maps.map(SituationalRowModel.fromCsvMap).toList();
  }

  /// 레거시 경로: 로컬 에셋에서 직접 파싱. Master bundle 경로 실패 시 fallback.
  Future<List<SituationalScript>> loadAllFromAsset() async {
    final rows = await readRowModelsFromAsset();
    return parseRows(rows);
  }

  List<Map<String, String>> _parseCsvToRows(String raw) {
    // CRLF 혼용 방지: 파서에 넣기 전에 항상 LF로 정규화한다.
    var text = raw;
    if (text.isNotEmpty && text.codeUnitAt(0) == 0xFEFF) {
      text = text.substring(1);
    }
    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    final matrix = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);
    if (matrix.isEmpty) return const [];
    final header = matrix.first.map((e) {
      var s = e.toString();
      if (s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF) {
        s = s.substring(1);
      }
      return s.trim();
    }).toList();
    final out = <Map<String, String>>[];
    for (var r = 1; r < matrix.length; r++) {
      final row = matrix[r];
      if (row.every((cell) => cell.toString().trim().isEmpty)) continue;
      final map = <String, String>{};
      for (var c = 0; c < header.length; c++) {
        map[header[c]] = c < row.length ? row[c].toString().trim() : '';
      }
      out.add(map);
    }
    return out;
  }
}

class _ScenarioBuilder {
  _ScenarioBuilder({
    required this.id,
    required this.category,
    required this.subCategory,
    required this.scenario,
  });

  final String id;
  final String category;
  final String subCategory;
  final String scenario;

  // 섹션 key → builder. 삽입 순서 유지(LinkedHashMap).
  final Map<String, _SectionBuilder> sections = <String, _SectionBuilder>{};

  String timing = '';
  String etcNote = '';
  String linkTarget = '';

  SituationalScript build() {
    final built = sections.values
        .map((b) => b.build())
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return SituationalScript(
      id: id,
      category: category,
      subCategory: subCategory,
      scenario: scenario,
      sections: List.unmodifiable(built),
      timing: timing,
      etcNote: etcNote,
      linkTarget: linkTarget,
    );
  }
}

class _SectionBuilder {
  _SectionBuilder({required this.order});

  final int order;
  String title = '';
  bool isOptional = false;
  String contentKo = '';
  String contentEn = '';
  final Map<String, List<SituationalOption>> options =
      <String, List<SituationalOption>>{};
  final Map<String, OptionDisplayMode> optionModes =
      <String, OptionDisplayMode>{};

  SituationalSection build() {
    final seen = <String>{};
    final orderedTokens = <String>[];
    for (final t in SituationalScript.extractTokens(contentKo)) {
      if (seen.add(t)) orderedTokens.add(t);
    }
    for (final t in SituationalScript.extractTokens(contentEn)) {
      if (seen.add(t)) orderedTokens.add(t);
    }
    // base 본문에 아직 {{TOKEN}}이 안 들어있어도, option 행이 있는 그룹은
    // 선택 UI가 필요하므로 토큰 목록에 포함시킨다.
    // (본문 작성 전 단계에서 옵션부터 입력하는 워크플로우 지원)
    for (final group in options.keys) {
      if (seen.add(group)) orderedTokens.add(group);
    }
    return SituationalSection(
      order: order,
      title: title,
      isOptional: isOptional,
      contentKo: contentKo,
      contentEn: contentEn,
      optionGroups: Map.unmodifiable(options),
      optionGroupModes: Map.unmodifiable(optionModes),
      tokens: List.unmodifiable(orderedTokens),
    );
  }
}
