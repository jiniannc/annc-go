import '../entities/situational_script.dart';

String _normCat(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// 시나리오 표시명 비교용 (공백·NBSP·연속 공백 정리). 링크 문자열과 CSV 값
/// 미세하게 달라도 같은 문구로 맞춘다.
String _normScenarioLabel(String s) => s
    .trim()
    .replaceAll('\u00A0', ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

bool _scenarioLabelEquals(String a, String b) =>
    _normScenarioLabel(a) == _normScenarioLabel(b);

bool _scenarioLabelEqualsIgnoreCase(String a, String b) =>
    _normScenarioLabel(a).toLowerCase() == _normScenarioLabel(b).toLowerCase();

/// [raw] — 시트 `Link` 컬럼의 **한 조각**(UI에서 `|` 로 나눈 뒤 각각 호출).
/// 다음 형식을 지원한다.
/// - 전체 id: `Category::SubCategory::Scenario` ([SituationalScript.id]와 동일)
///   시나리오 이름에 `:` 가 들어가도 되며, `::` 로만 구분한다(세 번째 토큰은
///   `parts.sublist(2).join('::')` 로 복원).
/// - `카테고리라벨|시나리오이름` — 동일 시나리오명이 여러 개일 때 구분
/// - `시나리오이름`만 — 전역에서 **한 건**이면 그대로, 복수면 [from]과 같은
///   `category` 를 우선한다. 그래도 복수면 CSV 순서상 첫 일치(호출부 리스트 순).
SituationalScript? resolveSituationalLink(
  List<SituationalScript> all,
  String raw, {
  SituationalScript? from,
}) {
  final q = raw.trim();
  if (q.isEmpty) return null;

  if (q.contains('::')) {
    for (final s in all) {
      if (s.id == q) return s;
    }
    final parts = q.split('::');
    if (parts.length >= 3) {
      final cat = parts[0].trim();
      final sub = parts[1].trim();
      final scen = parts.sublist(2).join('::').trim();
      final id2 = '$cat::$sub::$scen';
      for (final s in all) {
        if (s.id == id2) return s;
      }
      for (final s in all) {
        if (s.category.trim() == cat &&
            s.subCategory.trim() == sub &&
            _scenarioLabelEquals(s.scenario, scen)) {
          return s;
        }
      }
    }
  }

  if (q.contains('|') && !q.contains('::')) {
    final segs = q.split('|');
    if (segs.length == 2) {
      final wantCat = _normCat(segs[0]);
      final wantScen = segs[1].trim();
      for (final s in all) {
        if (_normCat(s.category) == wantCat &&
            _scenarioLabelEquals(s.scenario, wantScen)) {
          return s;
        }
      }
    }
  }

  SituationalScript? one(List<SituationalScript> cands) {
    if (cands.isEmpty) return null;
    if (cands.length == 1) return cands.first;
    final origin = from;
    if (origin != null) {
      final same = cands.where((s) => s.category == origin.category);
      if (same.length == 1) return same.first;
      if (same.isNotEmpty) return same.first;
    }
    return cands.first;
  }

  final exact = all.where((s) => _scenarioLabelEquals(s.scenario, q)).toList();
  if (exact.isNotEmpty) return one(exact);

  final fold =
      all.where((s) => _scenarioLabelEqualsIgnoreCase(s.scenario, q)).toList();
  return one(fold);
}
