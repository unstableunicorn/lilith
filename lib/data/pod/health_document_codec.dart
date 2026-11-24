// The JSON document kept on the pod, and the migrations between its versions.

import 'dart:convert';

import 'package:lilith/domain/daily_log.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/health_profile.dart';
import 'package:lilith/domain/period_event.dart';
import 'package:lilith/domain/remedy_feedback.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/shopping_item.dart';
import 'package:lilith/domain/temperature_reading.dart';
import 'package:lilith/domain/wearable_night.dart';

/// The document could not be read as a health document.
class MalformedDocumentException implements Exception {
  const MalformedDocumentException(this.cause);
  final Object cause;
  @override
  String toString() => 'MalformedDocumentException: $cause';
}

/// The document was written by a newer app than this one.
class UnsupportedDocumentVersionException implements Exception {
  const UnsupportedDocumentVersionException(this.version);
  final int version;
  @override
  String toString() =>
      'UnsupportedDocumentVersionException: version $version, this app reads '
      'up to ${HealthDocumentCodec.currentVersion}';
}

/// Brings [doc] up to [HealthDocumentCodec.currentVersion], one step at a time.
///
/// A document without a version is version 1. Version 2 was never written.
/// Version 4 added the shares, version 5 the shares received, version 6 what
/// each share holds, version 7 a period's end and flow, version 8 the
/// wearable temperature nights.
Map<String, dynamic> migrate(Map<String, dynamic> doc) {
  var version = (doc['version'] as num?)?.toInt() ?? 1;
  var current = doc;
  if (version > HealthDocumentCodec.currentVersion) {
    throw UnsupportedDocumentVersionException(version);
  }
  while (version < HealthDocumentCodec.currentVersion) {
    current = switch (version) {
      1 => _v1ToV3(current),
      3 => _v3ToV4(current),
      4 => _v4ToV5(current),
      5 => _v5ToV6(current),
      6 => _v6ToV7(current),
      7 => _v7ToV8(current),
      _ => throw UnsupportedDocumentVersionException(version),
    };
    version = current['version'] as int;
  }
  return current;
}

Map<String, dynamic> _v1ToV3(Map<String, dynamic> doc) => {
  ...doc,
  'version': 3,
  'dailyLogs': <Object>[],
  'remedyFeedback': <Object>[],
  'shopping': <Object>[],
};

Map<String, dynamic> _v3ToV4(Map<String, dynamic> doc) => {
  ...doc,
  'version': 4,
  'shares': <Object>[],
};

Map<String, dynamic> _v4ToV5(Map<String, dynamic> doc) => {
  ...doc,
  'version': 5,
  'received': <Object>[],
};

/// Every share so far held the app view.
Map<String, dynamic> _v5ToV6(Map<String, dynamic> doc) => {
  ...doc,
  'version': 6,
  'shares': [
    for (final s in (doc['shares'] as List? ?? const []))
      {...s as Map<String, dynamic>, 'content': 'cycleData'},
  ],
};

/// Periods gained optional `endDate` and `flow`. Nothing is rewritten; the
/// bump stops an older app from dropping them on its next save.
Map<String, dynamic> _v6ToV7(Map<String, dynamic> doc) => {
  ...doc,
  'version': 7,
};

Map<String, dynamic> _v7ToV8(Map<String, dynamic> doc) => {
  ...doc,
  'version': 8,
  'wearableNights': <Object>[],
};

/// Encodes and decodes [HealthData] as the pod document.
class HealthDocumentCodec {
  const HealthDocumentCodec();

  static const int currentVersion = 8;

  String encode(HealthData data) => jsonEncode({
    'version': currentVersion,
    'readings': [for (final r in data.readings) r.toJson()],
    'periods': [for (final p in data.periods) p.toJson()],
    'dailyLogs': [for (final l in data.dailyLogs) l.toJson()],
    'remedyFeedback': [for (final f in data.remedyFeedback) f.toJson()],
    'shopping': [for (final s in data.shopping) s.toJson()],
    'profile': data.profile.toJson(),
    'shares': [for (final s in data.shares) s.toJson()],
    'received': [for (final r in data.received) r.toJson()],
    'wearableNights': [for (final d in data.wearableNights) d.toJson()],
  });

  /// Reads any supported version; blank content is an empty document.
  HealthData decode(String content) {
    if (content.trim().isEmpty) return HealthData.empty;
    try {
      final doc = migrate(jsonDecode(content) as Map<String, dynamic>);
      final profile = doc['profile'];
      return HealthData(
        readings: _section(doc, 'readings', TemperatureReading.fromJson),
        periods: _section(doc, 'periods', PeriodEvent.fromJson),
        dailyLogs: _section(doc, 'dailyLogs', DailyLog.fromJson),
        remedyFeedback: _section(
          doc,
          'remedyFeedback',
          RemedyFeedback.fromJson,
        ),
        shopping: _section(doc, 'shopping', ShoppingItem.fromJson),
        shares: _section(doc, 'shares', Share.fromJson),
        received: _section(doc, 'received', ReceivedShare.fromJson),
        wearableNights: _section(doc, 'wearableNights', WearableNight.fromJson),
        profile: profile is Map<String, dynamic>
            ? HealthProfile.fromJson(profile)
            : null,
      );
    } on UnsupportedDocumentVersionException {
      rethrow;
    } on FormatException catch (e) {
      throw MalformedDocumentException(e);
      // A document of the wrong shape is a bad document, not a bug here.
      // ignore: avoid_catching_errors
    } on TypeError catch (e) {
      throw MalformedDocumentException(e);
    }
  }

  List<T> _section<T>(
    Map<String, dynamic> doc,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) => [
    for (final item in (doc[key] as List? ?? const []))
      fromJson(item as Map<String, dynamic>),
  ];
}
