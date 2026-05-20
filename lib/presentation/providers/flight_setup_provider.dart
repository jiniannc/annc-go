import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/flight_setup.dart';

class FlightSetupNotifier extends StateNotifier<FlightSetup?> {
  FlightSetupNotifier() : super(null);

  void saveSetup(FlightSetup setup) {
    state = setup;
  }
}

final flightSetupProvider =
    StateNotifierProvider<FlightSetupNotifier, FlightSetup?>(
      (ref) => FlightSetupNotifier(),
    );

final selectedMilestoneProvider = StateProvider<String?>((ref) {
  final setup = ref.watch(flightSetupProvider);
  if (setup == null || setup.milestones.isEmpty) {
    return null;
  }
  return setup.milestones.first;
});

final draftHlNoProvider = StateProvider<String>((ref) => '');
