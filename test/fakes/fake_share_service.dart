import 'dart:typed_data';

import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/pod/share_service.dart';

/// An in-memory record of share folders: which are open and what each holds.
class FakeShareService implements ShareService {
  /// Folder path to its copy, or null while the folder is open but empty.
  final Map<String, String?> folders = {};

  /// Files written by name: folder path to name to bytes.
  final Map<String, Map<String, Uint8List>> files = {};

  /// Every call, in order: `open <id>`, `write <id>`, `file <id> <name>`,
  /// `close <id>`.
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
  Future<void> writeFile(SharePlan plan, String name, Uint8List bytes) async {
    calls.add('file ${plan.folderPath} $name');
    if (failWrite case final e?) throw e;
    if (!folders.containsKey(plan.folderPath)) {
      throw const PodAccessException('folder not open');
    }
    files.putIfAbsent(plan.folderPath, () => {})[name] = bytes;
  }

  @override
  Future<Uri> folderUrl(SharePlan plan) async =>
      Uri.parse('https://pod.example/me/lilith/data/${plan.folderPath}/');

  @override
  Future<void> close(SharePlan plan) async {
    calls.add('close ${plan.folderPath}');
    if (failClose case final e?) throw e;
    folders.remove(plan.folderPath);
    files.remove(plan.folderPath);
  }
}
