// ShareReader on a real Solid pod through solidpod's resource functions.

import 'dart:convert';

import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_reader.dart';
import 'package:lilith/data/pod/solid_pod_service.dart';
import 'package:lilith/data/pod/solid_pod_session_service.dart';
import 'package:solidpod/solidpod.dart' as solid;

class SolidShareReader implements ShareReader {
  const SolidShareReader();

  static const String _storage = 'http://www.w3.org/ns/pim/space#storage';

  @override
  Future<Uri> podRootOf(String webId) async {
    await solidPodReady;
    final card = Uri.parse(webId).removeFragment();
    String? storage;
    try {
      final triples = solid.turtleToTripleMap(
        utf8.decode(await solid.getResource(card.toString())),
      );
      storage = switch (triples[webId]?[_storage]) {
        final String s => s,
        final List l when l.isNotEmpty => l.first as String,
        _ => null,
      };
    } catch (_) {
      // A card that cannot be read or parsed: fall back to the WebID's shape.
    }
    return podRootFor(webId, storage: storage);
  }

  @override
  Future<String> readDocument(Uri url) async {
    await solidPodReady;
    try {
      return await solid.readPod(
        url.toString(),
        pathType: solid.PathType.absoluteUrl,
      );
    } on solid.ResourceNotExistException catch (e) {
      throw PodAccessException(e.toString());
    } catch (e) {
      throw toPodException(e);
    }
  }
}

/// [storage] when the card gives one; else the WebID with its `profile/card`
/// document and fragment removed, which is where CSS and most servers keep
/// the pod.
Uri podRootFor(String webId, {String? storage}) {
  if (storage != null) {
    final root = Uri.parse(storage);
    return root.path.endsWith('/') ? root : root.replace(path: '${root.path}/');
  }
  final uri = Uri.parse(webId).removeFragment();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segments.length >= 2 && segments[segments.length - 2] == 'profile') {
    segments.removeRange(segments.length - 2, segments.length);
  } else if (segments.isNotEmpty) {
    segments.removeLast();
  }
  return uri.replace(
    path: '/${segments.map((s) => '$s/').join()}',
    query: null,
  );
}
