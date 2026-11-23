// The shares other people gave this user: adding one, fetching its data,
// and forgetting it. The list lives in the user's own pod document.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lilith/data/health_repository.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_cipher.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/pod/share_reader.dart';
import 'package:lilith/data/settings_store.dart';
import 'package:lilith/domain/health_data.dart';
import 'package:lilith/domain/share.dart';

/// Why a share could not be read.
enum ReceivedShareError {
  /// Missing or refused: ended, or never made for this user.
  ended,

  /// The copy is encrypted and no code was given.
  needsCode,
  wrongCode,
  malformed,
  unreachable,
  notLoggedIn,
}

/// What this user sees of one sharer's data right now.
sealed class SharedView {
  const SharedView();
}

class SharedViewLoading extends SharedView {
  const SharedViewLoading();
}

class SharedViewReady extends SharedView {
  const SharedViewReady(this.data);
  final HealthData data;
}

class SharedViewFailed extends SharedView {
  const SharedViewFailed(this.error, {this.detail});
  final ReceivedShareError error;
  final String? detail;
}

class ReceivedShareRepository extends ChangeNotifier {
  ReceivedShareRepository(
    this._health,
    this._reader, {
    required this.ownWebId,
    this._settings,
    this.codec = const HealthDocumentCodec(),
    this.cipher = const ShareCipher(),
  }) {
    _health.addListener(notifyListeners);
  }

  final HealthRepository _health;
  final ShareReader _reader;
  final SettingsStore? _settings;
  ShareInvite? _invite;

  /// This user's WebID, which names the folder on every sharer's pod.
  final String ownWebId;
  final HealthDocumentCodec codec;
  final ShareCipher cipher;

  final Map<String, SharedView> _views = {};

  List<ReceivedShare> get received => _health.data.received;

  /// An invite the app was opened with and the user has not acted on.
  ShareInvite? get pendingInvite => _invite;

  /// Picks up the invite kept across the login, if any.
  Future<void> loadInvite() async {
    _invite = await _settings?.readInvite();
    notifyListeners();
  }

  /// [loadInvite] with nothing to wait for, for a provider's create.
  void loadInviteLater() => unawaited(loadInvite());

  Future<void> clearInvite() async {
    _invite = null;
    await _settings?.clearInvite();
    notifyListeners();
  }

  /// The latest fetch for [share]; loading until [refresh] has run.
  SharedView viewOf(ReceivedShare share) =>
      _views[share.sharerWebId] ?? const SharedViewLoading();

  /// Fetches the share once to prove it can be read, then records it.
  /// Null on success, else why not; nothing is recorded on failure.
  Future<ReceivedShareError?> add({
    required String sharerWebId,
    required String label,
    required String? code,
    required DateTime today,
  }) async {
    final share = ReceivedShare(
      sharerWebId: sharerWebId.trim(),
      label: label.trim(),
      addedOn: today,
      code: (code ?? '').trim().isEmpty ? null : code!.trim(),
    );
    final view = await _fetch(share);
    if (view is SharedViewFailed) return view.error;
    _views[share.sharerWebId] = view;
    await _health.apply((d) => d.withReceived(share));
    if (_invite?.sharerWebId == share.sharerWebId) await clearInvite();
    return null;
  }

  /// Takes a new code for [share], as after a re-share: proves it opens the
  /// copy, then records it. Null on success, else why not; nothing changes
  /// on failure.
  Future<ReceivedShareError?> changeCode(
    ReceivedShare share,
    String? code,
  ) async {
    final updated = share.withCode(
      (code ?? '').trim().isEmpty ? null : code!.trim(),
    );
    final view = await _fetch(updated);
    if (view is SharedViewFailed) return view.error;
    _views[share.sharerWebId] = view;
    await _health.apply((d) => d.withReceived(updated));
    return null;
  }

  Future<void> refresh(ReceivedShare share) async {
    _views[share.sharerWebId] = const SharedViewLoading();
    notifyListeners();
    _views[share.sharerWebId] = await _fetch(share);
    notifyListeners();
  }

  /// Fetches every share again, one after another.
  Future<void> refreshAll() async {
    for (final share in received) {
      await refresh(share);
    }
  }

  /// Fetches the shares not looked at yet, so a list can show their state.
  Future<void> refreshUnseen() async {
    for (final share in received) {
      if (!_views.containsKey(share.sharerWebId)) await refresh(share);
    }
  }

  Future<void> remove(ReceivedShare share) async {
    _views.remove(share.sharerWebId);
    await _health.apply((d) => d.withoutReceived(share.sharerWebId));
  }

  Future<SharedView> _fetch(ReceivedShare share) async {
    try {
      final root = await _reader.podRootOf(share.sharerWebId);
      final url = SharePlan.forRecipient(ownWebId).documentUrl(root);
      final content = await _reader.readDocument(url);
      return SharedViewReady(codec.decode(_open(content, share.code)));
    } on PodNotLoggedInException {
      return const SharedViewFailed(ReceivedShareError.notLoggedIn);
    } on PodAccessException {
      return const SharedViewFailed(ReceivedShareError.ended);
    } on PodUnavailableException catch (e) {
      return SharedViewFailed(
        ReceivedShareError.unreachable,
        detail: e.message,
      );
    } on PodException catch (e) {
      return SharedViewFailed(
        ReceivedShareError.unreachable,
        detail: e.message,
      );
    } on _NeedsCode {
      return const SharedViewFailed(ReceivedShareError.needsCode);
    } on ShareUndecryptableException {
      return const SharedViewFailed(ReceivedShareError.wrongCode);
    } on MalformedDocumentException catch (e) {
      return SharedViewFailed(ReceivedShareError.malformed, detail: '$e');
    } on UnsupportedDocumentVersionException catch (e) {
      return SharedViewFailed(ReceivedShareError.malformed, detail: '$e');
    }
  }

  /// Plain JSON as it is; a JWE through the code.
  String _open(String content, String? code) {
    if (!isEnvelope(content)) return content;
    final key = code == null ? null : ShareKey.fromCode(code);
    if (key == null) throw const _NeedsCode();
    return cipher.decrypt(content, key);
  }

  /// A compact JWE has five dot-separated parts and no braces.
  static bool isEnvelope(String content) {
    final text = content.trim();
    return !text.startsWith('{') && text.split('.').length == 5;
  }

  @override
  void dispose() {
    _health.removeListener(notifyListeners);
    super.dispose();
  }
}

class _NeedsCode implements Exception {
  const _NeedsCode();
}
