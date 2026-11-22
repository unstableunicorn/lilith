import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/share_reader.dart';

/// Other people's pods: a root per WebID and a document per URL.
class FakeShareReader implements ShareReader {
  final Map<String, Uri> roots = {};
  final Map<Uri, String> documents = {};
  PodException? failRead;
  int reads = 0;

  @override
  Future<Uri> podRootOf(String webId) async =>
      roots[webId] ?? Uri.parse(webId).resolve('../');

  @override
  Future<String> readDocument(Uri url) async {
    reads++;
    if (failRead case final e?) throw e;
    return documents[url] ??
        (throw PodAccessException('$url is missing or refused'));
  }
}
