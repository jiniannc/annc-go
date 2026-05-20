import 'package:flutter/material.dart';

/// Situational **SubCategory** 탭·카드 좌측 세로줄에 공통으로 쓰는 색.
///
/// [orderedSubCategories] 순서(= CSV 등장 순)를 인덱스로 사용해 같은 서브는
/// 항상 같은 색이 되도록 한다.
class SituationalSubCategoryPalette {
  SituationalSubCategoryPalette._();

  /// 라이트 모드 — 채도 낮은 파스텔(세로줄·은은한 카드 틴트용).
  static const List<Color> _light = [
    Color(0xFFA3C4EC), // soft blue
    Color(0xFFC9B6E4), // soft lavender
    Color(0xFF9DD5CF), // soft teal
    Color(0xFFF5C4A8), // soft peach
    Color(0xFFF0B4B4), // soft rose
    Color(0xFFA8D4A6), // soft sage
    Color(0xFFB8ACE8), // soft periwinkle
    Color(0xFF9DD5E0), // soft aqua
    Color(0xFFF4B8D4), // soft pink
    Color(0xFFC0DC9E), // soft celery
  ];

  /// 다크 모드 — 배경 위에서 과하지 않게 보이는 탁한 파스텔.
  static const List<Color> _dark = [
    Color(0xFF6A8EB8),
    Color(0xFF957CAD),
    Color(0xFF5F9E96),
    Color(0xFFC4956E),
    Color(0xFFB87D7D),
    Color(0xFF6FA06D),
    Color(0xFF7F73B3),
    Color(0xFF5F9EAC),
    Color(0xFFB87A9A),
    Color(0xFF8AA864),
  ];

  static List<Color> _colors(bool isDark) => isDark ? _dark : _light;

  static int indexOfSubCategory(String subCategory, List<String> ordered) {
    final key = subCategory.trim();
    final i = ordered.indexWhere((e) => e.trim() == key);
    return i;
  }

  /// 서브카테고리 행에 쓸 stripe/chip 색. 목록에 없으면 null.
  static Color? colorForSubCategory(
    String subCategory,
    List<String> orderedSubCategories,
    bool isDark,
  ) {
    final i = indexOfSubCategory(subCategory, orderedSubCategories);
    if (i < 0) return null;
    final c = _colors(isDark);
    return c[i % c.length];
  }
}
