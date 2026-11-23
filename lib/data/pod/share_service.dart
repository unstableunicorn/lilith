// The pod operations a share needs, beyond reading and writing documents.

import 'dart:typed_data';

import 'package:lilith/data/pod/share_plan.dart';

abstract interface class ShareService {
  /// Creates the share's folder and then its access rule, in that order, so
  /// nothing is ever readable before its final rule.
  Future<void> open(SharePlan plan);

  /// Creates or replaces the share copy. [content] is plain JSON or a JWE
  /// envelope; the pod stores it as it is.
  Future<void> write(SharePlan plan, String content);

  /// Creates or replaces a file in the share's folder, typed by its name.
  Future<void> writeFile(SharePlan plan, String name, Uint8List bytes);

  /// Where the share's folder is, to pass on to a recipient without the app.
  Future<Uri> folderUrl(SharePlan plan);

  /// Ends the share: the access rule goes first, then every file, then the
  /// folder. Each step that finds nothing counts as done, so an interrupted
  /// close can be retried.
  Future<void> close(SharePlan plan);
}
