// PodSetupService on a real Solid pod through solidpod.

import 'dart:convert';

import 'package:lilith/data/pod/key_change.dart';
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

  /// solidpod creates the folders and key files. The rules it would write
  /// for others are left out, so everything keeps the owner-only rule of its
  /// folder. See PodSetupPlan.
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
    } catch (e) {
      throw toPodException(e);
    }
  }

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

  /// solidpod writes enc-keys.ttl, then ind-keys.ttl; a failure between the
  /// two leaves neither key working, so both are copied first. After a
  /// failure solidpod's cached keys are dropped and reloaded from the pod.
  @override
  Future<void> changeKey(String currentKey, String newKey) async {
    await solidPodReady;
    final encPath = await solid.getEncKeyPath();
    final indPath =
        '${encPath.substring(0, encPath.lastIndexOf('/') + 1)}'
        '${solid.SolidConstants.files.individualKeys}';
    await changeWithBackup(
      store: const _SolidKeyFiles(),
      urls: [await solid.getFileUrl(encPath), await solid.getFileUrl(indPath)],
      change: () async {
        try {
          await solid.KeyManager.changeSecurityKey(currentKey, newKey);
        } on solid.SecurityKeyVerificationException {
          throw const PodWrongKeyException();
        }
      },
      afterFailure: () => solid.KeyManager.clear(keepStoredSecurityKey: true),
    );
  }
}

class _SolidKeyFiles implements KeyFileStore {
  const _SolidKeyFiles();

  @override
  Future<String> read(String url) async {
    try {
      return utf8.decode(await solid.getResource(url));
    } catch (e) {
      throw toPodException(e);
    }
  }

  @override
  Future<void> write(String url, String content) =>
      solid.createResource(url, content: content);
}
