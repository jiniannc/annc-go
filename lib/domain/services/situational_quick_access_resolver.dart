import '../../data/models/situational_quick_access_row_model.dart';
import '../entities/situational_script.dart';

String _normKey(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

/// [SituationalQuickAccessRowModel]이 가리키는 [SituationalScript]를 찾는다.
///
/// `Category`(및 선택적 `SubCategory`)·`Scenario`를 [SituationalScript] 필드와
/// 공백·대소문자 무시로 비교한다.
SituationalScript? resolveQuickAccessTarget(
  List<SituationalScript> scripts,
  SituationalQuickAccessRowModel row,
) {
  if (row.isEmpty) return null;
  final cat = _normKey(row.situationalCategory);
  final subRaw = row.subCategory.trim();
  final scen = _normKey(row.scenario);

  for (final s in scripts) {
    if (_normKey(s.category) != cat) continue;
    if (subRaw.isNotEmpty && _normKey(s.subCategory) != _normKey(subRaw)) {
      continue;
    }
    if (_normKey(s.scenario) == scen) return s;
  }
  return null;
}
