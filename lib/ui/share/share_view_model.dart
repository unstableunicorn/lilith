// What the sharing screen decides: whether the form can be sent, what is
// wrong with it, how each share's end is described, and the code to show.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/pod/solid_client.dart';
import 'package:lilith/data/share_repository.dart';
import 'package:lilith/domain/export_rows.dart';
import 'package:lilith/domain/share.dart';
import 'package:lilith/ui/core/dates.dart';

enum WebIdProblem { empty, notALink, yourOwn }

class ShareViewModel extends ChangeNotifier {
  ShareViewModel(this._repo, {required this.ownWebId, required this.now}) {
    _repo.addListener(notifyListeners);
  }

  final ShareRepository _repo;
  final String ownWebId;

  /// The clock, injected so tests pick the day.
  final DateTime Function() now;

  String _label = '';
  String _webId = '';
  ShareDuration _duration = ShareDuration.recommended;
  ShareContent _content = ShareContent.cycleData;
  ExportRange _range = ExportRange.sixMonths;
  Share? _created;
  Uri? _createdLink;
  final Set<String> _revealed = {};

  List<Share> get shares => _repo.shares;
  bool get isBusy => _repo.isBusy;
  ShareError? get error => _repo.error;
  String? get errorDetail => _repo.errorDetail;
  String get label => _label;
  String get webId => _webId;
  ShareDuration get duration => _duration;
  ShareContent get content => _content;

  /// How far back a report reaches; only asked for a report.
  ExportRange get range => _range;

  /// The share just made, with its code to pass on, until dismissed.
  Share? get created => _created;

  /// Where the just-made report lives, for a recipient without the app.
  Uri? get createdLink => _createdLink;

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

  bool get canShare =>
      _label.trim().isNotEmpty && webIdProblem == null && !isBusy;

  void setLabel(String text) => _edit(() => _label = text);
  void setWebId(String text) => _edit(() => _webId = text);
  void setDuration(ShareDuration d) => _edit(() => _duration = d);
  void setContent(ShareContent c) => _edit(() => _content = c);
  void setRange(ExportRange r) => _edit(() => _range = r);

  Future<void> share() async {
    if (!canShare) return;
    final share = await _repo.create(
      recipientWebId: _webId,
      label: _label,
      duration: _duration,
      today: now(),
      content: _content,
      range: _range,
    );
    if (share == null) return;
    _created = share;
    _createdLink = share.isReport ? await _repo.folderUrl(share) : null;
    _label = '';
    _webId = '';
    _duration = ShareDuration.recommended;
    _content = ShareContent.cycleData;
    _range = ExportRange.sixMonths;
    notifyListeners();
  }

  void dismissCreated() => _edit(() {
    _created = null;
    _createdLink = null;
  });

  /// Where a report share's folder is, to copy for the recipient.
  Future<Uri> folderUrl(Share share) => _repo.folderUrl(share);

  Future<void> revoke(Share share) => _repo.revoke(share);

  /// The link that adds this share in the recipient's app: the sharer's
  /// WebID and, for an encrypted copy, the code.
  Uri inviteLink(Share share) => ShareInvite(
    sharerWebId: ownWebId,
    code: share.code,
  ).toUri(Uri.parse(SolidClient.webOrigin));

  /// Whether the share's code and QR code are shown in the list.
  bool isRevealed(Share share) => _revealed.contains(share.id);

  void toggleRevealed(Share share) => _edit(() {
    if (!_revealed.remove(share.id)) _revealed.add(share.id);
  });

  void clearError() => _repo.clearError();

  void _edit(void Function() change) {
    change();
    notifyListeners();
  }

  @override
  void dispose() {
    _repo.removeListener(notifyListeners);
    super.dispose();
  }
}

/// "Until Sun 31 May 2026", "Ended on …" once past, or "Until you end it".
String shareEndText(Share share, {required DateTime today}) {
  final end = share.expiresOn;
  if (end == null) return 'Until you end it';
  return share.isExpired(today)
      ? 'Ended on ${formatDay(end)}'
      : 'Until ${formatDay(end)}';
}

/// "Not shared with anyone", "Shared with Alex", "Shared with 3 people".
String sharingSummary(List<Share> shares) => switch (shares.length) {
  0 => 'Not shared with anyone',
  1 => 'Shared with ${shares.single.label}',
  final n => 'Shared with $n people',
};

/// "The app view", "PDF report and CSV, last 6 months".
String shareContentText(Share share) => switch (share.range) {
  final r? => '${share.content.label}, ${r.label.toLowerCase()}',
  null => share.content.label,
};
