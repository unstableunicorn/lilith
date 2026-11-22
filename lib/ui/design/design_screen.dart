// Every shared component, with sample content, in both themes. The place
// to look before building a screen and to check a change to a component.

import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';

abstract final class DesignKeys {
  static const Key page = Key('design.page');
}

class DesignScreen extends StatelessWidget {
  const DesignScreen({super.key});

  @override
  Widget build(BuildContext context) => PageScaffold(
    key: DesignKeys.page,
    title: 'Design',
    children: [
      for (final brightness in Brightness.values) ...[
        SectionHeading(
          '${brightness.name[0].toUpperCase()}${brightness.name.substring(1)} theme',
        ),
        Theme(
          data: lilithTheme(brightness),
          child: Builder(
            builder: (context) => Material(
              color: Theme.of(context).colorScheme.surface,
              child: const Padding(padding: Space.page, child: _Samples()),
            ),
          ),
        ),
      ],
    ],
  );
}

class _Samples extends StatelessWidget {
  const _Samples();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AppCard(
        icon: Icons.favorite_rounded,
        title: 'Card with icon and title',
        child: Text('Body text sits here, in the card\'s own colour.'),
      ),
      const AppCard(
        tone: CardTone.highlight,
        icon: Icons.star_rounded,
        title: 'Highlighted card',
        child: Text('For the thing that worked for you.'),
      ),
      const AppCard(
        tone: CardTone.callout,
        icon: Icons.medical_services_rounded,
        title: 'Callout card',
        child: Text('For a note to read before acting.'),
      ),
      const Wrap(
        spacing: Space.sm,
        children: [
          LabelBadge(icon: Icons.verified_rounded, text: 'Clinically backed'),
          LabelBadge(text: 'Plain badge'),
        ],
      ),
      const Row(
        children: [
          Expanded(
            child: StatTile(
              icon: Icons.calendar_today_rounded,
              label: 'Cycle day',
              value: '14',
            ),
          ),
          Expanded(
            child: StatTile(
              icon: Icons.thermostat_rounded,
              label: 'Latest temp',
              value: '36.4 °C',
            ),
          ),
          Expanded(
            child: StatTile(
              icon: Icons.loop_rounded,
              label: 'Avg cycle',
              value: '—',
            ),
          ),
        ],
      ),
      const SectionHeading('Chart'),
      TemperatureChart(
        readings: [
          for (var i = 0; i < 14; i++)
            TemperatureReading(
              date: DateTime(2026, 6, 1 + i),
              celsius: 36.2 + (i > 8 ? 0.4 : 0) + (i % 3) / 20,
            ),
        ],
        periodStarts: {DateTime(2026, 6, 3)},
      ),
      const SectionHeading('Buttons'),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          FilledButton(onPressed: () {}, child: const Text('Primary')),
          FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
          OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
          TextButton(onPressed: () {}, child: const Text('Text')),
          const FilledButton(onPressed: null, child: Text('Disabled')),
        ],
      ),
      const SectionHeading('Chips'),
      Wrap(
        spacing: Space.sm,
        children: [
          ChoiceChip(
            label: const Text('Chosen'),
            selected: true,
            onSelected: (_) {},
          ),
          ChoiceChip(
            label: const Text('Other'),
            selected: false,
            onSelected: (_) {},
          ),
          FilterChip(
            label: const Text('Tagged'),
            selected: true,
            onSelected: (_) {},
          ),
        ],
      ),
      const SectionHeading('Fields'),
      const TextField(
        decoration: InputDecoration(labelText: 'Label', hintText: 'Hint'),
      ),
      const ProblemText('What is wrong with the entry.'),
      const SectionHeading('Notices'),
      NoticeBanner(
        message: 'Something the user must see.',
        detail: 'Detail for a bug report.',
        onDismiss: () {},
      ),
      const BusyIndicator(),
    ],
  );
}
