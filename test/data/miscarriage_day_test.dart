import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:lilith/data/export/csv_export.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/domain/body_signs.dart';
import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/life_factor.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/log/log_summary.dart';

/// A miscarriage as something logged on its day: kept in the day's log,
/// listed in exports, never sent to a follower, and read from the life
/// factor it used to be.
void main() {
  const codec = HealthDocumentCodec();
  const csv = CsvExport();
  final day = DateTime(2026, 4, 2);
  final earlier = DateTime(2025, 11, 3);
  final today = DateTime(2026, 6, 10);

  group('DailyLog', () {
    test('is not marked unless said, and writes no key then', () {
      final log = DailyLog(date: day, painLevel: 3);
      expect(log.miscarriage, isFalse);
      expect(log.toJson().containsKey('miscarriage'), isFalse);
      expect(DailyLog.fromJson(log.toJson()).miscarriage, isFalse);
    });

    test('a day that holds only a miscarriage is worth storing', () {
      expect(DailyLog(date: day, miscarriage: true).isEmpty, isFalse);
      expect(DailyLog(date: day).isEmpty, isTrue);
    });

    test('round-trips through JSON', () {
      final log = DailyLog(date: day, miscarriage: true, painLevel: 3);
      final json = jsonDecode(jsonEncode(log.toJson())) as Map<String, dynamic>;
      expect(json['miscarriage'], isTrue);
      expect(DailyLog.fromJson(json), log);
      expect(DailyLog.fromJson(json).miscarriage, isTrue);
    });

    test('is part of what a day equals', () {
      expect(
        DailyLog(date: day, miscarriage: true),
        isNot(DailyLog(date: day)),
      );
      expect(
        DailyLog(date: day, miscarriage: true).hashCode,
        DailyLog(date: day, miscarriage: true).hashCode,
      );
    });

    test('copyWith sets it, clears it, and otherwise keeps it', () {
      final log = DailyLog(date: day, miscarriage: true);
      expect(log.copyWith(painLevel: 2).miscarriage, isTrue);
      expect(log.copyWith(miscarriage: false).miscarriage, isFalse);
      expect(
        DailyLog(date: day).copyWith(miscarriage: true).miscarriage,
        isTrue,
      );
    });
  });

  group('HealthData', () {
    test('lists the days a miscarriage is logged on, oldest first', () {
      final data = HealthData.empty
          .withDailyLog(DailyLog(date: day, miscarriage: true))
          .withDailyLog(DailyLog(date: DateTime(2026, 1, 9), painLevel: 2))
          .withDailyLog(DailyLog(date: earlier, miscarriage: true));
      expect(data.miscarriageDays, [earlier, day]);
      expect(HealthData.empty.miscarriageDays, isEmpty);
    });

    test('withMiscarriageDays marks a day, keeping what it holds', () {
      final data = HealthData.empty
          .withDailyLog(DailyLog(date: day, painLevel: 4, note: 'hospital'))
          .withMiscarriageDays([DateTime(2026, 4, 2, 15), earlier]);
      expect(data.miscarriageDays, [earlier, day]);
      expect(data.logFor(day)!.painLevel, 4);
      expect(data.logFor(day)!.note, 'hospital');
      expect(data.logFor(earlier), DailyLog(date: earlier, miscarriage: true));
    });

    test('withMiscarriageDays unmarks the days left out, and drops a day '
        'that then holds nothing', () {
      final data = HealthData.empty
          .withDailyLog(DailyLog(date: day, miscarriage: true, painLevel: 4))
          .withDailyLog(DailyLog(date: earlier, miscarriage: true))
          .withMiscarriageDays(const []);
      expect(data.miscarriageDays, isEmpty);
      expect(data.logFor(day), DailyLog(date: day, painLevel: 4));
      expect(data.logFor(earlier), isNull);
    });

    test('withMiscarriageDays leaves periods as they are', () {
      final period = PeriodEvent(startDate: DateTime(2026, 3, 1));
      final data = HealthData.empty.withPeriod(period).withMiscarriageDays([
        day,
      ]);
      expect(data.periods, [period]);
    });
  });

  test('the summary History shows says it', () {
    expect(logSummary(DailyLog(date: day, miscarriage: true)), 'miscarriage');
    expect(
      logSummary(
        DailyLog(
          date: day,
          miscarriage: true,
          painLevel: 2,
          signs: BodySigns(moods: const {Mood.calm}),
        ),
      ),
      'pain 2/10, miscarriage, calm',
    );
  });

  group('a share', () {
    final data = HealthData.empty
        .withDailyLog(DailyLog(date: day, miscarriage: true, painLevel: 4))
        .withDailyLog(DailyLog(date: earlier, miscarriage: true))
        .withProfile(
          HealthProfile(
            lifeFactors: [
              LifeFactor(
                kind: LifeFactorKind.breastfeeding,
                start: DateTime(2026, 1),
              ),
              LifeFactor(
                kind: LifeFactorKind.pregnant,
                start: DateTime(2026, 5),
              ),
            ],
          ),
        );

    test('never carries a miscarriage, whatever else is shared', () {
      for (final all in [false, true]) {
        final shared = sharedView(
          data,
          includeNotes: all,
          includeContraception: all,
          includeSigns: all,
        );
        expect(shared.miscarriageDays, isEmpty, reason: 'all: $all');
        expect(shared.logFor(day), DailyLog(date: day, painLevel: 4));
        expect(shared.logFor(earlier), isNull);
      }
    });

    test('carries a pregnancy, and never breastfeeding', () {
      expect(sharedView(data).profile.lifeFactors, [
        LifeFactor(kind: LifeFactorKind.pregnant, start: DateTime(2026, 5)),
      ]);
    });

    test('with only breastfeeding the shared profile is empty', () {
      final shared = sharedView(
        HealthData.empty.withProfile(
          HealthProfile(
            lifeFactors: [
              LifeFactor(
                kind: LifeFactorKind.breastfeeding,
                start: DateTime(2026, 1),
              ),
            ],
          ),
        ),
      );
      expect(shared.profile.isEmpty, isTrue);
    });
  });

  group('CSV', () {
    test('has a miscarriage column, after the columns it already had', () {
      expect(CsvExport.header.last, 'miscarriage');
      expect(CsvExport.header.indexOf('tags'), 21);
      expect(CsvExport.header, hasLength(23));
    });

    test('says yes on the day, and nothing on any other', () {
      final lines = csv
          .text([
            ExportRow(
              date: day,
              log: DailyLog(date: day, miscarriage: true, painLevel: 2),
            ),
            ExportRow(
              date: today,
              log: DailyLog(date: today, painLevel: 1),
            ),
          ])
          .split('\r\n');
      expect(lines[1], '2026-04-02,,,,,,2,,,,,,,,,,,,,,,,yes');
      expect(lines[2], '2026-06-10,,,,,,1,,,,,,,,,,,,,,,,');
    });
  });

  group('the PDF report', () {
    ReportContent report(HealthData data) =>
        reportContent(data, range: ExportRange.all, today: today);
    String? row(List<(String, String)> rows, String label) =>
        rows.where((r) => r.$1 == label).map((r) => r.$2).firstOrNull;

    test('names it in the day row', () {
      expect(
        reportDayCells(
          ExportRow(
            date: day,
            log: DailyLog(
              date: day,
              miscarriage: true,
              symptoms: const {Symptom.cramps},
            ),
          ),
        )[5],
        'Cramps, Miscarriage',
      );
    });

    test('lists the days in the profile, though nothing else is in it', () {
      final c = report(
        HealthData.empty
            .withDailyLog(DailyLog(date: day, miscarriage: true))
            .withDailyLog(DailyLog(date: earlier, miscarriage: true)),
      );
      expect(row(c.profile, 'Miscarriages logged'), '2025-11-03, 2026-04-02');
    });

    test('says nothing of them when none is logged', () {
      final c = report(
        HealthData.empty
            .withDailyLog(DailyLog(date: day, painLevel: 2))
            .withProfile(HealthProfile(notes: 'n')),
      );
      expect(row(c.profile, 'Miscarriages logged'), isNull);
    });

    test('lists breastfeeding with its dates, and pauses nothing for it', () {
      final c = report(
        HealthData.empty
            .withPeriod(PeriodEvent(startDate: DateTime(2026, 4, 14)))
            .withPeriod(PeriodEvent(startDate: DateTime(2026, 5, 12)))
            .withProfile(
              HealthProfile(
                lifeFactors: [
                  LifeFactor(
                    kind: LifeFactorKind.breastfeeding,
                    start: DateTime(2025, 9),
                    end: DateTime(2026, 3),
                  ),
                  LifeFactor(
                    kind: LifeFactorKind.breastfeeding,
                    start: DateTime(2026, 5, 20),
                  ),
                ],
              ),
            ),
      );
      expect(
        row(c.profile, 'Pregnancy and breastfeeding'),
        'Breastfeeding from 2025-09-01 to 2026-03-01; '
        'Breastfeeding from 2026-05-20 (ongoing)',
      );
      expect(row(c.summary, 'Predictions'), isNull);
      expect(row(c.summary, 'Predicted next period'), isNotNull);
    });
  });

  group('a document written when a miscarriage was a life factor', () {
    String legacy(HealthData data, List<Map<String, String>> factors) {
      final doc = jsonDecode(codec.encode(data)) as Map<String, dynamic>;
      doc['profile'] = {
        ...?(doc['profile'] as Map<String, dynamic>?),
        'lifeFactors': factors,
      };
      return jsonEncode(doc);
    }

    test('loads it as a day entry on its start date', () {
      final data = codec.decode(
        legacy(HealthData.empty, [
          {'kind': 'pregnant', 'start': '2026-05-01'},
          {'kind': 'miscarriage', 'start': '2026-04-02', 'end': '2026-04-20'},
        ]),
      );
      expect(data.miscarriageDays, [day]);
      expect(data.profile.lifeFactors, [
        LifeFactor(kind: LifeFactorKind.pregnant, start: DateTime(2026, 5)),
      ]);
    });

    test('keeps what the day already holds', () {
      final data = codec.decode(
        legacy(
          HealthData.empty.withDailyLog(DailyLog(date: day, painLevel: 6)),
          [
            {'kind': 'miscarriage', 'start': '2026-04-02'},
          ],
        ),
      );
      expect(
        data.logFor(day),
        DailyLog(date: day, painLevel: 6, miscarriage: true),
      );
    });

    test('is written back without the factor, with the day', () {
      final again = codec.encode(
        codec.decode(
          legacy(HealthData.empty, [
            {'kind': 'miscarriage', 'start': '2026-04-02'},
          ]),
        ),
      );
      expect(again, isNot(contains('"kind":"miscarriage"')));
      expect(codec.decode(again).miscarriageDays, [day]);
    });
  });
}
