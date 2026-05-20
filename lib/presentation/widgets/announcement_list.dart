import 'package:flutter/material.dart';

import '../../core/constants/ui_constants.dart';
import '../../domain/entities/announcement.dart';
import 'liquid_glass_card.dart';

class AnnouncementList extends StatelessWidget {
  const AnnouncementList({
    super.key,
    required this.items,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Announcement> items;
  final String? selectedId;
  final ValueChanged<Announcement> onSelect;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('현재 이정표에 해당하는 루틴 방송이 없습니다.'));
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = item.id == selectedId;
        return AnimatedScale(
          duration: UiConstants.softAnimation,
          scale: isSelected ? 1 : 0.99,
          child: InkWell(
            onTap: () => onSelect(item),
            borderRadius: BorderRadius.circular(UiConstants.cardRadius),
            child: LiquidGlassCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: UiConstants.softAnimation,
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? UiConstants.goOrange.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.record_voice_over_outlined,
                      size: 20,
                      color: isSelected
                          ? UiConstants.goOrange
                          : UiConstants.navyMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
