// The shares the logged-in user has given, for the whole app: creating and
// ending them, keeping every copy current, and ending the ones past their day.

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/pod/share_service.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';

/// What last went wrong, for the UI to phrase.
enum ShareError { notLoggedIn, unreachable, failed }

class ShareRepository extends ChangeNotifier {
  ShareRepository(
    this._health,
    this._pod, {
    required this.protection,
    Random? random,
    HealthDocumentCodec this._codec = const HealthDocumentCodec(),
    ShareCipher this._cipher = const ShareCipher(),
  }) : _random = random ?? Random.secure() {
    _health.addListener(_onHealthChanged);
  }

  final HealthRepository _health;
  final ShareService _pod;

  /// How the sharer's own data is stored. Encrypted data gets encrypted
  /// copies, each with its own key.
  final DataProtection protection;

  final Random _random;
  final HealthDocumentCodec _codec;
  final ShareCipher _cipher;

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
  }) => _run(() async {
    final share = Share(
      recipientWebId: recipientWebId.trim(),
      label: label.trim(),
      createdOn: today,
      expiresOn: duration.endFrom(today),
      code: protection == DataProtection.encrypted
          ? ShareKey.generate(_random).code
          : null,
    );
    final plan = SharePlan.forRecipient(share.recipientWebId);
    await _pod.open(plan);
    await _pod.write(plan, _copyFor(share, sharedView(_health.data)));
    await _health.apply((d) => d.withShare(share));
    return share;
  });

  /// Ends the share on the pod, then forgets it.
  Future<void> revoke(Share share) => _run(() async {
    await _pod.close(SharePlan.forRecipient(share.recipientWebId));
    await _health.apply((d) => d.withoutShare(share.recipientWebId));
  });

  /// Ends every share past its last day. Safe to call on every start.
  Future<void> sweep(DateTime today) async {
    for (final share in overdue(today)) {
      await revoke(share);
    }
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
    _run(() async {
      for (final share in shares) {
        await _pod.write(
          SharePlan.forRecipient(share.recipientWebId),
          _copyFor(share, current),
        );
      }
    });
  }

  String _copyFor(Share share, HealthData view) {
    final json = _codec.encode(view);
    return switch (share.code) {
      final code? => _cipher.encrypt(json, ShareKey.fromCode(code)!, _random),
      null => json,
    };
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
