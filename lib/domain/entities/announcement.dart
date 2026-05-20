enum AnnouncementCategory { routine, situational, emergency }

class Announcement {
  const Announcement({
    required this.id,
    required this.category,
    required this.flightPhase,
    required this.title,
    required this.contentKR,
    required this.contentEN,
    this.audioJpUrl,
    this.audioCnUrl,
    this.conditionTag,
    this.order = 0,
    this.isOptional = false,
    /// CSV Option 컬럼이 `hide`일 때 true — 필요시 카드이나 기본으로 접혀 있음.
    this.optionalStartsCollapsed = false,
    /// CSV Option 컬럼이 `select`일 때 true — 연속 시 택1 그룹(단독이면 hide와 동일).
    this.optionalIsSelect = false,
    this.announcer = '',
    this.timing = '',
    this.etcNote = '',
  });

  final String id;
  final AnnouncementCategory category;
  final String flightPhase;
  final String title;
  final String contentKR;
  final String contentEN;
  final String? audioJpUrl;
  final String? audioCnUrl;
  final String? conditionTag;
  final int order;
  final bool isOptional;
  /// true 이면 [isOptional]과 함께 쓰이며, UI에서 본문을 기본 접힘으로 시작한다.
  final bool optionalStartsCollapsed;
  /// CSV `Option` = `select`. 연속 구간은 택1 그룹으로, 단독은 hide와 동일하게 접힘.
  final bool optionalIsSelect;
  final String announcer;
  final String timing;
  final String etcNote;
}
