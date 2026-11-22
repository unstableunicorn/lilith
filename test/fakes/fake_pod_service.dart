import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/domain/pod_provider.dart';

/// An in-memory pod. Flip [failReads] or [failWrites] to make it misbehave.
class FakePodService implements PodService {
  FakePodService({PodProvider? provider, Map<String, String>? documents})
    : provider = provider ?? PodProvider.solidCommunityAu,
      documents = {...?documents};

  @override
  final PodProvider provider;

  final Map<String, String> documents;

  PodException? failReads;
  PodException? failWrites;
  int reads = 0;
  int writes = 0;

  @override
  Future<String?> read(String path) async {
    reads++;
    if (failReads case final e?) throw e;
    return documents[path];
  }

  @override
  Future<void> write(String path, String content) async {
    writes++;
    if (failWrites case final e?) throw e;
    documents[path] = content;
  }
}
