import 'package:flutter/material.dart';

import 'liquid_glass_card.dart';

class QuickAccessBar extends StatelessWidget {
  const QuickAccessBar({
    super.key,
    required this.onSituationalTap,
    required this.onEmergencyTap,
  });

  final VoidCallback onSituationalTap;
  final VoidCallback onEmergencyTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: LiquidGlassCard(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          borderRadius: 24,
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onSituationalTap,
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('상황별'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEmergencyTap,
                  icon: const Icon(Icons.sos_outlined, size: 18),
                  label: const Text('비상'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
