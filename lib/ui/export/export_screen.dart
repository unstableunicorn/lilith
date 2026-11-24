// Export: pick a span, then share it as a PDF report for a doctor or a CSV
// for a spreadsheet. Made on the device; nothing leaves it but by the share.

import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/page_settings_repository.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/ui/components/components.dart';
import 'package:lilith/ui/core/file_sharer.dart';
import 'package:lilith/ui/export/export_view_model.dart';
import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

abstract final class ExportKeys {
  static const Key error = Key('export.error');
  static const Key dismissError = Key('export.dismissError');
  static const Key empty = Key('export.empty');
  static const Key dayCount = Key('export.dayCount');
  static const Key sharePdf = Key('export.sharePdf');
  static const Key shareCsv = Key('export.shareCsv');
  static const Key shared = Key('export.shared');
  static Key range(ExportRange r) => Key('export.range.${r.name}');
}

class ExportScreen extends StatelessWidget {
  const ExportScreen({this.now = DateTime.now, super.key});

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (context) => ExportViewModel(
      context.read<HealthRepository>(),
      now: now,
      share: context.read<FileSharer>(),
      pdf: context.read<PdfReport>(),
      fertileWindowMode: context
          .read<PageSettingsRepository>()
          .settings
          .fertileWindowMode,
    ),
    child: const _ExportView(),
  );
}

class _ExportView extends StatelessWidget {
  const _ExportView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ExportViewModel>();
    final theme = Theme.of(context);
    return PageScaffold(
      title: 'Export your data',
      children: [
        if (vm.error case final error?)
          NoticeBanner(
            key: ExportKeys.error,
            message: _describe(error),
            dismissKey: ExportKeys.dismissError,
            onDismiss: vm.clearError,
          ),
        const Text(
          'A report to show your doctor, or a spreadsheet of every logged '
          'day. The file is made on this device and goes only where you '
          'send it.',
        ),
        const SectionHeading('How far back'),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.xs,
          children: [
            for (final r in ExportRange.values)
              ChoiceChip(
                key: ExportKeys.range(r),
                label: Text(r.label),
                selected: vm.range == r,
                onSelected: (_) => vm.setRange(r),
              ),
          ],
        ),
        const SizedBox(height: Space.md),
        if (vm.canExport)
          Text(
            key: ExportKeys.dayCount,
            '${vm.dayCount} ${vm.dayCount == 1 ? 'day' : 'days'} with '
            'something logged.',
          )
        else
          Text(
            key: ExportKeys.empty,
            'Nothing logged in this span yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: Space.xl),
        FilledButton.icon(
          key: ExportKeys.sharePdf,
          onPressed: vm.canExport && !vm.isBusy
              ? () => vm.share(ExportFormat.pdf)
              : null,
          icon: const Icon(Icons.picture_as_pdf_rounded),
          label: Text(
            vm.busyWith == ExportFormat.pdf
                ? 'Preparing…'
                : 'Share as PDF report',
          ),
        ),
        const SizedBox(height: Space.sm),
        FilledButton.tonalIcon(
          key: ExportKeys.shareCsv,
          onPressed: vm.canExport && !vm.isBusy
              ? () => vm.share(ExportFormat.csv)
              : null,
          icon: const Icon(Icons.table_chart_rounded),
          label: Text(
            vm.busyWith == ExportFormat.csv
                ? 'Preparing…'
                : 'Share as CSV spreadsheet',
          ),
        ),
        if (vm.lastShared case final format?)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            child: Text(
              key: ExportKeys.shared,
              switch (format) {
                ExportFormat.pdf => 'PDF report handed over.',
                ExportFormat.csv => 'CSV handed over.',
              },
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        const SizedBox(height: Space.lg),
        const AppCard(
          icon: Icons.info_outline_rounded,
          title: 'What is in it',
          child: Text(
            'The PDF has your cycle summary and prediction, your health '
            'profile, each cycle, a temperature chart and every logged day. '
            'The CSV has one line per day: temperature, period start, flow, '
            'pain and symptoms. Neither includes your shopping list or '
            'remedy ratings.',
          ),
        ),
      ],
    );
  }

  String _describe(ExportError error) => switch (error) {
    ExportError.shareFailed =>
      'The file could not be handed over. Try again, or try the other '
          'format.',
  };
}
