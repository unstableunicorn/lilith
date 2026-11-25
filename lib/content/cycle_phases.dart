// Learn content: what each phase of the cycle is, with its source.

import 'package:lilith/content/symptom_advice.dart' show Source;
import 'package:lilith/domain/cycle_phase.dart';

/// One phase explained.
class CyclePhaseEntry {
  const CyclePhaseEntry({
    required this.phase,
    required this.title,
    required this.text,
    required this.source,
  });

  final CyclePhase phase;
  final String title;
  final String text;
  final Source source;
}

const Source _clevelandClinic = Source(
  'Cleveland Clinic',
  'https://my.clevelandclinic.org/health/articles/10132-menstrual-cycle',
);

/// The phases in cycle order.
const List<CyclePhaseEntry> cyclePhaseEntries = [
  CyclePhaseEntry(
    phase: CyclePhase.menstrual,
    title: 'Menstrual',
    text:
        'Your period: the lining of the uterus sheds when there is no '
        'pregnancy. Most people bleed for three to five days; anything from '
        'three to seven is usually nothing to worry about.',
    source: _clevelandClinic,
  ),
  CyclePhaseEntry(
    phase: CyclePhase.follicular,
    title: 'Follicular',
    text:
        'Starts on the first day of your period and ends at ovulation. '
        'Oestrogen rises and the lining of the uterus grows and thickens '
        'while an egg matures. Lilith calls the days after bleeding '
        'follicular.',
    source: _clevelandClinic,
  ),
  CyclePhaseEntry(
    phase: CyclePhase.luteal,
    title: 'Luteal',
    text:
        'From ovulation to your next period, about day 15 to day 28 of a '
        '28-day cycle. Progesterone rises to prepare the lining for a '
        'pregnancy; without one, hormone levels fall and the next period '
        'starts. Lilith dates ovulation from a temperature rise when there '
        'is one, otherwise 14 days before the predicted period.',
    source: _clevelandClinic,
  ),
];
