class FlightSetup {
  /// 비행 설정이 없을 때 `Condition_Tag` 평가용 최소 상태(미선택 기종·미설정 노선).
  ///
  /// [CsvMasterDataRepository.matchesConditionTag] 등에서 `setup == null` 대신 사용한다.
  factory FlightSetup.emptyForConditionTags() {
    return const FlightSetup(
      originDestination: '',
      originIata: '',
      destinationIata: '',
      flightNumberDigits: '',
      flightTime: '',
      flightHour: 0,
      flightMinute: 0,
      isCodeshare: false,
      hlNo: null,
      specialWelcome: '',
      specialWelcomeTag: 'none',
      windowState: '',
      milestones: [],
    );
  }

  const FlightSetup({
    required this.originDestination,
    required this.originIata,
    required this.destinationIata,
    required this.flightNumberDigits,
    required this.flightTime,
    required this.flightHour,
    required this.flightMinute,
    required this.isCodeshare,
    required this.specialWelcome,
    required this.specialWelcomeTag,
    required this.windowState,
    this.hlNo,
    required this.milestones,
  });

  final String originDestination;
  final String originIata;
  final String destinationIata;
  final String flightNumberDigits;
  final String flightTime;
  final int flightHour;
  final int flightMinute;
  final bool isCodeshare;
  final String? hlNo;
  final String specialWelcome;
  final String specialWelcomeTag;
  final String windowState;
  final List<String> milestones;

  String get fullFlightNumber => 'LJ$flightNumberDigits';

  /// 숫자 편명만 영어로 읽는 힌트.
  /// - 맨 앞·맨 뒤의 0 → `zero` (예: `290` → `two-nine-zero`)
  /// - 가운데 끼인 0 → `o` (예: `201` → `two-o-one`, `902` → `nine-o-two`)
  String get flightNumberPronunciationEn {
    final chars = [
      for (final ch in flightNumberDigits.split(''))
        if (ch.length == 1 && ch.codeUnitAt(0) >= 0x30 && ch.codeUnitAt(0) <= 0x39)
          ch,
    ];
    if (chars.isEmpty) {
      return '';
    }
    final parts = <String>[];
    for (var i = 0; i < chars.length; i++) {
      final ch = chars[i];
      if (ch != '0') {
        parts.add(
          switch (ch) {
            '1' => 'one',
            '2' => 'two',
            '3' => 'three',
            '4' => 'four',
            '5' => 'five',
            '6' => 'six',
            '7' => 'seven',
            '8' => 'eight',
            '9' => 'nine',
            _ => '',
          },
        );
        continue;
      }
      final atEnds = i == 0 || i == chars.length - 1;
      parts.add(atEnds ? 'zero' : 'o');
    }
    return parts.where((p) => p.isNotEmpty).join('-');
  }
}
