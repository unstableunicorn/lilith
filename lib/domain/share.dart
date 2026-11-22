// A read-only share of the cycle data with one named person, served from
// the sharer's own pod, and the part of the data it carries.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/health_data.dart';

/// The folder name of the share for [recipientWebId]: the first 16 hex digits
/// of the SHA-256 of the WebID. Both sides can compute it, nobody else can
/// read the WebID back from it.
String shareId(String recipientWebId) => sha256
    .convert(utf8.encode(recipientWebId.trim()))
    .toString()
    .substring(0, 16);

/// The part of [data] a recipient sees: the cycle data only. The health
/// profile, remedy verdicts, shopping list and the shares stay with the owner.
HealthData sharedView(HealthData data) => HealthData(
  readings: data.readings,
  periods: data.periods,
  dailyLogs: data.dailyLogs,
);

/// How long a share lasts, as offered on the share screen.
enum ShareDuration {
  thirtyDays('30 days', 30),
  ninetyDays('90 days', 90),
  untilRevoked('Until I end it', null);

  const ShareDuration(this.label, this.days);
  final String label;
  final int? days;

  static const ShareDuration recommended = ShareDuration.thirtyDays;

  /// The last day the share is readable, or null for no end.
  DateTime? endFrom(DateTime today) =>
      days == null ? null : addDays(dateOnly(today), days!);
}

/// One share, as the sharer keeps it in their pod document.
class Share {
  Share({
    required this.recipientWebId,
    required this.label,
    required DateTime createdOn,
    DateTime? expiresOn,
    this.code,
  }) : createdOn = dateOnly(createdOn),
       expiresOn = expiresOn == null ? null : dateOnly(expiresOn);

  factory Share.fromJson(Map<String, dynamic> json) => Share(
    recipientWebId: json['recipient'] as String,
    label: json['label'] as String,
    createdOn: DateTime.parse(json['createdOn'] as String),
    expiresOn: switch (json['expiresOn']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    code: json['code'] as String?,
  );

  final String recipientWebId;

  /// What the sharer calls the recipient.
  final String label;
  final DateTime createdOn;

  /// The last day the share is readable; null means until revoked.
  final DateTime? expiresOn;

  /// The share key as a code, kept so the copy can be rewritten after every
  /// save. Null when the sharer's data is plain and so is the copy.
  final String? code;

  String get id => shareId(recipientWebId);
  bool get isEncrypted => code != null;

  /// True from the day after [expiresOn].
  bool isExpired(DateTime today) =>
      expiresOn != null && dateOnly(today).isAfter(expiresOn!);

  Map<String, dynamic> toJson() => {
    'recipient': recipientWebId,
    'label': label,
    'createdOn': createdOn.toIso8601String(),
    if (expiresOn != null) 'expiresOn': expiresOn!.toIso8601String(),
    if (code != null) 'code': code,
  };

  @override
  bool operator ==(Object other) =>
      other is Share &&
      other.recipientWebId == recipientWebId &&
      other.label == label &&
      other.createdOn == createdOn &&
      other.expiresOn == expiresOn &&
      other.code == code;

  @override
  int get hashCode =>
      Object.hash(recipientWebId, label, createdOn, expiresOn, code);
}
