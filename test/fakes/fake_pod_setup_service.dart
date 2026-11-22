import 'package:lilith/data/pod/pod_service.dart';
import 'package:lilith/data/pod/pod_setup_service.dart';
import 'package:lilith/domain/data_protection.dart';

/// A pod whose set-up state a test controls.
class FakePodSetupService implements PodSetupService {
  PodInspection inspection = const PodInspection(
    plainDocumentExists: false,
    keysOnPod: false,
    keyOnDevice: false,
  );
  String? podKey;
  PodException? failInspect;
  PodException? failSetUp;
  int inspections = 0;

  @override
  Future<PodInspection> inspect() async {
    inspections++;
    if (failInspect case final e?) throw e;
    return inspection;
  }

  @override
  Future<void> setUpEncryption(String securityKey) async {
    if (failSetUp case final e?) throw e;
    podKey = securityKey;
    inspection = const PodInspection(
      plainDocumentExists: false,
      keysOnPod: true,
      keyOnDevice: true,
    );
  }

  @override
  Future<void> setUpPlain() async {
    if (failSetUp case final e?) throw e;
    inspection = const PodInspection(
      plainDocumentExists: true,
      keysOnPod: false,
      keyOnDevice: false,
    );
  }

  @override
  Future<void> unlock(String securityKey) async {
    if (securityKey != podKey) throw const PodWrongKeyException();
    inspection = const PodInspection(
      plainDocumentExists: false,
      keysOnPod: true,
      keyOnDevice: true,
    );
  }

  @override
  Future<void> forgetKey() async {
    inspection = PodInspection(
      plainDocumentExists: inspection.plainDocumentExists,
      keysOnPod: inspection.keysOnPod,
      keyOnDevice: false,
    );
  }
}
