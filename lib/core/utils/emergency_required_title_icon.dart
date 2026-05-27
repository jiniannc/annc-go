import 'package:flutter/material.dart';

/// Emergency Phase 토글(비상 착륙 / 비상 착수)용 아이콘.
IconData emergencyPhaseToggleIcon(String phaseName) {
  final p = phaseName.trim().toLowerCase();
  final isDitching =
      p.contains('착수') || p.contains('ditch') || p.contains('ditching');
  final isLanding =
      p.contains('착륙') || p.contains('land') || p.contains('landing');

  if (isDitching) {
    return Icons.waves_rounded;
  }
  if (isLanding && !isDitching) {
    return Icons.flight_land_rounded;
  }
  return Icons.crisis_alert_rounded;
}

/// Emergency Phase명 + CSV `Order`에 따른 필수 구간 헤더 아이콘.
///
/// Phase 라벨은 시트에 따라 조금 달라질 수 있으므로 부분 문자열로 구분한다.
IconData emergencyRequiredTitleIcon(String phaseName, int order) {
  final p = phaseName.trim().toLowerCase();
  final isDitching =
      p.contains('착수') || p.contains('ditch') || p.contains('ditching');
  final isLanding =
      p.contains('착륙') || p.contains('land') || p.contains('landing');

  if (isLanding && !isDitching) {
    return _landingIcon(order);
  }
  if (isDitching) {
    return _ditchingIcon(order);
  }
  return Icons.campaign_rounded;
}

IconData _landingIcon(int order) {
  switch (order) {
    case 1:
      return Icons.record_voice_over_rounded;
    case 3:
      return Icons.restaurant_menu_rounded;
    case 5:
      return Icons.backpack_rounded;
    case 7:
      return Icons.event_seat_rounded;
    case 9:
      return Icons.accessibility_new_rounded;
    case 13:
      return Icons.door_front_door_outlined;
    case 19:
      return Icons.menu_book_rounded;
    case 21:
      return Icons.volunteer_activism_rounded;
    case 23:
      return Icons.swap_horiz_rounded;
    case 25:
      return Icons.tungsten_rounded;
    default:
      return Icons.campaign_rounded;
  }
}

IconData _ditchingIcon(int order) {
  switch (order) {
    case 1:
      return Icons.record_voice_over_rounded;
    case 3:
      return Icons.restaurant_menu_rounded;
    case 5:
      return Icons.backpack_rounded;
    case 7:
      return Icons.sailing;
    case 11:
      return Icons.accessibility_new_rounded;
    case 15:
      return Icons.waves_rounded;
    case 23:
      return Icons.menu_book_rounded;
    case 25:
      return Icons.volunteer_activism_rounded;
    case 27:
      return Icons.swap_horiz_rounded;
    case 29:
      return Icons.tungsten_rounded;
    default:
      return Icons.campaign_rounded;
  }
}

bool scriptEtcShowsDemoBadge(String etcNote) {
  final t = etcNote.trim();
  if (t.isEmpty) return false;
  return t == '시연 필요' || t.contains('시연 필요');
}