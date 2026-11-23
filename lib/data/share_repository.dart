// The shares the logged-in user has given, for the whole app: creating and
// ending them, keeping every copy current, and ending the ones past their day.

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lilith/data/export/csv_export.dart';
import 'package:lilith/data/export/pdf_report.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/notifications/notification_service.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/pod/share_service.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/domain/share_reminder.dart';

/// What last went wrong, for the UI to phrase.
enum ShareError { notLoggedIn, unreachable, failed }

class ShareRepository extends ChangeNotifier {
  ShareRepository(
    this._health,
    this._pod, {
    required this.protection,
    this._notifications = const NoNotificationService(),
    this._now = DateTime.now,
    Random? random,
    this._codec = const HealthDocumentCodec(),
    this._cipher = const ShareCipher(),
    this._pdf = const PdfReport(),
    this._csv = const CsvExport(),
  }) : _random = random ?? Random.secure() {
    _health.addListener(_onHealthChanged);
  }

  final HealthRepository _health;
  final ShareService _pod;
  final NotificationService _notifications;

  /// How the sharer's own data is stored. Encrypted data gets encrypted
  /// copies, each with its own key.
  final DataProtection protection;

  final DateTime Function() _now;
  final Random _random;
  final HealthDocumentCodec _codec;
  final ShareCipher _cipher;
  final PdfReport _pdf;
  final CsvExport _csv;

  HealthData? _lastCopied;
  bool _busy = false;
  ShareError? _error;
  String? _errorDetail;

  List<Share> get shares => _health.data.shares;
  bool get isBusy => _busy;
  ShareError? get error => _error;
  String? get errorDetail => _errorDetail;

  /// Shares past their last day that have not been ended yet.
  List<Share> overdue(DateTime today) =>
      shares.where((s) => s.isExpired(today)).toList();

  /// Opens the share, writes the first copy and records it. Null, with
  /// [error] set, when the pod refused. [today] decides the end day.
  Future<Share?> create({
    required String recipientWebId,
    required String label,
    required ShareDuration duration,
    required DateTime today,
    ShareContent content = ShareContent.cycleData,
    ExportRange? range,
  }) => _run(() async {
    final share = Share(
      recipientWebId: recipientWebId.trim(),
      label: label.trim(),
      createdOn: today,
      expiresOn: duration.endFrom(today),
      code:
          protection == DataProtection.encrypted &&
              content == ShareContent.cycleData
          ? ShareKey.generate(_random).code
          : null,
      content: content,
      range: range,
    );
    await _pod.open(SharePlan.forRecipient(share.recipientWebId));
    await _writeCopy(share, sharedView(_health.data));
    await _health.apply((d) => d.withShare(share));
    await _remind(share);
    return share;
  });

  /// Where the share's folder is, for a recipient without the app.
  Future<Uri> folderUrl(Share share) =>
      _pod.folderUrl(SharePlan.forRecipient(share.recipientWebId));

  /// Ends the share on the pod, then forgets it.
  Future<void> revoke(Share share) => _run(() async {
    await _pod.close(SharePlan.forRecipient(share.recipientWebId));
    await _health.apply((d) => d.withoutShare(share.recipientWebId));
    await _notifications.cancel(shareReminderId(share));
  });

  /// Ends every share past its last day and makes sure the rest have their
  /// reminder on this device. Safe to call on every start.
  Future<void> sweep(DateTime today) async {
    for (final share in overdue(today)) {
      await revoke(share);
    }
    for (final share in shares) {
      await _remind(share, ask: false);
    }
  }

  /// Schedules the share's end-day reminder, asking for permission on the
  /// first share made here. A share with no end day has no reminder.
  Future<void> _remind(Share share, {bool ask = true}) async {
    final reminder = shareReminder(share);
    if (reminder == null) return;
    if (ask) await _notifications.requestPermission();
    await _notifications.schedule(reminder);
  }

  void clearError() {
    _error = null;
    _errorDetail = null;
    notifyListeners();
  }

  // The copies follow the data: after a save that changed what is shared,
  // every copy is rewritten. The first sight of loaded data is the baseline.
  void _onHealthChanged() {
    if (!_health.isLoaded) return;
    final current = sharedView(_health.data);
    final previous = _lastCopied;
    _lastCopied = current;
    if (previous == null || previous == current || shares.isEmpty) {
      notifyListeners();
      return;
    }
    unawaited(
      _run(() async {
        for (final share in shares) {
          await _writeCopy(share, current);
        }
      }),
    );
  }

  /// The app view as JSON or a JWE; a report as a PDF and a CSV.
  Future<void> _writeCopy(Share share, HealthData view) async {
    final plan = SharePlan.forRecipient(share.recipientWebId);
    if (!share.isReport) {
      final json = _codec.encode(view);
      return await _pod.write(plan, switch (share.code) {
        final code? => _cipher.encrypt(json, ShareKey.fromCode(code)!, _random),
        null => json,
      });
    }
    final range = share.range!;
    final today = _now();
    final pdf = await _pdf.build(
      reportContent(view, range: range, today: today),
    );
    await _pod.writeFile(plan, SharePlan.reportName, pdf.bytes);
    await _pod.writeFile(
      plan,
      SharePlan.csvName,
      _csv
          .build(
            exportRows(view, range: range, today: today),
            today: today,
          )
          .bytes,
    );
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    _busy = true;
    _error = null;
    _errorDetail = null;
    notifyListeners();
    try {
      return await action();
    } on PodNotLoggedInException {
      _error = ShareError.notLoggedIn;
    } on PodUnavailableException catch (e) {
      _error = ShareError.unreachable;
      _errorDetail = e.message;
    } on PodException catch (e) {
      _error = ShareError.failed;
      _errorDetail = e.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
    return null;
  }

  @override
  void dispose() {
    _health.removeListener(_onHealthChanged);
    super.dispose();
  }
}
