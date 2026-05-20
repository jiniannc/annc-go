import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/ui_constants.dart';
import '../../domain/entities/announcement.dart';
import '../providers/announcement_provider.dart';
import '../providers/flight_setup_provider.dart';
import 'liquid_glass_card.dart';

class AnnouncementDetailPanel extends ConsumerWidget {
  const AnnouncementDetailPanel({
    super.key,
    required this.selectedAnnouncement,
  });

  final Announcement? selectedAnnouncement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatted = ref.watch(formattedSelectedAnnouncementProvider);
    final reasons = ref.watch(delayReasonsProvider);
    final selectedReason = ref.watch(selectedDelayReasonProvider);

    if (selectedAnnouncement == null) {
      return LiquidGlassCard(
        child: SizedBox(
          width: double.infinity,
          child: Center(
            child: Text(
              '방송문을 선택하면 KR/EN 본문이 여기에 표시됩니다.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: UiConstants.navyMuted),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: UiConstants.softAnimation,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: SizedBox(
        key: ValueKey(selectedAnnouncement!.id),
        child: Column(
          children: [
            if (reasons.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final reason = reasons[index];
                    final selected = reason.id == selectedReason?.id;
                    final setup = ref.watch(flightSetupProvider);
                    final chipText = setup == null
                        ? reason.reasonKo.trim().isEmpty
                            ? reason.id
                            : reason.reasonKo
                        : ref
                              .watch(announcementFormatterProvider)
                              .formatDelayReasonSnippet(
                                template: reason.reasonKo,
                                setup: setup,
                                originAirport: ref.watch(originAirportProvider),
                                destinationAirport:
                                    ref.watch(destinationAirportProvider),
                                aircraft: ref.watch(currentAircraftProvider),
                              );
                    return ChoiceChip(
                      label: Text(chipText),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) {
                        ref.read(selectedDelayReasonProvider.notifier).state =
                            reason;
                      },
                    );
                  },
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemCount: reasons.length,
                ),
              ),
            if (reasons.isNotEmpty) const SizedBox(height: 10),
            Expanded(
              child: _LanguageCard(
                language: 'KR',
                text: formatted?.ko ?? selectedAnnouncement!.contentKR,
                isEnglish: false,
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _LanguageCard(
                language: 'EN',
                text: formatted?.en ?? selectedAnnouncement!.contentEN,
                isEnglish: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.language,
    required this.text,
    required this.isEnglish,
  });

  final String language;
  final String text;
  final bool isEnglish;

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: UiConstants.minTouchTarget,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: UiConstants.goOrange.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                language,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: UiConstants.goOrange,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.7,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.44,
                  color: isEnglish ? Colors.grey.shade700 : UiConstants.navyInk,
                  fontStyle: isEnglish ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
