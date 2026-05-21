import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/google_sheet_urls.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../core/utils/google_sheet_link_converter.dart';
import '../../../data/models/sync_sheet_links.dart';
import '../../../data/models/aircraft_master_model.dart';
import '../../../domain/entities/flight_setup.dart';
import '../../../domain/services/announcement_formatter.dart';
import '../../providers/announcement_provider.dart';
import '../../providers/flight_setup_provider.dart';
import '../../providers/sync_provider.dart';
import '../../widgets/liquid_glass_card.dart';
import '../../widgets/sync_progress_panel.dart';
import '../home/home_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _originCodeController = TextEditingController(text: 'ICN');
  final _destinationCodeController = TextEditingController(text: 'NRT');
  final _flightDigitsController = TextEditingController(text: '101');
  final _hlNoController = TextEditingController();
  final _spreadsheetLinkController = TextEditingController();
  final _announcementsLinkController = TextEditingController();
  final _routesLinkController = TextEditingController();
  final _airportsLinkController = TextEditingController();
  final _aircraftLinkController = TextEditingController();
  final _delayLinkController = TextEditingController();
  bool _isCodeshare = false;
  String _specialWelcomeTag = noSpecialWelcomeTag;
  String _originCode = 'ICN';
  String _destinationCode = 'NRT';
  int _flightHour = 2;
  int _flightMinute = 10;
  bool _didHydrateFromSavedSetup = false;

  @override
  void initState() {
    super.initState();
    _originCodeController.addListener(_onIataChanged);
    _destinationCodeController.addListener(_onIataChanged);
    _hlNoController.addListener(_onHlNoChanged);
    _hydrateFromSavedSetup();
    _onIataChanged();
    Future.microtask(_loadSavedSheetLinks);
  }

  void _hydrateFromSavedSetup() {
    final saved = ref.read(flightSetupProvider);
    _applySetupToForm(saved);
  }

  void _applySetupToForm(FlightSetup? saved) {
    if (saved == null) {
      return;
    }
    _didHydrateFromSavedSetup = true;
    _originCodeController.text = saved.originIata.trim().toUpperCase();
    _destinationCodeController.text = saved.destinationIata.trim().toUpperCase();
    _flightDigitsController.text = saved.flightNumberDigits.trim();
    _hlNoController.text = _stripHlPrefix(saved.hlNo);

    setState(() {
      _originCode = saved.originIata.trim().toUpperCase();
      _destinationCode = saved.destinationIata.trim().toUpperCase();
      _flightHour = saved.flightHour;
      _flightMinute = saved.flightMinute;
      _isCodeshare = saved.isCodeshare;
      _specialWelcomeTag = saved.specialWelcomeTag.trim().isEmpty
          ? noSpecialWelcomeTag
          : saved.specialWelcomeTag.trim();
    });
    ref.read(draftHlNoProvider.notifier).state = _composeHlNo(
      _hlNoController.text,
    );
  }

  static String _stripHlPrefix(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return '';
    final upper = value.toUpperCase();
    if (upper.startsWith('HL')) {
      return value.substring(2).trim();
    }
    return value;
  }

  static String _composeHlNo(String digits) {
    final trimmed = digits.trim();
    if (trimmed.isEmpty) return '';
    return 'HL$trimmed';
  }

  @override
  void dispose() {
    _originCodeController.removeListener(_onIataChanged);
    _destinationCodeController.removeListener(_onIataChanged);
    _hlNoController.removeListener(_onHlNoChanged);
    _originCodeController.dispose();
    _destinationCodeController.dispose();
    _flightDigitsController.dispose();
    _hlNoController.dispose();
    _spreadsheetLinkController.dispose();
    _announcementsLinkController.dispose();
    _routesLinkController.dispose();
    _airportsLinkController.dispose();
    _aircraftLinkController.dispose();
    _delayLinkController.dispose();
    super.dispose();
  }

  void _onIataChanged() {
    final origin = _originCodeController.text.trim().toUpperCase();
    final destination = _destinationCodeController.text.trim().toUpperCase();
    if (origin == _originCode && destination == _destinationCode) {
      return;
    }
    setState(() {
      _originCode = origin;
      _destinationCode = destination;
    });
  }

  void _swapOriginDestination() {
    HapticFeedback.selectionClick();
    final o = _originCodeController.text.trim().toUpperCase();
    final d = _destinationCodeController.text.trim().toUpperCase();
    _originCodeController.text = d;
    _destinationCodeController.text = o;
    setState(() {
      _originCode = d;
      _destinationCode = o;
    });
  }

  Future<void> _save() async {
    final flightDigits = _flightDigitsController.text.trim();
    final flightTime =
        AnnouncementFormatter.formatFlightDurationKo(_flightHour, _flightMinute);
    final originDestination = '$_originCode - $_destinationCode';

    if (flightDigits.isEmpty) {
      return;
    }
    if (_originCode.length != 3 || _destinationCode.length != 3) {
      return;
    }

    final bundle = await ref.read(masterDataProvider.future);
    final repository = ref.read(masterDataRepositoryProvider);
    final destinationAirport = repository.findAirportByIata(
      bundle,
      _destinationCode,
    );
    final specialWelcomeOptions = ref.read(specialWelcomeOptionsProvider);
    SpecialWelcomeOption? selectedWelcome;
    for (final option in specialWelcomeOptions) {
      if (option.conditionTag == _specialWelcomeTag) {
        selectedWelcome = option;
        break;
      }
    }
    final milestones = repository.resolveMilestones(
      bundle,
      originIata: _originCode,
      destinationIata: _destinationCode,
    );
    if (milestones.isEmpty) {
      return;
    }

    final setup = FlightSetup(
      originDestination: originDestination,
      originIata: _originCode,
      destinationIata: _destinationCode,
      flightNumberDigits: flightDigits,
      flightTime: flightTime,
      flightHour: _flightHour,
      flightMinute: _flightMinute,
      isCodeshare: _isCodeshare,
      hlNo: _composeHlNo(_hlNoController.text).isEmpty
          ? null
          : _composeHlNo(_hlNoController.text),
      specialWelcome: selectedWelcome?.label ?? '해당없음',
      specialWelcomeTag: selectedWelcome?.conditionTag ?? noSpecialWelcomeTag,
      windowState: destinationAirport?.isMilitary == true ? '닫아' : '열어',
      milestones: milestones,
    );

    ref.read(flightSetupProvider.notifier).saveSetup(setup);
    ref.read(selectedMilestoneProvider.notifier).state = milestones.first;
    if (!mounted) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
      );
    }
  }

  void _onHlNoChanged() {
    ref.read(draftHlNoProvider.notifier).state = _composeHlNo(
      _hlNoController.text,
    );
  }

  Future<void> _loadSavedSheetLinks() async {
    final repo = ref.read(syncConfigRepositoryProvider);
    final links = await repo.readSheetLinks();
    if (!mounted) {
      return;
    }
    _announcementsLinkController.text = links.announcementsCsvUrl;
    _routesLinkController.text = links.routesCsvUrl;
    _airportsLinkController.text = links.airportsCsvUrl;
    _aircraftLinkController.text = links.aircraftCsvUrl;
    _delayLinkController.text = links.delayReasonsCsvUrl;
    _spreadsheetLinkController.text = links.spreadsheetUrl.trim().isNotEmpty
        ? links.spreadsheetUrl
        : (links.hasPerSheetCsvWithoutSpreadsheet
              ? ''
              : GoogleSheetUrls.canonicalSpreadsheetUrl);
    setState(() {});
  }

  Future<void> _saveSingleSpreadsheetLink() async {
    final spreadsheetUrl = _spreadsheetLinkController.text.trim();
    if (spreadsheetUrl.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('스프레드시트 주소를 먼저 입력해 주세요.')));
      return;
    }
    try {
      final links = SyncSheetLinks(
        spreadsheetUrl: spreadsheetUrl,
        announcementsCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['announcements']!,
        ),
        routesCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['routes']!,
        ),
        airportsCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['airports']!,
        ),
        aircraftCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['aircraft']!,
        ),
        delayReasonsCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['delayReasons']!,
        ),
        uiControlsCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['uiControls']!,
        ),
        situationalCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['situational']!,
        ),
        situationalQuickAccessCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['situationalQuickAccess']!,
        ),
        emergencyCsvUrl: GoogleSheetLinkConverter.toCsvBySheetName(
          spreadsheetUrl,
          GoogleSheetLinkConverter.defaultTabNames['emergency']!,
        ),
      );
      await ref.read(syncConfigRepositoryProvider).saveSheetLinks(links);
      _announcementsLinkController.text = links.announcementsCsvUrl;
      _routesLinkController.text = links.routesCsvUrl;
      _airportsLinkController.text = links.airportsCsvUrl;
      _aircraftLinkController.text = links.aircraftCsvUrl;
      _delayLinkController.text = links.delayReasonsCsvUrl;
      await ref.read(syncStateProvider.notifier).syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('링크 저장 및 최신 데이터 동기화를 완료했습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '스프레드시트 처리 실패: $e\n시트 공유 권한을 "링크가 있는 모든 사용자(뷰어)"로 설정해 주세요.',
          ),
        ),
      );
    }
  }

  Future<void> _saveGoogleSheetLinks() async {
    try {
      final links = SyncSheetLinks(
        spreadsheetUrl: _spreadsheetLinkController.text.trim(),
        announcementsCsvUrl: GoogleSheetLinkConverter.toCsvExportUrl(
          _announcementsLinkController.text,
        ),
        routesCsvUrl: GoogleSheetLinkConverter.toCsvExportUrl(
          _routesLinkController.text,
        ),
        airportsCsvUrl: GoogleSheetLinkConverter.toCsvExportUrl(
          _airportsLinkController.text,
        ),
        aircraftCsvUrl: GoogleSheetLinkConverter.toCsvExportUrl(
          _aircraftLinkController.text,
        ),
        delayReasonsCsvUrl: GoogleSheetLinkConverter.toCsvExportUrl(
          _delayLinkController.text,
        ),
      );
      await ref.read(syncConfigRepositoryProvider).saveSheetLinks(links);
      _announcementsLinkController.text = links.announcementsCsvUrl;
      _routesLinkController.text = links.routesCsvUrl;
      _airportsLinkController.text = links.airportsCsvUrl;
      _aircraftLinkController.text = links.aircraftCsvUrl;
      _delayLinkController.text = links.delayReasonsCsvUrl;
      await ref.read(syncStateProvider.notifier).syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('링크 변환 저장 및 동기화를 완료했습니다.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('링크 변환 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedSetup = ref.watch(flightSetupProvider);
    if (!_didHydrateFromSavedSetup && savedSetup != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didHydrateFromSavedSetup) {
          return;
        }
        _applySetupToForm(savedSetup);
      });
    }
    final originAirport = ref.watch(airportByIataProvider(_originCode));
    final destinationAirport = ref.watch(
      airportByIataProvider(_destinationCode),
    );
    final draftAircraft = ref.watch(draftAircraftProvider);
    final syncState = ref.watch(syncStateProvider);
    final specialWelcomeOptions = ref.watch(specialWelcomeOptionsProvider);
    final hasSelectedWelcome = specialWelcomeOptions.any(
      (o) => o.conditionTag == _specialWelcomeTag,
    );
    final effectiveSpecialWelcomeTag = hasSelectedWelcome
        ? _specialWelcomeTag
        : noSpecialWelcomeTag;

    return Scaffold(
      backgroundColor: Colors.transparent,
      // 모달 시트(bar) 바깥에서 이미 keyboard inset을 처리하므로,
      // 여기서 재적용하면 이중 패딩으로 플로팅 버튼이 위로 뜬다.
      resizeToAvoidBottomInset: false,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _setupSheetHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    UiConstants.pagePadding,
                    0,
                    UiConstants.pagePadding,
                    88,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _setupSectionHeader(
                        context,
                        title: '비행 정보',
                        isFirst: true,
                      ),
                      _setupPanelCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _iataField(
                                    context,
                                    controller: _originCodeController,
                                    label: '출발지',
                                    hintText: 'ICN',
                                    icon: Icons.flight_takeoff_outlined,
                                    cityName: originAirport?.cityKo,
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 2),
                                  child: IconButton(
                                    onPressed: _swapOriginDestination,
                                    tooltip: '출발지 ↔ 도착지 (인바운드 등)',
                                    icon: Icon(
                                      Icons.swap_horiz_rounded,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.55),
                                    ),
                                    style: IconButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.65),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: _iataField(
                                    context,
                                    controller: _destinationCodeController,
                                    label: '도착지',
                                    hintText: 'NRT',
                                    icon: Icons.flight_land_outlined,
                                    cityName: destinationAirport?.cityKo,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _flightNumberWithCodeshareRow(context),
                            const SizedBox(height: 14),
                            _flightDurationRow(context),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    _setupSectionHeader(
                      context,
                      title: '항공기',
                    ),
                    _setupPanelCard(
                      context,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _textField(
                            context,
                            controller: _hlNoController,
                            label: 'HL No.',
                            hintText: '7719',
                            icon: Icons.airplane_ticket_outlined,
                            fixedLeadingToken: 'HL',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(5),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _aircraftStatusPanel(
                            context,
                            hlEntered:
                                _hlNoController.text.trim().isNotEmpty,
                            aircraft: draftAircraft,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _setupSectionHeader(
                      context,
                      title: '부가 옵션',
                    ),
                    _setupPanelCard(
                      context,
                      child: _specialWelcomeField(
                        context,
                        options: specialWelcomeOptions,
                        valueTag: effectiveSpecialWelcomeTag,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _setupPanelCard(
                      context,
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      child: Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding:
                              const EdgeInsets.fromLTRB(0, 10, 0, 0),
                          title: _sectionTitle(context, '데이터 동기화 (선택)'),
                          children: [
                            _textField(
                              context,
                              controller: _spreadsheetLinkController,
                              label: '마스터 스프레드시트 링크',
                              hintText:
                                  'https://docs.google.com/spreadsheets/d/.../edit',
                              icon: Icons.link_rounded,
                              labelWidth: _fieldLabelWidthLong,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _saveSingleSpreadsheetLink();
                                    },
                                    icon: const Icon(Icons.auto_awesome_outlined),
                                    label: const Text('주소 하나로 연결'),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: syncState.isLoading
                                        ? null
                                        : () async {
                                            HapticFeedback.lightImpact();
                                            await ref
                                                .read(
                                                  syncStateProvider.notifier,
                                                )
                                                .syncNow();
                                          },
                                    icon: const Icon(Icons.sync_rounded),
                                    label: const Text('동기화'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _SyncStatusText(syncState: syncState),
                            const SizedBox(height: 8),
                            Theme(
                              data: Theme.of(
                                context,
                              ).copyWith(dividerColor: Colors.transparent),
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(0, 6, 0, 0),
                                title: Text(
                                  '고급 링크 설정',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.62),
                                      ),
                                ),
                                children: [
                                  _textField(
                                    context,
                                    controller: _announcementsLinkController,
                                    label: '방송문 링크',
                                    icon: Icons.article_outlined,
                                    labelWidth: _fieldLabelWidthLong,
                                  ),
                                  const SizedBox(height: 8),
                                  _textField(
                                    context,
                                    controller: _routesLinkController,
                                    label: '노선 링크',
                                    icon: Icons.route_outlined,
                                    labelWidth: _fieldLabelWidthLong,
                                  ),
                                  const SizedBox(height: 8),
                                  _textField(
                                    context,
                                    controller: _airportsLinkController,
                                    label: '공항 링크',
                                    icon: Icons.place_outlined,
                                    labelWidth: _fieldLabelWidthLong,
                                  ),
                                  const SizedBox(height: 8),
                                  _textField(
                                    context,
                                    controller: _aircraftLinkController,
                                    label: '기재 링크',
                                    icon: Icons.airplanemode_active_outlined,
                                    labelWidth: _fieldLabelWidthLong,
                                  ),
                                  const SizedBox(height: 8),
                                  _textField(
                                    context,
                                    controller: _delayLinkController,
                                    label: '지연 사유 링크',
                                    icon: Icons.report_problem_outlined,
                                    labelWidth: _fieldLabelWidthLong,
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      _saveGoogleSheetLinks();
                                    },
                                    icon: const Icon(Icons.link),
                                    label: const Text('개별 링크 저장'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0),
                        Theme.of(context).colorScheme.surface,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        UiConstants.pagePadding,
                        10,
                        UiConstants.pagePadding,
                        12,
                      ),
                      child: FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _save();
                        },
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: UiConstants.situationalNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 22),
                        label: const Text(
                          '저장하고 시작',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _setupSheetHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        UiConstants.pagePadding,
        8,
        4,
        14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FLIGHT SETUP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                        color: UiConstants.goOrange.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '비행 설정',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.9,
                        height: 1.05,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '비행 정보를 입력한 뒤 저장하면 홈 화면으로 이동합니다.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 14.5,
                        height: 1.38,
                        color: scheme.onSurface.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '닫기',
                icon: Icon(
                  Icons.expand_more_rounded,
                  size: 30,
                  color: scheme.onSurface.withValues(alpha: 0.48),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _setupSectionHeader(
    BuildContext context, {
    required String title,
    String subtitle = '',
    bool isFirst = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        top: isFirst ? 4 : 0,
        bottom: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 3,
              height: 17,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    UiConstants.goOrange.withValues(alpha: 0.95),
                    UiConstants.goOrange.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.38,
                    height: 1.22,
                    color: scheme.onSurface.withValues(alpha: 0.80),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13.5,
                      height: 1.38,
                      color: scheme.onSurface.withValues(alpha: 0.52),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const double _panelRadius = 18;
  static const EdgeInsets _panelPadding =
      EdgeInsets.fromLTRB(12, 10, 12, 10);

  Widget _setupPanelCard(
    BuildContext context, {
    required Widget child,
    EdgeInsets? padding,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_panelRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.085),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -8,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_panelRadius),
        child: LiquidGlassCard(
          borderRadius: _panelRadius,
          padding: padding ?? _panelPadding,
          child: child,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Unified input system
  // ------------------------------------------------------------

  static const double _fieldRadius = 12;

  /// 비행 정보 패널 라벨 열(출발지·편명·비행시간 줄의 아이콘 세로 정렬용).
  static const double _flightPanelLabelColumnWidth = 76;

  /// 비행 패널 외 입력 기본 라벨 폭(HL No. 등).
  static const double _fieldLabelWidthFlight = 112;

  /// 긴 라벨(링크 제목 등).
  static const double _fieldLabelWidthLong = 138;

  Color _fieldFill(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (Theme.of(context).brightness == Brightness.dark) {
      return scheme.surfaceContainerHighest.withValues(alpha: 0.55);
    }
    return const Color(0xFFF4F7FB);
  }

  Color _fieldIconColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.52);
  }

  TextStyle _labelStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: scheme.onSurface.withValues(alpha: isDark ? 0.82 : 0.74),
      letterSpacing: -0.12,
      height: 1.25,
    );
  }

  TextStyle _valueStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 16.5,
      fontWeight: FontWeight.w700,
      color: scheme.onSurface,
      letterSpacing: -0.12,
      height: 1.22,
      textBaseline: TextBaseline.alphabetic,
      fontFeatures: const [FontFeature.liningFigures()],
    );
  }

  /// 필드 앞(라벨 오른쪽) 고정 아이콘.
  Widget _leadingFieldIcon(BuildContext context, IconData icon) {
    final color = _fieldIconColor(context);
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Icon(icon, size: 20, color: color),
    );
  }

  /// 라벨 + 아이콘은 밖에서 두고, 입력 영역만 둥근 셀로 감싼다.
  InputDecoration _shellDecoration(
    BuildContext context, {
    String? hint,
    Widget? leadingPrefix,
    String? prefixText,
    TextStyle? prefixStyleOverride,
    Widget? suffixIcon,
    String? suffixText,
    TextStyle? suffixStyle,
  }) {
    final labelSt = _labelStyle(context);
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      prefix: leadingPrefix,
      prefixText: prefixText,
      prefixStyle:
          prefixStyleOverride ??
          _valueStyle(context).copyWith(fontWeight: FontWeight.w700),
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: suffixStyle,
      filled: true,
      fillColor: _fieldFill(context),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      counterText: '',
      hintStyle: labelSt.copyWith(
        color: scheme.onSurface.withValues(alpha: 0.42),
        fontWeight: FontWeight.w500,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_fieldRadius),
        borderSide: BorderSide(
          color: UiConstants.goOrange.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
    );
  }

  Widget _fixedTokenPrefix(BuildContext context, String token, TextStyle tokenStyle) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Text(token, style: tokenStyle),
    );
  }

  Widget _labeledFieldRow(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Widget child,
    double labelWidth = _fieldLabelWidthFlight,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(
            label,
            style: _labelStyle(context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _leadingFieldIcon(context, icon),
        Expanded(child: child),
      ],
    );
  }

  Widget _textField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    String? fixedLeadingToken,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextStyle? uniformHeavyStyle,
    double labelWidth = _fieldLabelWidthFlight,
  }) {
    final inputStyle = uniformHeavyStyle ?? _valueStyle(context);
    final prefixStyle = uniformHeavyStyle ?? _valueStyle(context).copyWith(
      fontWeight: FontWeight.w700,
    );
    final leading = fixedLeadingToken == null
        ? null
        : _fixedTokenPrefix(context, fixedLeadingToken, prefixStyle);
    return _labeledFieldRow(
      context,
      label: label,
      icon: icon,
      labelWidth: labelWidth,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textAlignVertical: TextAlignVertical.center,
        style: inputStyle,
        decoration: _shellDecoration(
          context,
          hint: hintText,
          leadingPrefix: leading,
          prefixStyleOverride: prefixStyle,
        ),
      ),
    );
  }

  Widget _iataField(
    BuildContext context, {
    required TextEditingController controller,
    required String label,
    required String hintText,
    required IconData icon,
    required String? cityName,
  }) {
    final city = (cityName ?? '').trim();
    final scheme = Theme.of(context).colorScheme;
    return _labeledFieldRow(
      context,
      label: label,
      icon: icon,
      labelWidth: _flightPanelLabelColumnWidth,
      child: TextField(
        controller: controller,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
          LengthLimitingTextInputFormatter(3),
          UpperCaseTextFormatter(),
        ],
        style: _valueStyle(context).copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.55,
        ),
        decoration: _shellDecoration(context, hint: hintText).copyWith(
          suffixText: city.isEmpty ? null : city,
          suffixStyle: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface.withValues(alpha: 0.66),
            letterSpacing: -0.12,
          ),
        ),
      ),
    );
  }

  Widget _shellDropdownForIntegers(
    BuildContext context, {
    required int value,
    required List<int> items,
    required ValueChanged<int> onChanged,
  }) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      isDense: true,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 22,
        color: _fieldIconColor(context),
      ),
      style: _valueStyle(context),
      decoration: _shellDecoration(context),
      items: items
          .map(
            (v) => DropdownMenuItem(
              value: v,
              child: Text('$v', style: _valueStyle(context)),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }

  /// 비행시간 — 라벨·아이콘 한 번, `[시 드롭다운] 시간 [분 드롭다운] 분`.
  Widget _flightDurationRow(BuildContext context) {
    final midStyle = _labelStyle(context).copyWith(
      fontWeight: FontWeight.w600,
      height: 1.22,
    );
    return _labeledFieldRow(
      context,
      label: '비행시간',
      icon: Icons.schedule_outlined,
      labelWidth: _flightPanelLabelColumnWidth,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: _shellDropdownForIntegers(
              context,
              value: _flightHour,
              items: [for (var h = 0; h <= 15; h++) h],
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _flightHour = v);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('시간', style: midStyle),
          ),
          Expanded(
            flex: 2,
            child: _shellDropdownForIntegers(
              context,
              value: _flightMinute,
              items: [for (var m = 0; m <= 55; m += 5) m],
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _flightMinute = v);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text('분', style: midStyle),
          ),
        ],
      ),
    );
  }

  Widget _specialWelcomeField(
    BuildContext context, {
    required List<SpecialWelcomeOption> options,
    required String valueTag,
  }) {
    return _labeledFieldRow(
      context,
      label: 'Special Welcome',
      icon: Icons.celebration_outlined,
      labelWidth: _fieldLabelWidthLong,
      child: DropdownButtonFormField<String>(
        initialValue: valueTag,
        isDense: true,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 22,
          color: _fieldIconColor(context),
        ),
        style: _valueStyle(context),
        decoration: _shellDecoration(context),
        items: options
            .map(
              (o) => DropdownMenuItem(
                value: o.conditionTag,
                child: Text(o.label, style: _valueStyle(context)),
              ),
            )
            .toList(),
        onChanged: (tag) {
          if (tag == null) return;
          HapticFeedback.selectionClick();
          final selected = options.firstWhere(
            (o) => o.conditionTag == tag,
            orElse: () => const SpecialWelcomeOption(
              label: '해당없음',
              conditionTag: noSpecialWelcomeTag,
            ),
          );
          setState(() {
            _specialWelcomeTag = selected.conditionTag;
          });
        },
      ),
    );
  }

  Widget _flightNumberWithCodeshareRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _textField(
            context,
            controller: _flightDigitsController,
            label: '편명',
            hintText: '101',
            icon: Icons.flight_outlined,
            fixedLeadingToken: 'LJ',
            keyboardType: TextInputType.number,
            labelWidth: _flightPanelLabelColumnWidth,
            uniformHeavyStyle: _valueStyle(context).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Tooltip(
          message: '공동운항(Code-share) 편',
          child: Padding(
            padding: const EdgeInsets.only(right: 0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  size: 17,
                  color: _fieldIconColor(context),
                ),
                const SizedBox(width: 5),
                Text(
                  '공동운항',
                  style: _labelStyle(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Transform.scale(
                  scale: 0.9,
                  alignment: Alignment.center,
                  child: Switch.adaptive(
                    value: _isCodeshare,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeTrackColor: scheme.primary.withValues(alpha: 0.38),
                    activeThumbColor: scheme.onPrimary,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() => _isCodeshare = v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _aircraftStatusPanel(
    BuildContext context, {
    required bool hlEntered,
    required AircraftMasterModel? aircraft,
  }) {
    if (!hlEntered) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    if (aircraft != null) {
      final onCard = scheme.onPrimaryContainer;
      final muted = onCard.withValues(alpha: 0.78);
      TextStyle labelStyle() => TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.3,
            color: muted,
          );
      TextStyle valueStyle() => TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.35,
            color: onCard,
          );

      /// 원문·파싱값이 있을 때만 표시 (알 수 없음·빈 값은 생략)
      String? lifevestIfShown(AircraftMasterModel a) {
        final raw = a.lifevest.trim();
        if (raw.isNotEmpty) {
          return raw;
        }
        return switch (a.lifevestKind) {
          LifevestChamberKind.oneChamber => 'one chamber',
          LifevestChamberKind.twoChamber => 'two chamber',
          LifevestChamberKind.unknown => null,
        };
      }

      Widget row(String label, String value, {bool isLast = false}) {
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: Text(label, style: labelStyle()),
              ),
              Expanded(
                child: Text(value, style: valueStyle()),
              ),
            ],
          ),
        );
      }

      final rows = <({String label, String value})>[];
      final m = aircraft.model.trim();
      if (m.isNotEmpty) {
        rows.add((label: '기종', value: m));
      }
      if (aircraft.hasFootrest) {
        rows.add((label: '풋레스트', value: '있음'));
      }
      if (aircraft.hasIsps) {
        rows.add((label: 'ISPS', value: '있음'));
      }
      if (aircraft.hasWifi) {
        rows.add((label: 'Wi-Fi', value: '있음'));
      }
      final lv = lifevestIfShown(aircraft);
      if (lv != null) {
        rows.add((label: 'Life Vest', value: lv));
      }

      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(_fieldRadius),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_outlined,
                size: 22,
                color: scheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: rows.isEmpty
                    ? Text(
                        '마스터에 상세 스펙이 비어 있습니다.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          color: muted,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < rows.length; i++)
                            row(
                              rows[i].label,
                              rows[i].value,
                              isLast: i == rows.length - 1,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(_fieldRadius),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 22,
              color: scheme.tertiary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '기재 정보를 찾지 못했습니다',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.34,
                      color: scheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'HL 번호가 맞는지 확인해 주세요.',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.38,
                      color: scheme.onSurface.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.38,
        color: scheme.onSurface.withValues(alpha: 0.80),
      ),
    );
  }
}

class _SyncStatusText extends ConsumerWidget {
  const _SyncStatusText({required this.syncState});

  final AsyncValue<DateTime?> syncState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(
      alpha: 0.62,
    );
    return syncState.when(
      data: (lastSyncedAt) {
        if (lastSyncedAt == null) {
          return Text(
            '동기화 이력이 없습니다.',
            style: TextStyle(fontSize: 14, color: muted),
          );
        }
        return Text(
          '마지막 동기화: ${lastSyncedAt.toLocal()}',
          style: TextStyle(fontSize: 14, color: muted),
        );
      },
      loading: () => const SyncProgressPanel(),
      error: (_, _) => Text(
        '동기화 실패: 네트워크 또는 URL 설정을 확인하세요.',
        style: TextStyle(fontSize: 14, color: muted),
      ),
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
