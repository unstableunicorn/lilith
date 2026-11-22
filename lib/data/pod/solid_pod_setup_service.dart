// PodSetupService on a real Solid pod through solidpod.

import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_setup_service.dart';
import 'package:lilith/data/pod/solid_pod_service.dart';
import 'package:lilith/domain/data_protection.dart';
import 'package:solidpod/solidpod.dart' as solid;

class SolidPodSetupService implements PodSetupService {
  const SolidPodSetupService();

  @override
  Future<PodInspection> inspect() async {
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

  @override
  Future<void> setUpEncryption(String securityKey) async {
    try {
      await solid.initPod(securityKey);
    } catch (e) {
      throw toPodException(e);
    }
  }

  @override
  Future<void> setUpPlain() async {
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
    try {
      await solid.KeyManager.setSecurityKey(securityKey);
    } on solid.SecurityKeyVerificationException {
      throw const PodWrongKeyException();
    } catch (e) {
      throw toPodException(e);
    }
  }

  @override
  Future<void> forgetKey() => solid.KeyManager.forgetSecurityKey();
}
