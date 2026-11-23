import 'dart:async';

import 'package:lilith/domain/export_file.dart';

/// Records the files a screen asked to share. [hold] keeps the share pending
/// until [release]; [failWith] makes it throw.
class RecordingFileSharer {
  final List<ExportFile> shared = [];
  bool hold = false;
  Exception? failWith;
  Completer<void>? _pending;

  Future<void> call(ExportFile file) async {
    if (failWith case final e?) throw e;
    shared.add(file);
    if (hold) await (_pending ??= Completer<void>()).future;
  }

  void release() {
    _pending?.complete();
    _pending = null;
  }
}
