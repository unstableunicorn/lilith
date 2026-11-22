import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/pod/share_service.dart';

/// An in-memory record of share folders: which are open and what each holds.
class FakeShareService implements ShareService {
  /// Folder path to its copy, or null while the folder is open but empty.
  final Map<String, String?> folders = {};

  /// Every call, in order: `open <id>`, `write <id>`, `close <id>`.
  final List<String> calls = [];

  PodException? failOpen;
  PodException? failWrite;
  PodException? failClose;

  @override
  Future<void> open(SharePlan plan) async {
    calls.add('open ${plan.folderPath}');
    if (failOpen case final e?) throw e;
    folders.putIfAbsent(plan.folderPath, () => null);
  }

  @override
  Future<void> write(SharePlan plan, String content) async {
    calls.add('write ${plan.folderPath}');
    if (failWrite case final e?) throw e;
    if (!folders.containsKey(plan.folderPath)) {
      throw const PodAccessException('folder not open');
    }
    folders[plan.folderPath] = content;
  }

  @override
  Future<void> close(SharePlan plan) async {
    calls.add('close ${plan.folderPath}');
    if (failClose case final e?) throw e;
    folders.remove(plan.folderPath);
  }
}
