// The one source of truth for the user's health data while the app runs.
//
// Holds a HealthData value, loads it from the pod document once, and writes
// the whole document back after every change. Screens listen for changes.

import 'package:flutter/foundation.dart';
import 'package:lilith/data/pod/health_document_codec.dart';
import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:lilith/domain/health_data.dart';

/// What last went wrong, for the UI to phrase.
enum RepositoryError {
  notLoggedIn,
  loadFailed,
  malformed,
  newerVersion,
  saveFailed,

  /// A change was attempted before a load succeeded.
  notLoaded,
}

class HealthRepository extends ChangeNotifier {
  HealthRepository(
    this._pod, {
    required this.protection,
    HealthDocumentCodec? codec,
  }) : _codec = codec ?? const HealthDocumentCodec();

  /// How the document is stored; it decides the document's path and whether
  /// writes are encrypted.
  final DataProtection protection;

  final PodService _pod;
  final HealthDocumentCodec _codec;

  String get documentPath => protection.documentPath;

  HealthData _data = HealthData.empty;
  bool _loaded = false;
  bool _isLoading = false;
  Future<void>? _inFlight;
  RepositoryError? _error;

  HealthData get data => _data;
  bool get isLoaded => _loaded;
  bool get isLoading => _isLoading;
  RepositoryError? get error => _error;

  /// Reads the document. A missing document is an empty one. Does nothing
  /// once loaded unless [force]; concurrent calls share one read.
  Future<void> load({bool force = false}) {
    if (_inFlight case final inFlight?) return inFlight;
    if (_loaded && !force) return Future.value();
    _isLoading = true;
    _error = null;
    notifyListeners();
    return _inFlight = _load().whenComplete(() {
      _isLoading = false;
      _inFlight = null;
      notifyListeners();
    });
  }

  Future<void> _load() async {
    try {
      final content = await _pod.read(documentPath);
      _data = content == null ? HealthData.empty : _codec.decode(content);
      _loaded = true;
    } on PodNotLoggedInException {
      _error = RepositoryError.notLoggedIn;
    } on PodException {
      _error = RepositoryError.loadFailed;
    } on MalformedDocumentException {
      _error = RepositoryError.malformed;
    } on UnsupportedDocumentVersionException {
      _error = RepositoryError.newerVersion;
    }
  }

  /// Applies [change] to the data and writes the document back. On a failed
  /// write the change is kept in memory and [error] says so.
  Future<void> apply(HealthData Function(HealthData data) change) async {
    if (!_loaded) {
      _error = RepositoryError.notLoaded;
      notifyListeners();
      return;
    }
    final next = change(_data);
    if (next == _data) return;
    _data = next;
    _error = null;
    notifyListeners();
    try {
      await _pod.write(
        documentPath,
        _codec.encode(next),
        encrypted: protection == DataProtection.encrypted,
      );
    } on PodNotLoggedInException {
      _error = RepositoryError.notLoggedIn;
    } on PodException {
      _error = RepositoryError.saveFailed;
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
