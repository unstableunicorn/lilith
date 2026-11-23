// How a user's document is protected on their pod, and what set-up it needs.

import 'package:meta/meta.dart';

/// Encrypted on the device with the user's security key, or plain behind the
/// pod's access control. Each mode keeps its own document, so the mode in use
/// can be read off the pod.
enum DataProtection {
  encrypted('cycle_data.ttl'),
  plain('cycle_data.json');

  DataProtection(this.documentPath);

  /// The document in the app's data folder. solidpod encrypts only `.ttl`.
  final String documentPath;

  static const DataProtection recommended = DataProtection.encrypted;
}

/// What a look at the pod and this device found.
class PodInspection {
  const PodInspection({
    required this.plainDocumentExists,
    required this.keysOnPod,
    required this.keyOnDevice,
  });

  final bool plainDocumentExists;

  /// solidpod's key files exist on the pod: encryption was set up once.
  final bool keysOnPod;

  /// A security key is stored on this device and verified against the pod.
  final bool keyOnDevice;
}

/// Where set-up stands, as the app shows it.
@immutable
sealed class SetupState {
  const SetupState();

  const factory SetupState.unknown() = SetupUnknown;
  const factory SetupState.choose() = SetupChoose;
  const factory SetupState.enterKey() = SetupEnterKey;
  const factory SetupState.ready(DataProtection protection) = SetupReady;

  @override
  bool operator ==(Object other) => other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Not looked yet.
class SetupUnknown extends SetupState {
  const SetupUnknown();
}

/// First use on this pod: the user picks a [DataProtection].
class SetupChoose extends SetupState {
  const SetupChoose();
}

/// Encrypted on another device: the user enters the security key.
class SetupEnterKey extends SetupState {
  const SetupEnterKey();
}

@immutable
class SetupReady extends SetupState {
  const SetupReady(this.protection);
  final DataProtection protection;

  @override
  bool operator ==(Object other) =>
      other is SetupReady && other.protection == protection;

  @override
  int get hashCode => Object.hash(runtimeType, protection);
}

/// The set-up state a [PodInspection] implies. A device key without keys on
/// the pod is stale and ignored.
SetupState setupStateFor(PodInspection seen) {
  if (seen.plainDocumentExists) {
    return const SetupState.ready(DataProtection.plain);
  }
  if (!seen.keysOnPod) return const SetupState.choose();
  return seen.keyOnDevice
      ? const SetupState.ready(DataProtection.encrypted)
      : const SetupState.enterKey();
}
