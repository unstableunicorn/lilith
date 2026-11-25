import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/content/cycle_phases.dart';
import 'package:lilith/domain/cycle_phase.dart';

void main() {
  test('every phase has exactly one entry, in cycle order', () {
    expect(cyclePhaseEntries.map((e) => e.phase), CyclePhase.values);
  });
}
