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

/// A share someone else gave this user, as the recipient keeps it in their
/// own pod document. The folder on the sharer's pod is named after the
/// recipient, so the recipient's own WebID finds it.
class ReceivedShare {
  ReceivedShare({
    required this.sharerWebId,
    required this.label,
    required DateTime addedOn,
    this.code,
  }) : addedOn = dateOnly(addedOn);

  factory ReceivedShare.fromJson(Map<String, dynamic> json) => ReceivedShare(
    sharerWebId: json['sharer'] as String,
    label: json['label'] as String,
    addedOn: DateTime.parse(json['addedOn'] as String),
    code: json['code'] as String?,
  );

  final String sharerWebId;

  /// What the recipient calls the sharer.
  final String label;
  final DateTime addedOn;

  /// The share's code, when the copy is encrypted.
  final String? code;

  Map<String, dynamic> toJson() => {
    'sharer': sharerWebId,
    'label': label,
    'addedOn': addedOn.toIso8601String(),
    if (code != null) 'code': code,
  };

  @override
  bool operator ==(Object other) =>
      other is ReceivedShare &&
      other.sharerWebId == sharerWebId &&
      other.label == label &&
      other.addedOn == addedOn &&
      other.code == code;

  @override
  int get hashCode => Object.hash(sharerWebId, label, addedOn, code);
}

/// What a recipient needs to add a share: the sharer's WebID and, for an
/// encrypted copy, the code. Travels as a link, shown as a QR code.
class ShareInvite {
  const ShareInvite({required this.sharerWebId, this.code});

  /// The invite in [uri]'s query, or null when there is none.
  static ShareInvite? fromUri(Uri uri) {
    final sharer = uri.queryParameters[sharerParam]?.trim();
    if (sharer == null || sharer.isEmpty) return null;
    final code = uri.queryParameters[codeParam]?.trim();
    return ShareInvite(
      sharerWebId: sharer,
      code: code == null || code.isEmpty ? null : code,
    );
  }

  static const String sharerParam = 'share';
  static const String codeParam = 'code';

  final String sharerWebId;
  final String? code;

  /// The link to the app at [base] that carries this invite.
  Uri toUri(Uri base) => base.replace(
    queryParameters: {
      sharerParam: sharerWebId,
      if (code != null) codeParam: code,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is ShareInvite &&
      other.sharerWebId == sharerWebId &&
      other.code == code;

  @override
  int get hashCode => Object.hash(sharerWebId, code);
}
