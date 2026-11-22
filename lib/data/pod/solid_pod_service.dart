// PodService on a real Solid pod through the solidpod package.
// The only file that imports solidpod for data access.

import 'dart:io';

import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/pod_provider.dart';
import 'package:solidpod/solidpod.dart' as solid;

class SolidPodService implements PodService {
  SolidPodService({required this.provider});

  @override
  final PodProvider provider;

  @override
  Future<String?> read(String path) async {
    try {
      return await solid.readPod(path);
    } on solid.ResourceNotExistException {
      return null;
    } catch (e) {
      throw toPodException(e);
    }
  }

  @override
  Future<void> write(String path, String content) async {
    try {
      await solid.writePod(path, content, encrypted: true, overwrite: true);
    } catch (e) {
      throw toPodException(e);
    }
  }
}

/// The [PodException] for a failure raised by solidpod or the network.
PodException toPodException(Object error) => switch (error) {
  solid.NotLoggedInException() => const PodNotLoggedInException(),
  solid.AccessForbiddenException(:final message) ||
  solid.AccessFailedException(:final message) ||
  solid.ResourceNotDecryptableException(
    :final message,
  ) => PodAccessException(message),
  SocketException(:final message) ||
  HttpException(:final message) => PodUnavailableException(message),
  _ => PodUnavailableException(error.toString()),
};
