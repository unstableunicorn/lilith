// The pod operations a share needs, beyond reading and writing documents.

import 'package:lilith/data/pod/share_plan.dart';

abstract interface class ShareService {
  /// Creates the share's folder and then its access rule, in that order, so
  /// nothing is ever readable before its final rule.
  Future<void> open(SharePlan plan);

  /// Creates or replaces the share copy. [content] is plain JSON or a JWE
  /// envelope; the pod stores it as it is.
  Future<void> write(SharePlan plan, String content);

  /// Ends the share: the access rule goes first, then the copy, then the
  /// folder. Each step that finds nothing counts as done, so an interrupted
  /// close can be retried.
  Future<void> close(SharePlan plan);
}
