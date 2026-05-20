import 'package:flutter/material.dart';

import '../../data/models/situational_quick_access_row_model.dart';

/// 스프레드시트 `Icon` 컬럼 문자열 → [IconData].
///
/// - 컬럼이 비었거나 이름이 알 수 없으면 [inferQuickAccessKeywordIcon] 에 맡길
///   수 있다. 빈 문자열만 넘긴 기존 호출처는 레거시 호환상 **번개**를 썼으나,
///   `keywordHint`(또는 [quickAccessResolvedIcon]) 가 있으면 키워드 기준 아이콘으로
///   대체한다.
IconData situationalQuickAccessIcon(
  String raw, {
  String keywordHint = '',
}) {
  final key = raw.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  if (key.isEmpty) {
    final h = keywordHint.trim();
    if (h.isNotEmpty) return inferQuickAccessKeywordIcon(h);
    return Icons.bolt_rounded;
  }
  final resolved = _iconNameMap[key];
  if (resolved != null) return resolved;
  return inferQuickAccessKeywordIcon(keywordHint.isNotEmpty ? keywordHint : raw);
}

bool _looksLikeDoctor(String lowered) =>
    lowered.contains('doctor') ||
    lowered.contains('dr.') ||
    lowered.contains('닥터') ||
    lowered.contains('의사');

bool _looksLikeDelay(String lowered) =>
    lowered.contains('지연') ||
    lowered.contains('delay') ||
    lowered.contains('departure delay') ||
    lowered.contains('dep delay');

IconData inferQuickAccessKeywordIcon(String keyword) {
  final sRaw = keyword.trim();
  if (sRaw.isEmpty) {
    return Icons.bolt_rounded;
  }
  final s = sRaw.toLowerCase().replaceAll(RegExp(r'\([^)]*\)'), ' ');
  final compact = s.replaceAll(RegExp(r'[\s\-]+'), '');
  final k = '$s ';

  // Doctor paging — 먼저 (의료 키워드가 다른 규칙과 겹치지 않게)
  if (_looksLikeDoctor(k)) {
    return Icons.local_hospital_rounded;
  }

  // Go-around
  if (k.contains('go-around') ||
      k.contains('go around') ||
      compact.contains('goaround')) {
    return Icons.flight_rounded;
  }

  // RTO 이륙 중지
  if (compact.contains('rto') ||
      k.contains('rejectedtake') ||
      k.contains('take-offreject') ||
      k.contains('이륙중지') ||
      k.contains('이륙 중지')) {
    return Icons.do_not_touch_rounded;
  }

  // 출발 지연 / departure delay (안전 시연보다 먼저 매칭할 필요는 없지만 구체적으로)
  if ((k.contains('출발') && k.contains('지연')) ||
      k.contains('departure delay')) {
    return Icons.departure_board;
  }

  // 이륙 지연
  if ((k.contains('이륙') && k.contains('지연')) ||
      compact.contains('이륙지연') ||
      k.contains('takeoff delay')) {
    return Icons.flight_takeoff;
  }

  // Safety Demonstration 국제선/국내선 — shield 하나에 몰지 않고 구분
  if (k.contains('safety') ||
      compact.contains('safetydemo') ||
      k.contains('세이프티') ||
      (k.contains('안전') && k.contains('demo'))) {
    if (k.contains('국제') ||
        k.contains('international') ||
        k.contains('intl')) {
      return Icons.public_rounded;
    }
    if (k.contains('국내') || k.contains('domestic')) {
      return Icons.home_work_outlined;
    }
    return Icons.shield_outlined;
  }

  // 공중 대기 / Holding
  if ((k.contains('공중') && k.contains('대기')) ||
      k.contains('holding') ||
      k.contains('hold pattern')) {
    return Icons.hourglass_bottom_rounded;
  }

  // 착륙 후 대기 (taxi 혼동 줄이기: '착륙'+'대기' 우선)
  if ((k.contains('착륙') && k.contains('대기')) ||
      (k.contains('after') && k.contains('land'))) {
    return Icons.alt_route_rounded;
  }
  if (k.contains('taxi') || k.contains('택시')) {
    return Icons.airport_shuttle_rounded;
  }

  // 하기 지연 (디스렘바크)
  if (k.contains('하기지연') ||
      k.contains('하기 지연') ||
      k.contains('disembark')) {
    return Icons.airline_seat_recline_normal_rounded;
  }

  // 지연 양해 멘트 (일반 schedule 과 구분)
  if (k.contains('양해')) {
    return Icons.volunteer_activism_rounded;
  }

  // 회항
  if (k.contains('회항') || k.contains('diversion')) {
    return Icons.u_turn_left_rounded;
  }

  // 기내 화재
  if (k.contains('화재') ||
      k.contains('fire') ||
      compact.contains('inflightfire')) {
    return Icons.local_fire_department_rounded;
  }

  // 폭발물 위협 — shield 와 구분
  if (k.contains('폭발') || k.contains('bomb') || k.contains('explos')) {
    return Icons.priority_high_rounded;
  }

  // 흡연
  if (k.contains('흡연') ||
      k.contains('smoking') ||
      compact.contains('smoke')) {
    return Icons.smoke_free_rounded;
  }

  // 비정상 상황
  if (k.contains('비정상') ||
      k.contains('abnormal') ||
      k.contains('irregular')) {
    return Icons.warning_amber_rounded;
  }

  // 기타 지연 안내 (일반)
  if (_looksLikeDelay(k)) {
    return Icons.schedule_rounded;
  }

  return Icons.radio_button_checked_rounded;
}

/// Quick Access 한 행: `Icon` 컬럼이 유효하면 우선 적용하고, 비어 있거나 모르면
/// Keyword 기반으로 선택한다.
IconData quickAccessResolvedIcon(SituationalQuickAccessRowModel row) {
  return situationalQuickAccessIcon(
    row.iconName,
    keywordHint: row.keyword,
  );
}

const Map<String, IconData> _iconNameMap = {
  'schedule': Icons.schedule_rounded,
  'schedule_rounded': Icons.schedule_rounded,
  'delay': Icons.schedule_rounded,
  'flight': Icons.flight_rounded,
  'flight_rounded': Icons.flight_rounded,
  'u_turn': Icons.u_turn_left_rounded,
  'u_turn_left': Icons.u_turn_left_rounded,
  'u_turn_left_rounded': Icons.u_turn_left_rounded,
  'diversion': Icons.u_turn_left_rounded,
  'person': Icons.person_rounded,
  'person_rounded': Icons.person_rounded,
  'passenger': Icons.sentiment_dissatisfied_rounded,
  'sick': Icons.healing_rounded,
  'medical': Icons.local_hospital_rounded,
  'campaign': Icons.campaign_rounded,
  'campaign_rounded': Icons.campaign_rounded,
  'paging': Icons.campaign_rounded,
  'mic': Icons.mic_rounded,
  'shield': Icons.shield_rounded,
  'shield_outlined': Icons.shield_outlined,
  'safety': Icons.shield_outlined,
  'demo': Icons.shield_outlined,
  'warning': Icons.warning_amber_rounded,
  'emergency': Icons.emergency_rounded,
  'sos': Icons.sos_rounded,
  'fire': Icons.local_fire_department_rounded,
  'smoke': Icons.smoke_free_rounded,
  'smoking': Icons.smoke_free_rounded,
  'weather': Icons.thunderstorm_rounded,
  'cloud': Icons.cloud_rounded,
  'airplane': Icons.airplanemode_active_rounded,
  'seat': Icons.airline_seat_recline_normal_rounded,
  'luggage': Icons.luggage_rounded,
  'help': Icons.help_rounded,
  'info': Icons.info_rounded,
  'search': Icons.search_rounded,
  'bolt': Icons.bolt_rounded,
  'bolt_rounded': Icons.bolt_rounded,
  'hourglass': Icons.hourglass_bottom_rounded,
  'hourglass_bottom': Icons.hourglass_bottom_rounded,
  'holding': Icons.hourglass_bottom_rounded,
};
