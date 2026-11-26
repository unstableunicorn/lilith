// What the "shared with you" screen decides: whether the form can be sent,
// what is wrong with it, and how a failed add is explained.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/received_share_repository.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/share/share_view_model.dart';

class ReceivedViewModel extends ChangeNotifier {
  ReceivedViewModel(
    this._repo, {
    required this.ownWebId,
    required this.now,
    ShareInvite? prefill,
  }) : _webId = prefill?.sharerWebId ?? '',
       _code = prefill?.code ?? '' {
    _repo.addListener(notifyListeners);
  }

  final ReceivedShareRepository _repo;
  final String ownWebId;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  String _label = '';
  String _webId;
  String _code;
  bool _busy = false;
  ReceivedShareError? _error;

  List<ReceivedShare> get received => _repo.received;
  String get label => _label;
  String get webId => _webId;
  String get code => _code;
  bool get isBusy => _busy;

  /// Why the last add failed, until the form changes.
  ReceivedShareError? get error => _error;

  WebIdProblem? get webIdProblem {
    final text = _webId.trim();
    if (text.isEmpty) return WebIdProblem.empty;
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return WebIdProblem.notALink;
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      return WebIdProblem.notALink;
    }
    if (text == ownWebId.trim()) return WebIdProblem.yourOwn;
    return null;
  }

  bool get canAdd => _label.trim().isNotEmpty && webIdProblem == null && !_busy;

  void setLabel(String text) => _edit(() => _label = text);
  void setWebId(String text) => _edit(() => _webId = text);
  void setCode(String text) => _edit(() => _code = text);

  /// True when the add succeeded; the form is then cleared.
  Future<bool> add() async {
    if (!canAdd) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    final error = await _repo.add(
      sharerWebId: _webId,
      label: _label,
      code: _code,
      today: now(),
    );
    _busy = false;
    _error = error;
    if (error == null) {
      _label = '';
      _webId = '';
      _code = '';
    }
    notifyListeners();
    return error == null;
  }

  Future<void> remove(ReceivedShare share) => _repo.remove(share);

  String? _editingCodeFor;
  String _newCode = '';
  ReceivedShareError? _codeError;

  /// The sharer whose code is being changed, if any.
  bool isEditingCode(ReceivedShare share) =>
      _editingCodeFor == share.sharerWebId;
  String get newCode => _newCode;

  /// Why the last code change failed, until the field changes.
  ReceivedShareError? get codeError => _codeError;
  bool get canSaveCode => _newCode.trim().isNotEmpty && !_busy;

  void startChangingCode(ReceivedShare share) => _edit(() {
    _editingCodeFor = share.sharerWebId;
    _newCode = '';
    _codeError = null;
  });

  void cancelChangingCode() => _edit(() {
    _editingCodeFor = null;
    _newCode = '';
    _codeError = null;
  });

  void setNewCode(String text) => _edit(() {
    _newCode = text;
    _codeError = null;
  });

  /// True when the new code opened the share and was saved.
  Future<bool> saveCode(ReceivedShare share) async {
    if (!canSaveCode) return false;
    _busy = true;
    notifyListeners();
    final error = await _repo.changeCode(share, _newCode);
    _busy = false;
    _codeError = error;
    if (error == null) {
      _editingCodeFor = null;
      _newCode = '';
    }
    notifyListeners();
    return error == null;
  }

  /// Fetches every share again, for a pull down on the list.
  Future<void> refreshAll() => _repo.refreshAll();

  /// Looks at the shares not fetched yet, when the list opens.
  Future<void> refreshUnseen() => _repo.refreshUnseen();

  /// "Up to date", "Ended", "Could not fetch", or "Checking…" while unknown.
  String stateText(ReceivedShare share) => switch (_repo.viewOf(share)) {
    SharedViewLoading() => 'Checking…',
    SharedViewReady() || SharedViewPhases() => 'Up to date',
    SharedViewFailed(error: ReceivedShareError.ended) => 'Ended',
    SharedViewFailed() => 'Could not fetch',
  };

  /// True when the share can no longer be read, so the card can say so.
  bool hasEnded(ReceivedShare share) => switch (_repo.viewOf(share)) {
    SharedViewFailed(error: ReceivedShareError.ended) => true,
    _ => false,
  };

  void _edit(void Function() change) {
    change();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}

/// "Nobody is sharing with you", "Elric shares with you", "3 people share
/// with you".
String receivedSummary(List<ReceivedShare> received) =>
    switch (received.length) {
      0 => 'Nobody is sharing with you',
      1 => '${received.single.label} shares with you',
      final n => '$n people share with you',
    };

/// Why an add failed, for the user.
String describeReceivedError(ReceivedShareError error) => switch (error) {
  ReceivedShareError.ended =>
    'Nothing is shared with you there. Check the WebID, and that they have '
        'shared with your WebID.',
  ReceivedShareError.needsCode =>
    'This share is encrypted. Enter the code they gave you.',
  ReceivedShareError.wrongCode => 'That code does not open this share.',
  ReceivedShareError.malformed => 'The share could not be read.',
  ReceivedShareError.unreachable => 'Their pod could not be reached.',
  ReceivedShareError.notLoggedIn => 'You are logged out. Log in and try again.',
};
