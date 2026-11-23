// ShareService on a real Solid pod through solidpod's resource functions.

import 'dart:typed_data';

import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_plan.dart';
import 'package:lilith/data/pod/share_service.dart';
import 'package:lilith/data/pod/solid_pod_service.dart';
import 'package:lilith/data/pod/solid_pod_session_service.dart';
import 'package:solidpod/solidpod.dart' as solid;

class SolidShareService implements ShareService {
  const SolidShareService();

  @override
  Future<void> open(SharePlan plan) async {
    await solidPodReady;
    try {
      final webId = await solid.AuthDataManager.getWebId();
      if (webId == null) throw const PodNotLoggedInException();
      // solidpod makes a folder by POSTing to its parent, and CSS answers
      // 404 when the parent is missing, so shares/ comes first.
      await _ensureDir(await _sharesUrl());
      final folderUrl = await _folderUrl(plan);
      await _ensureDir(folderUrl);
      await solid.createResource(
        '$folderUrl.acl',
        content: await plan.aclTurtle(ownerWebId: webId, folderUrl: folderUrl),
      );
    } on PodException {
      rethrow;
    } catch (e) {
      throw toPodException(e);
    }
  }

  /// No ACL of its own for the copy: solidpod would write an owner-only one,
  /// which replaces the folder's rule and shuts the recipient out.
  @override
  Future<void> write(SharePlan plan, String content) async {
    await solidPodReady;
    try {
      await solid.writePod(
        plan.documentPath,
        content,
        encrypted: false,
        createAcl: false,
        overwrite: true,
      );
    } catch (e) {
      throw toPodException(e);
    }
  }

  @override
  Future<void> writeFile(SharePlan plan, String name, Uint8List bytes) async {
    await solidPodReady;
    try {
      await solid.createResource(
        '${await _folderUrl(plan)}$name',
        content: bytes,
        contentType: solid.ResourceContentType.auto,
      );
    } catch (e) {
      throw toPodException(e);
    }
  }

  @override
  Future<Uri> folderUrl(SharePlan plan) async {
    await solidPodReady;
    return Uri.parse(await _folderUrl(plan));
  }

  @override
  Future<void> close(SharePlan plan) async {
    await solidPodReady;
    try {
      final folderUrl = await _folderUrl(plan);
      await _deleteIfExists('$folderUrl.acl', solid.ResourceContentType.any);
      for (final name in SharePlan.fileNames) {
        await _deleteIfExists('$folderUrl$name', solid.ResourceContentType.any);
      }
      await _deleteIfExists(folderUrl, solid.ResourceContentType.directory);
    } catch (e) {
      throw toPodException(e);
    }
  }

  Future<String> _folderUrl(SharePlan plan) async => await solid.getDirUrl(
    '${await solid.getDataDirPath()}/${plan.folderPath}',
  );

  Future<String> _sharesUrl() async => await solid.getDirUrl(
    '${await solid.getDataDirPath()}/${SharePlan.sharesFolder}',
  );

  Future<void> _ensureDir(String url) async {
    if (await solid.checkResourceStatus(url, isFile: false) !=
        solid.ResourceStatus.exist) {
      await solid.createDir(url);
    }
  }

  Future<void> _deleteIfExists(
    String url,
    solid.ResourceContentType type,
  ) async {
    final isFile = type != solid.ResourceContentType.directory;
    if (await solid.checkResourceStatus(url, isFile: isFile) ==
        solid.ResourceStatus.exist) {
      await solid.deleteResource(url, type);
    }
  }
}
