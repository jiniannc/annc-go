import 'dart:math' as math;

import '../entities/situational_script.dart';

/// Situational 검색 결과에서 "어디에 매칭됐는지" 구분.
enum SituationalSearchMatchField {
  scenarioTitle,
  subCategory,
  sectionTitle,
  contentKo,
  contentEn,
  optionKo,
  optionEn,
}

/// 한 스크립트 안의 매칭 한 건(스니펫 + 필드).
class SituationalSearchMatch {
  const SituationalSearchMatch({
    required this.field,
    required this.labelKo,
    required this.snippet,
  });

  final SituationalSearchMatchField field;
  final String labelKo;

  /// 하이라이트용 짧은 발췌(중심은 검색어 첫 등장).
  final String snippet;

  /// 정렬: 제목·서브가 먼저, 본문·옵션은 뒤.
  int get sortRank {
    switch (field) {
      case SituationalSearchMatchField.scenarioTitle:
        return 0;
      case SituationalSearchMatchField.subCategory:
        return 1;
      case SituationalSearchMatchField.sectionTitle:
        return 2;
      case SituationalSearchMatchField.contentKo:
        return 3;
      case SituationalSearchMatchField.contentEn:
        return 4;
      case SituationalSearchMatchField.optionKo:
        return 5;
      case SituationalSearchMatchField.optionEn:
        return 6;
    }
  }
}

/// 스크립트 한 건에 대한 검색 히트(복수 필드 가능).
class SituationalSearchHit {
  const SituationalSearchHit({
    required this.script,
    required this.matches,
  });

  final SituationalScript script;

  /// 우선순위 오름차순으로 정렬된 매칭 목록.
  final List<SituationalSearchMatch> matches;

  int get bestRank =>
      matches.isEmpty ? 99 : matches.map((m) => m.sortRank).reduce(math.min);
}

String _norm(String s) => s.trim().toLowerCase();

bool _containsNorm(String haystack, String needle) {
  if (needle.isEmpty) return false;
  return _norm(haystack).contains(_norm(needle));
}

/// 검색 미리보기용 — `{{REASON}}` 등을 [SituationalScript.compose] 미선택 시와
/// 같은 뉘앙스의 자리표시 문자열로만 보이게 한다 (매칭은 원문으로 수행).
String situationalSearchMaskTokens(String text) {
  if (text.isEmpty) return text;
  return text.replaceAllMapped(
    SituationalScript.tokenPattern,
    (_) => '(선택 필요)',
  );
}

/// [query] 주변을 잘라 스니펫으로 쓴다.
String situationalSearchSnippetAround(
  String text,
  String query, {
  int radius = 44,
}) {
  final t = situationalSearchMaskTokens(text.trim());
  if (t.isEmpty) return '';
  final q = query.trim();
  if (q.isEmpty) {
    return t.length > 90 ? '${t.substring(0, 87)}…' : t;
  }
  final lower = t.toLowerCase();
  final qi = q.toLowerCase();
  final i = lower.indexOf(qi);
  if (i < 0) {
    return t.length > 90 ? '${t.substring(0, 87)}…' : t;
  }
  final start = math.max(0, i - radius);
  final end = math.min(t.length, i + q.length + radius);
  var out = t.substring(start, end);
  if (start > 0) out = '…$out';
  if (end < t.length) out = '$out…';
  return out;
}

/// 모든 Situational 스크립트에서 [query] 검색.
List<SituationalSearchHit> situationalGlobalSearch(
  List<SituationalScript> scripts,
  String query,
) {
  final q = query.trim();
  if (q.isEmpty) return const [];

  final hits = <SituationalSearchHit>[];

  for (final s in scripts) {
    final matches = <SituationalSearchMatch>[];

    if (_containsNorm(s.scenario, q)) {
      matches.add(
        SituationalSearchMatch(
          field: SituationalSearchMatchField.scenarioTitle,
          labelKo: '시나리오 제목',
          snippet: situationalSearchSnippetAround(s.scenario, q),
        ),
      );
    }
    if (s.subCategory.trim().isNotEmpty && _containsNorm(s.subCategory, q)) {
      matches.add(
        SituationalSearchMatch(
          field: SituationalSearchMatchField.subCategory,
          labelKo: '서브카테고리',
          snippet: situationalSearchSnippetAround(s.subCategory, q),
        ),
      );
    }

    for (final section in s.sections) {
      if (section.title.trim().isNotEmpty &&
          _containsNorm(section.title, q)) {
        matches.add(
          SituationalSearchMatch(
            field: SituationalSearchMatchField.sectionTitle,
            labelKo: '섹션: ${section.title}',
            snippet: situationalSearchSnippetAround(section.title, q),
          ),
        );
      }
      if (_containsNorm(section.contentKo, q)) {
        matches.add(
          SituationalSearchMatch(
            field: SituationalSearchMatchField.contentKo,
            labelKo: '본문(KR) · ${section.title.trim().isNotEmpty ? section.title : "섹션 ${section.order}"}',
            snippet: situationalSearchSnippetAround(section.contentKo, q),
          ),
        );
      }
      if (_containsNorm(section.contentEn, q)) {
        matches.add(
          SituationalSearchMatch(
            field: SituationalSearchMatchField.contentEn,
            labelKo: '본문(EN) · ${section.title.trim().isNotEmpty ? section.title : "섹션 ${section.order}"}',
            snippet: situationalSearchSnippetAround(section.contentEn, q),
          ),
        );
      }
      for (final opts in section.optionGroups.values) {
        for (final o in opts) {
          if (_containsNorm(o.contentKo, q)) {
            matches.add(
              SituationalSearchMatch(
                field: SituationalSearchMatchField.optionKo,
                labelKo: '옵션(KR) · ${o.group}',
                snippet: situationalSearchSnippetAround(o.contentKo, q),
              ),
            );
          }
          if (_containsNorm(o.contentEn, q)) {
            matches.add(
              SituationalSearchMatch(
                field: SituationalSearchMatchField.optionEn,
                labelKo: '옵션(EN) · ${o.group}',
                snippet: situationalSearchSnippetAround(o.contentEn, q),
              ),
            );
          }
        }
      }
    }

    if (matches.isEmpty) continue;
    matches.sort((a, b) {
      final c = a.sortRank.compareTo(b.sortRank);
      if (c != 0) return c;
      return a.labelKo.compareTo(b.labelKo);
    });
    hits.add(SituationalSearchHit(script: s, matches: matches));
  }

  hits.sort((a, b) {
    final r = a.bestRank.compareTo(b.bestRank);
    if (r != 0) return r;
    final ca = _norm(a.script.category).compareTo(_norm(b.script.category));
    if (ca != 0) return ca;
    final cs =
        _norm(a.script.subCategory).compareTo(_norm(b.script.subCategory));
    if (cs != 0) return cs;
    return _norm(a.script.scenario).compareTo(_norm(b.script.scenario));
  });

  return hits;
}
