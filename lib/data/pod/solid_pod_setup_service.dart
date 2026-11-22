// PodSetupService on a real Solid pod through solidpod.

import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_setup_plan.dart';
import 'package:lilith/data/pod/pod_setup_service.dart';
import 'package:lilith/data/pod/solid_pod_service.dart';
import 'package:lilith/data/pod/solid_pod_session_service.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:solidpod/solidpod.dart' as solid;

class SolidPodSetupService implements PodSetupService {
  const SolidPodSetupService();

  @override
  Future<PodInspection> inspect() async {
    await solidPodReady;
    try {
      final dataDir = await solid.getDataDirPath();
      final plainUrl = await solid.getFileUrl(
        '$dataDir/${DataProtection.plain.documentPath}',
      );
      final encKeyUrl = await solid.getFileUrl(await solid.getEncKeyPath());
      final plainExists =
          await solid.checkResourceStatus(plainUrl) ==
          solid.ResourceStatus.exist;
      final keysOnPod =
          await solid.checkResourceStatus(encKeyUrl) ==
          solid.ResourceStatus.exist;
      return PodInspection(
        plainDocumentExists: plainExists,
        keysOnPod: keysOnPod,
        keyOnDevice: keysOnPod && await solid.KeyManager.hasSecurityKey(),
      );
    } catch (e) {
      throw toPodException(e);
    }
  }

  /// solidpod creates the folders and key files; the rules it would open to
  /// anyone are written here for logged-in users instead, so no public rule
  /// exists at any moment. See PodSetupPlan.
  @override
  Future<void> setUpEncryption(String securityKey) async {
    await solidPodReady;
    try {
      final plan = PodSetupPlan.from(await solid.generateDefaultFiles());
      await solid.initPod(
        securityKey,
        fileUrls: [
          for (final f in plan.filesForInitPod) await solid.getFileUrl(f),
        ],
      );
      for (final acl in plan.acls) {
        final resourceUrl = acl.isFile
            ? await solid.getFileUrl(acl.resourcePath)
            : await solid.getDirUrl(acl.resourcePath);
        final aclUrl = acl.isFile ? '$resourceUrl.acl' : '$resourceUrl.acl';
        await solid.createResource(
          aclUrl,
          content: await solid.genAclTurtle(
            resourceUrl,
            isFile: acl.isFile,
            authUserAccess: {for (final m in acl.modes) _accessMode(m)},
          ),
        );
      }
    } catch (e) {
      throw toPodException(e);
    }
  }

  solid.AccessMode _accessMode(AclMode mode) => switch (mode) {
    AclMode.read => solid.AccessMode.read,
    AclMode.write => solid.AccessMode.write,
    AclMode.append => solid.AccessMode.append,
  };

  @override
  Future<void> setUpPlain() async {
    await solidPodReady;
    try {
      for (final dir in await solid.generateDefaultFolders()) {
        final url = await solid.getDirUrl(dir);
        if (await solid.checkResourceStatus(url, isFile: false) !=
            solid.ResourceStatus.exist) {
          await solid.createDir(url);
        }
      }
      await solid.writePod(
        DataProtection.plain.documentPath,
        '{}',
        encrypted: false,
      );
    } catch (e) {
      throw toPodException(e);
    }
  }

  @override
  Future<void> unlock(String securityKey) async {
    await solidPodReady;
    try {
      await solid.KeyManager.setSecurityKey(securityKey);
    } on solid.SecurityKeyVerificationException {
      throw const PodWrongKeyException();
    } catch (e) {
      throw toPodException(e);
    }
  }

  @override
  Future<void> forgetKey() async {
    await solidPodReady;
    await solid.KeyManager.forgetSecurityKey();
  }
}
