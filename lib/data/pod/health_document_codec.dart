// The JSON document kept on the pod, and the migrations between its versions.

import 'dart:convert';

import 'package:lillith/domain/daily_log.dart';
import 'package:lillith/domain/health_data.dart';
import 'package:lillith/domain/health_profile.dart';
import 'package:lillith/domain/period_event.dart';
import 'package:lillith/domain/remedy_feedback.dart';
import 'package:lillith/domain/shopping_item.dart';
import 'package:lillith/domain/temperature_reading.dart';

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
Map<String, dynamic> migrate(Map<String, dynamic> doc) {
  var version = (doc['version'] as num?)?.toInt() ?? 1;
  var current = doc;
  if (version > HealthDocumentCodec.currentVersion) {
    throw UnsupportedDocumentVersionException(version);
  }
  while (version < HealthDocumentCodec.currentVersion) {
    current = switch (version) {
      1 => _v1ToV3(current),
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

/// Encodes and decodes [HealthData] as the pod document.
class HealthDocumentCodec {
  const HealthDocumentCodec();

  static const int currentVersion = 3;

  String encode(HealthData data) => jsonEncode({
    'version': currentVersion,
    'readings': [for (final r in data.readings) r.toJson()],
    'periods': [for (final p in data.periods) p.toJson()],
    'dailyLogs': [for (final l in data.dailyLogs) l.toJson()],
    'remedyFeedback': [for (final f in data.remedyFeedback) f.toJson()],
    'shopping': [for (final s in data.shopping) s.toJson()],
    'profile': data.profile.toJson(),
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
        profile: profile is Map<String, dynamic>
            ? HealthProfile.fromJson(profile)
            : null,
      );
    } on UnsupportedDocumentVersionException {
      rethrow;
    } on FormatException catch (e) {
      throw MalformedDocumentException(e);
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
