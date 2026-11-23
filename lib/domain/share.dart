// A read-only share of the cycle data with one named person, served from
// the sharer's own pod, and the part of the data it carries.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:lilith/domain/day.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:meta/meta.dart';

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
  untilRevoked('Until I end it', null),

  /// A day of the user's choosing, given alongside the duration.
  custom('Choose a date', null);

  ShareDuration(this.label, this.days);
  final String label;
  final int? days;

  static const ShareDuration recommended = ShareDuration.thirtyDays;

  bool get isCustom => this == ShareDuration.custom;

  /// The last day the share is readable, or null for no end. A custom
  /// duration takes its day from [customEnd].
  DateTime? endFrom(DateTime today, {DateTime? customEnd}) {
    if (isCustom) return customEnd == null ? null : dateOnly(customEnd);
    return days == null ? null : addDays(dateOnly(today), days!);
  }

  /// The first day a custom end may be: tomorrow.
  static DateTime earliestEnd(DateTime today) => addDays(dateOnly(today), 1);
}

/// What a share's folder holds.
enum ShareContent {
  /// The cycle data for the Lilith app: a JSON copy, encrypted when the
  /// sharer's data is.
  cycleData(
    'The app view',
    'For someone with Lilith: their app shows your cycle, read-only.',
  ),

  /// A PDF report and a CSV, readable without the app, never encrypted.
  report(
    'A PDF report and CSV',
    'For a doctor or anyone without the app: files they open from your pod.',
  );

  ShareContent(this.label, this.description);
  final String label;
  final String description;

  static ShareContent fromName(String? name) => values.firstWhere(
    (c) => c.name == name,
    orElse: () => ShareContent.cycleData,
  );
}

/// One share, as the sharer keeps it in their pod document.
@immutable
class Share {
  Share({
    required this.recipientWebId,
    required this.label,
    required DateTime createdOn,
    DateTime? expiresOn,
    this.code,
    this.content = ShareContent.cycleData,
    ExportRange? range,
  }) : createdOn = dateOnly(createdOn),
       expiresOn = expiresOn == null ? null : dateOnly(expiresOn),
       range = content == ShareContent.report
           ? range ?? ExportRange.sixMonths
           : null;

  factory Share.fromJson(Map<String, dynamic> json) => Share(
    recipientWebId: json['recipient'] as String,
    label: json['label'] as String,
    createdOn: DateTime.parse(json['createdOn'] as String),
    expiresOn: switch (json['expiresOn']) {
      final String s => DateTime.parse(s),
      _ => null,
    },
    code: json['code'] as String?,
    content: ShareContent.fromName(json['content'] as String?),
    range: switch (json['range']) {
      final String r => ExportRange.values.firstWhere((e) => e.name == r),
      _ => null,
    },
  );

  final String recipientWebId;

  /// What the sharer calls the recipient.
  final String label;
  final DateTime createdOn;

  /// The last day the share is readable; null means until revoked.
  final DateTime? expiresOn;

  /// The share key as a code, kept so the copy can be rewritten after every
  /// save. Null when the sharer's data is plain and so is the copy, and for
  /// a report, which is never encrypted.
  final String? code;

  final ShareContent content;

  /// How far back a report reaches; null for the app view.
  final ExportRange? range;

  String get id => shareId(recipientWebId);
  bool get isEncrypted => code != null;
  bool get isReport => content == ShareContent.report;

  /// True from the day after [expiresOn].
  bool isExpired(DateTime today) =>
      expiresOn != null && dateOnly(today).isAfter(expiresOn!);

  Map<String, dynamic> toJson() => {
    'recipient': recipientWebId,
    'label': label,
    'createdOn': createdOn.toIso8601String(),
    if (expiresOn != null) 'expiresOn': expiresOn!.toIso8601String(),
    if (code != null) 'code': code,
    'content': content.name,
    if (range != null) 'range': range!.name,
  };

  @override
  bool operator ==(Object other) =>
      other is Share &&
      other.recipientWebId == recipientWebId &&
      other.label == label &&
      other.createdOn == createdOn &&
      other.expiresOn == expiresOn &&
      other.code == code &&
      other.content == content &&
      other.range == range;

  @override
  int get hashCode => Object.hash(
    recipientWebId,
    label,
    createdOn,
    expiresOn,
    code,
    content,
    range,
  );
}

/// A share someone else gave this user, as the recipient keeps it in their
/// own pod document. The folder on the sharer's pod is named after the
/// recipient, so the recipient's own WebID finds it.
@immutable
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

  ReceivedShare withCode(String? code) => ReceivedShare(
    sharerWebId: sharerWebId,
    label: label,
    addedOn: addedOn,
    code: code,
  );

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
@immutable
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
