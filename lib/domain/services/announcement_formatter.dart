import '../../data/models/aircraft_master_model.dart';
import '../../data/models/airport_master_model.dart';
import '../../data/models/delay_reason_model.dart';
import '../entities/flight_setup.dart';

class AnnouncementFormatter {
  /// 설정·본문 치환에 공통. 비행 **소요** 시간 — `hour`가 0이면 `분`만 표시한다.
  static String formatFlightDurationKo(int hour, int minute) {
    final h = hour;
    final m = minute;
    if (h == 0 && m == 0) {
      return '0분';
    }
    if (h == 0) {
      return '$m분';
    }
    if (m == 0) {
      return '$h시간';
    }
    return '$h시간 $m분';
  }

  /// 텔레프롬프터 본문 안에 지연 사유 드롭다운을 넣기 위한 자리 표시자.
  /// 실제 방송문에 쓰이지 않는 Private Use 문자 1개만 사용합니다.
  static const String kInlineDelayReasonSentinel = '\uE000';
  static const String kInlineFlightNumberStart = '\uE001';
  static const String kInlineFlightNumberDivider = '\uE002';
  static const String kInlineFlightNumberEnd = '\uE003';
  static const String kInlineSpecialFarewellSentinel = '\uE006';

  /// `format(..., emphasizeResolvedPlaceholders: true)`일 때 치환된 값 구간 표시용.
  static const String kVariableEmphasisStart = '\uE004';
  static const String kVariableEmphasisEnd = '\uE005';

  String format({
    required String template,
    required FlightSetup setup,
    required AirportMasterModel? originAirport,
    required AirportMasterModel? destinationAirport,
    required AircraftMasterModel? aircraft,
    required DelayReasonModel? selectedDelayReason,
    bool inlineDelayReasonSlot = false,
    bool inlineSpecialFarewellSlot = false,
    bool inlineFlightNumberHint = false,
    bool emphasizeResolvedPlaceholders = false,
  }) {
    final vars = _buildSubstitutionVars(
      template: template,
      setup: setup,
      originAirport: originAirport,
      destinationAirport: destinationAirport,
      aircraft: aircraft,
      selectedDelayReason: selectedDelayReason,
      inlineDelayReasonSlot: inlineDelayReasonSlot,
      inlineSpecialFarewellSlot: inlineSpecialFarewellSlot,
      inlineFlightNumberHint: inlineFlightNumberHint,
    );
    return _applySubstitutionsToTemplate(
      template,
      vars,
      emphasizeResolvedPlaceholders,
    );
  }

  /// Delay_Reasons 시트의 문구를 텔레프롬프터 **인라인 드롭다운**에 넣을 때 사용.
  ///
  /// 본문은 `inlineDelayReasonSlot` 이라 `{delay_reason}` 자리에 센티넬만 들어가고,
  /// 실제 사유 텍스트는 이 메서드로 비행 설정값을 치환해 표시해야 한다.
  String formatDelayReasonSnippet({
    required String template,
    required FlightSetup setup,
    required AirportMasterModel? originAirport,
    required AirportMasterModel? destinationAirport,
    required AircraftMasterModel? aircraft,
    bool emphasizeResolvedPlaceholders = false,
  }) {
    if (template.trim().isEmpty) {
      return template;
    }
    final vars = _buildSubstitutionVars(
      template: template,
      setup: setup,
      originAirport: originAirport,
      destinationAirport: destinationAirport,
      aircraft: aircraft,
      selectedDelayReason: null,
      inlineDelayReasonSlot: false,
      inlineSpecialFarewellSlot: false,
      inlineFlightNumberHint: false,
    );
    vars.remove('delay_reason');
    vars.remove('delay_reasons1');
    vars.remove('delay_reason_en');
    vars.remove('dealy_reason');
    return _applySubstitutionsToTemplate(
      template,
      vars,
      emphasizeResolvedPlaceholders,
    );
  }

  Map<String, String> _buildSubstitutionVars({
    required String template,
    required FlightSetup setup,
    required AirportMasterModel? originAirport,
    required AirportMasterModel? destinationAirport,
    required AircraftMasterModel? aircraft,
    required DelayReasonModel? selectedDelayReason,
    required bool inlineDelayReasonSlot,
    required bool inlineSpecialFarewellSlot,
    required bool inlineFlightNumberHint,
  }) {
    final zonedNow = _nowAtDestinationTimezone(destinationAirport);
    final flightTimeKo = _flightTimeKo(setup);
    final flightTimeEn = _flightTimeEn(setup);
    final isKoreanTemplate = _isKoreanTemplate(template);
    final flightNoText = _flightNoText(
      setup,
      isKoreanTemplate,
      inlineFlightNumberHint,
    );
    final footrestText = _footrestText(aircraft, isKoreanTemplate);
    final originMilitary = originAirport?.isMilitary == true;
    final destinationMilitary = destinationAirport?.isMilitary == true;
    final windowStateOriginKo = _windowStateByMilitaryKo(originMilitary);
    final windowStateOriginEn = _windowStateByMilitaryEn(originMilitary);
    final windowStateDestinationKo = _windowStateByMilitaryKo(
      destinationMilitary,
    );
    final windowStateDestinationEn = _windowStateByMilitaryEn(
      destinationMilitary,
    );
    final windowStateKo = _windowStateKo(setup);
    final windowStateEn = _windowStateEn(setup);
    final windowStateText =
        isKoreanTemplate ? windowStateKo : windowStateEn;
    final monthKo = zonedNow.month.toString();
    final dateKo = zonedNow.day.toString();
    final hourKo = _hourKoWithMeridiem(zonedNow.hour);
    final minuteKo = zonedNow.minute.toString();
    final hour12 = _hour12(zonedNow.hour);
    final minutePadded = zonedNow.minute.toString().padLeft(2, '0');
    final meridiemEn = zonedNow.hour < 12 ? 'AM' : 'PM';
    final meridiemEnSpoken = zonedNow.hour < 12 ? 'a.m.' : 'p.m.';
    final monthEnWord = _monthNameEn(zonedNow.month);
    final dateEnWord = _ordinalDayEn(zonedNow.day);
    final timeEnWord = _spokenTimeEn(hour12, zonedNow.minute, meridiemEnSpoken);
    return <String, String>{
      'flight_no': flightNoText,
      'flight_number': setup.flightNumberDigits,
      'flight_number_pronunciation': setup.flightNumberPronunciationEn,
      'flight_number_pronunciation_en': setup.flightNumberPronunciationEn,
      'flight_time': flightTimeKo,
      'flight_time_ko': flightTimeKo,
      'flight_time_en': flightTimeEn,
      'origin_city_ko': originAirport?.cityKo ?? '',
      'origin_city_en': originAirport?.cityEn ?? '',
      'dest_city_ko': destinationAirport?.cityKo ?? '',
      'dest_city_en': destinationAirport?.cityEn ?? '',
      'origin_city_kr': originAirport?.cityKo ?? '',
      'dest_city_kr': destinationAirport?.cityKo ?? '',
      'dest': destinationAirport?.cityKo ?? '',
      'dest_ko': destinationAirport?.cityKo ?? '',
      'dest_en': destinationAirport?.cityEn ?? '',
      'origin_ko': originAirport?.cityKo ?? '',
      'origin_en': originAirport?.cityEn ?? '',
      'destination_ko': destinationAirport?.cityKo ?? '',
      'destination_en': destinationAirport?.cityEn ?? '',
      'dest_airport_ko': destinationAirport?.airportKo ?? '',
      'dest_airport_en': destinationAirport?.airportEn ?? '',
      'origin_airport_ko': originAirport?.airportKo ?? '',
      'origin_airport_en': originAirport?.airportEn ?? '',
      // 시트·delay_reasons 에서 흔한 오타/관례: 한국어 공항명에 _kr 접미사
      'origin_airport_kr': originAirport?.airportKo ?? '',
      'dest_airport_kr': destinationAirport?.airportKo ?? '',
      'city_ko': destinationAirport?.cityKo ?? '',
      'city_en': destinationAirport?.cityEn ?? '',
      'airport_ko': destinationAirport?.airportKo ?? '',
      'airport_en': destinationAirport?.airportEn ?? '',
      'window_state': windowStateText,
      'window_state_ko': windowStateKo,
      'window_state_en': windowStateEn,
      'window_state_origin': isKoreanTemplate
          ? windowStateOriginKo
          : windowStateOriginEn,
      'window_state_origin_ko': windowStateOriginKo,
      'window_state_origin_en': windowStateOriginEn,
      'window_state_destination': isKoreanTemplate
          ? windowStateDestinationKo
          : windowStateDestinationEn,
      'window_state_destination_ko': windowStateDestinationKo,
      'window_state_destination_en': windowStateDestinationEn,
      // alias: departure/arrival
      'window_state_departure': isKoreanTemplate
          ? windowStateOriginKo
          : windowStateOriginEn,
      'window_state_departure_ko': windowStateOriginKo,
      'window_state_departure_en': windowStateOriginEn,
      'window_state_arrival': isKoreanTemplate
          ? windowStateDestinationKo
          : windowStateDestinationEn,
      'window_state_arrival_ko': windowStateDestinationKo,
      'window_state_arrival_en': windowStateDestinationEn,
      'footrest': footrestText,
      'footrest_ko': _footrestText(aircraft, true),
      'footrest_en': _footrestText(aircraft, false),
      'stopover': '-',
      'features': _featuresText(aircraft),
      'delay_reason': inlineDelayReasonSlot
          ? kInlineDelayReasonSentinel
          : _delayReasonKo(selectedDelayReason, destinationAirport),
      'delay_reasons1': inlineDelayReasonSlot
          ? kInlineDelayReasonSentinel
          : _delayReasonKo(selectedDelayReason, destinationAirport),
      'delay_reason_en': inlineDelayReasonSlot
          ? kInlineDelayReasonSentinel
          : _delayReasonEn(
              selectedDelayReason,
              destinationAirport,
            ),
      // 시트 오타 허용: {dealy_reason}
      'dealy_reason': inlineDelayReasonSlot
          ? kInlineDelayReasonSentinel
          : _delayReasonKo(selectedDelayReason, destinationAirport),
      'month_ko': monthKo,
      'date_ko': dateKo,
      'hour_ko': hourKo,
      'minute_ko': minuteKo,
      'time_en': _inlineNumericWithSpelling(
        '$hour12:$minutePadded $meridiemEn',
        timeEnWord,
      ),
      'month_en': _inlineNumericWithSpelling(
        zonedNow.month.toString(),
        monthEnWord,
      ),
      'date_en': _inlineNumericWithSpelling(
        zonedNow.day.toString(),
        dateEnWord,
      ),
      'special_farewell': _specialFarewellText(
        destinationAirport,
        inlineSpecialFarewellSlot,
      ),
    };
  }

  String _applySubstitutionsToTemplate(
    String template,
    Map<String, String> vars,
    bool emphasizeResolvedPlaceholders,
  ) {
    final sortedEntries = vars.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    var output = template;
    for (final entry in sortedEntries) {
      final value = _wrapResolvedValueForEmphasis(
        entry.value,
        emphasizeResolvedPlaceholders,
      );
      output = _replaceTokenForms(output, entry.key, value);
    }
    output = _replaceFlexiblePlaceholders(
      output,
      vars,
      emphasizeResolvedPlaceholders,
    );
    output = _fixKoreanJosa(output);
    return _resolveAutoJosaPlaceholders(output);
  }

  /// 시트에 `{Origin_Airport_En}`, 전각 `｛origin_airport_en｝`, 공백 등
  /// 변형이 있어도 snake_case 키로 정규화해 vars 를 찾는다.
  String _replaceFlexiblePlaceholders(
    String output,
    Map<String, String> vars,
    bool emphasizeResolvedPlaceholders,
  ) {
    String normalizeKey(String raw) {
      var s = raw.trim();
      s = s.replaceAll(RegExp(r'\s+'), '_');
      return s.toLowerCase();
    }

    String substitute(String keyNorm) {
      if (!vars.containsKey(keyNorm)) {
        return '';
      }
      return _wrapResolvedValueForEmphasis(
        vars[keyNorm]!,
        emphasizeResolvedPlaceholders,
      );
    }

    var result = output.replaceAllMapped(
      RegExp(r'[\{｛]([^{}｛｝]+)[\}｝]'),
      (m) {
        final keyNorm = normalizeKey(m.group(1)!);
        if (!vars.containsKey(keyNorm)) {
          return m.group(0)!;
        }
        return substitute(keyNorm);
      },
    );
    result = result.replaceAllMapped(RegExp(r'\[([^\]]+)\]'), (m) {
      final keyNorm = normalizeKey(m.group(1)!);
      if (!vars.containsKey(keyNorm)) {
        return m.group(0)!;
      }
      return substitute(keyNorm);
    });
    return result;
  }

  String _replaceTokenForms(String output, String key, String value) {
    final upper = key.toUpperCase();
    final pascal = _toPascal(key);
    return output
        .replaceAll('{$key}', value)
        .replaceAll('{$upper}', value)
        .replaceAll('{$pascal}', value)
        .replaceAll('[$key]', value)
        .replaceAll('[$upper]', value)
        .replaceAll('[$pascal]', value);
  }

  String _wrapResolvedValueForEmphasis(String value, bool emphasize) {
    if (!emphasize ||
        value.isEmpty ||
        value == kInlineDelayReasonSentinel ||
        value == kInlineSpecialFarewellSentinel ||
        value.contains(kInlineFlightNumberStart)) {
      return value;
    }
    return '$kVariableEmphasisStart$value$kVariableEmphasisEnd';
  }

  String _footrestText(AircraftMasterModel? aircraft, bool korean) {
    if (aircraft?.hasFootrest != true) {
      return '';
    }
    return korean ? '발 받침대' : 'footrest';
  }

  bool _isKoreanTemplate(String template) {
    return RegExp(r'[가-힣]').hasMatch(template);
  }

  String _windowStateKo(FlightSetup setup) {
    final raw = setup.windowState.trim();
    if (raw.isEmpty) {
      return '';
    }
    final lower = raw.toLowerCase();
    if (lower.contains('닫') ||
        lower.contains('close') ||
        lower.contains('closed')) {
      return '닫아';
    }
    if (lower.contains('열') || lower.contains('open')) {
      return '열어';
    }
    return raw;
  }

  String _windowStateEn(FlightSetup setup) {
    final raw = setup.windowState.trim();
    if (raw.isEmpty) {
      return '';
    }
    final lower = raw.toLowerCase();
    if (lower.contains('닫') ||
        lower.contains('close') ||
        lower.contains('closed')) {
      return 'close';
    }
    if (lower.contains('열') || lower.contains('open')) {
      return 'open';
    }
    return lower;
  }

  String _windowStateByMilitaryKo(bool isMilitaryAirport) {
    return isMilitaryAirport ? '닫아' : '열어';
  }

  String _windowStateByMilitaryEn(bool isMilitaryAirport) {
    return isMilitaryAirport ? 'close' : 'open';
  }

  String _flightNoText(
    FlightSetup setup,
    bool koreanTemplate,
    bool inlineFlightNumberHint,
  ) {
    final digits = setup.flightNumberDigits.trim();
    if (digits.isEmpty) {
      return '';
    }
    if (koreanTemplate) {
      return digits;
    }
    final pronunciation = setup.flightNumberPronunciationEn.trim();
    if (pronunciation.isEmpty || !inlineFlightNumberHint) {
      return digits;
    }
    return '$kInlineFlightNumberStart$digits'
        '$kInlineFlightNumberDivider$pronunciation'
        '$kInlineFlightNumberEnd';
  }

  String _flightTimeKo(FlightSetup setup) {
    return formatFlightDurationKo(setup.flightHour, setup.flightMinute);
  }

  String _flightTimeEn(FlightSetup setup) {
    final h = setup.flightHour;
    final m = setup.flightMinute;
    final minutePart = m == 1 ? '1 minute' : '$m minutes';
    if (h == 0) {
      return minutePart;
    }
    if (m == 0) {
      return h == 1 ? '1 hour' : '$h hours';
    }
    final hourPart = h == 1 ? '1 hour' : '$h hours';
    return '$hourPart and $minutePart';
  }

  String _featuresText(AircraftMasterModel? aircraft) {
    final labels = aircraft?.featureLabelsKo ?? const <String>[];
    if (labels.isEmpty) {
      return '좌석';
    }
    if (labels.length == 1) {
      return labels.first;
    }
    if (labels.length == 2) {
      return '${labels.first}와 ${labels.last}';
    }
    final head = labels.sublist(0, labels.length - 1).join(', ');
    return '$head, 그리고 ${labels.last}';
  }

  String _delayReasonKo(
    DelayReasonModel? selected,
    AirportMasterModel? destinationAirport,
  ) {
    final reason = selected?.reasonKo ?? '';
    return reason.replaceAll(
      '{Airport_KO}',
      destinationAirport?.airportKo ?? '',
    );
  }

  String _delayReasonEn(
    DelayReasonModel? selected,
    AirportMasterModel? destinationAirport,
  ) {
    final reason = selected?.reasonEn ?? '';
    return reason.replaceAll(
      '{Airport_EN}',
      destinationAirport?.airportEn ?? '',
    );
  }

  String _specialFarewellText(
    AirportMasterModel? destinationAirport,
    bool inlineSlot,
  ) {
    final options = destinationAirport?.specialFarewellItems ?? const <String>[];
    if (options.isEmpty) {
      return '';
    }
    if (inlineSlot) {
      return kInlineSpecialFarewellSentinel;
    }
    return options.first;
  }

  DateTime _nowAtDestinationTimezone(AirportMasterModel? destinationAirport) {
    final offset = _parseTimezoneOffset(destinationAirport?.timeZone);
    if (offset == null) {
      return DateTime.now();
    }
    return DateTime.now().toUtc().add(offset);
  }

  Duration? _parseTimezoneOffset(String? rawTz) {
    final raw = (rawTz ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    final normalized = raw
        .toUpperCase()
        .replaceAll('UTC', '')
        .replaceAll('GMT', '')
        .replaceAll(' ', '');
    final signed = RegExp(r'^([+-])(\d{1,2})(?::?(\d{2}))?$').firstMatch(
      normalized,
    );
    if (signed != null) {
      final sign = signed.group(1) == '-' ? -1 : 1;
      final hour = int.tryParse(signed.group(2) ?? '') ?? 0;
      final minute = int.tryParse(signed.group(3) ?? '0') ?? 0;
      return Duration(hours: sign * hour, minutes: sign * minute);
    }
    final onlyHour = RegExp(r'^(\d{1,2})$').firstMatch(normalized);
    if (onlyHour != null) {
      final hour = int.tryParse(onlyHour.group(1) ?? '') ?? 0;
      return Duration(hours: hour);
    }
    return null;
  }

  int _hour12(int hour24) {
    final mod = hour24 % 12;
    return mod == 0 ? 12 : mod;
  }

  String _hourKoWithMeridiem(int hour24) {
    final meridiem = hour24 < 12 ? '오전' : '오후';
    return '$meridiem ${_hour12(hour24)}';
  }

  String _monthNameEn(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    if (month < 1 || month > 12) {
      return '';
    }
    return names[month - 1];
  }

  String _spokenTimeEn(int hour12, int minute, String meridiemSpoken) {
    final hourWord = _numberWordEn(hour12);
    if (minute == 0) {
      return "$hourWord o'clock $meridiemSpoken";
    }
    if (minute < 10) {
      return '$hourWord-o-${_numberWordEn(minute)} $meridiemSpoken';
    }
    return '$hourWord ${_numberWordEn(minute)} $meridiemSpoken';
  }

  String _ordinalDayEn(int day) {
    if (day < 1 || day > 31) {
      return '';
    }
    const ordinals = {
      1: 'first',
      2: 'second',
      3: 'third',
      4: 'fourth',
      5: 'fifth',
      6: 'sixth',
      7: 'seventh',
      8: 'eighth',
      9: 'ninth',
      10: 'tenth',
      11: 'eleventh',
      12: 'twelfth',
      13: 'thirteenth',
      14: 'fourteenth',
      15: 'fifteenth',
      16: 'sixteenth',
      17: 'seventeenth',
      18: 'eighteenth',
      19: 'nineteenth',
      20: 'twentieth',
      30: 'thirtieth',
    };
    if (ordinals.containsKey(day)) {
      return ordinals[day]!;
    }
    final ten = (day ~/ 10) * 10;
    final one = day % 10;
    final tensWord = switch (ten) {
      20 => 'twenty',
      30 => 'thirty',
      _ => '',
    };
    final unitOrdinal = switch (one) {
      1 => 'first',
      2 => 'second',
      3 => 'third',
      4 => 'fourth',
      5 => 'fifth',
      6 => 'sixth',
      7 => 'seventh',
      8 => 'eighth',
      9 => 'ninth',
      _ => '',
    };
    if (tensWord.isEmpty || unitOrdinal.isEmpty) {
      return day.toString();
    }
    return '$tensWord-$unitOrdinal';
  }

  String _numberWordEn(int value) {
    const units = [
      'zero',
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen',
      'nineteen',
    ];
    if (value < 0) {
      return '';
    }
    if (value < 20) {
      return units[value];
    }
    final tensWord = switch (value ~/ 10) {
      2 => 'twenty',
      3 => 'thirty',
      4 => 'forty',
      5 => 'fifty',
      _ => '',
    };
    final ones = value % 10;
    if (tensWord.isEmpty) {
      return value.toString();
    }
    if (ones == 0) {
      return tensWord;
    }
    return '$tensWord-${units[ones]}';
  }

  String _inlineNumericWithSpelling(String numeric, String spoken) {
    final n = numeric.trim();
    final s = spoken.trim();
    if (n.isEmpty) {
      return '';
    }
    if (s.isEmpty) {
      return n;
    }
    return '$kInlineFlightNumberStart$n'
        '$kInlineFlightNumberDivider$s'
        '$kInlineFlightNumberEnd';
  }

  String _toPascal(String snakeCase) {
    final words = snakeCase.split('_');
    return words
        .map((w) {
          if (w.isEmpty) return w;
          return '${w[0].toUpperCase()}${w.substring(1)}';
        })
        .join('_');
  }

  String _fixKoreanJosa(String text) {
    final regex = RegExp(r'([가-힣A-Za-z0-9]+)과\(와\)');
    return text.replaceAllMapped(regex, (match) {
      final word = match.group(1)!;
      final particle = _hasBatchim(word) ? '과' : '와';
      return '$word$particle';
    });
  }

  /// `{을}`/`{를}`, `{이}`/`{가}`, `{은}`/`{는}` 을 두면 직전 한글 음절 받침에 따라
  /// 하나로 고정한다. (전각 `｛｝` 허용.) 한글 앞 토큰이 없으면 `를·가·는` 쪽을 쓴다.
  String _resolveAutoJosaPlaceholders(String text) {
    const markerStart = kVariableEmphasisStart;
    const markerEnd = kVariableEmphasisEnd;
    var result = text;
    final token = RegExp(r'[\{｛](을|를|이|가|은|는)[\}｝]');
    for (;;) {
      final m = token.firstMatch(result);
      if (m == null) break;
      final prefix = result.substring(0, m.start);
      final tail = result.substring(m.end);
      final stripped = prefix
          .replaceAll(markerStart, '')
          .replaceAll(markerEnd, '');
      final inner = m.group(1)!;
      final particle = _particleFromJosaToken(stripped, inner);
      result = '$prefix$particle$tail';
    }
    return result;
  }

  String _particleFromJosaToken(String prefixStripped, String tokenInner) {
    final runes = prefixStripped.runes.toList();
    for (var i = runes.length - 1; i >= 0; i--) {
      final r = runes[i];
      if (r >= 0xAC00 && r <= 0xD7A3) {
        final syllable = String.fromCharCode(r);
        final has = _hasBatchim(syllable);
        switch (tokenInner) {
          case '을':
          case '를':
            return has ? '을' : '를';
          case '이':
          case '가':
            return has ? '이' : '가';
          case '은':
          case '는':
            return has ? '은' : '는';
          default:
            return tokenInner;
        }
      }
    }
    switch (tokenInner) {
      case '을':
      case '를':
        return '를';
      case '이':
      case '가':
        return '가';
      case '은':
      case '는':
        return '는';
      default:
        return tokenInner;
    }
  }

  bool _hasBatchim(String text) {
    final runes = text.runes.toList();
    if (runes.isEmpty) {
      return false;
    }
    final code = runes.last;
    if (code < 0xAC00 || code > 0xD7A3) {
      return false;
    }
    return (code - 0xAC00) % 28 != 0;
  }
}
