// Where a share lives on the sharer's pod and the one access rule it gets.
// Everything else in the pod keeps its owner-only rule (see PodSetupPlan).

import 'package:lilith/data/pod/solid_client.dart';
import 'package:lilith/domain/share.dart';
import 'package:solidpod/solidpod.dart' as solid;

class SharePlan {
  const SharePlan._({required this.recipientWebId, required this.folderPath});

  factory SharePlan.forRecipient(String recipientWebId) => SharePlan._(
    recipientWebId: recipientWebId.trim(),
    folderPath: 'shares/${shareId(recipientWebId)}',
  );

  final String recipientWebId;

  /// The share's folder, relative to the app's data folder.
  final String folderPath;

  /// The share copy of the cycle data, in that folder.
  String get documentPath => '$folderPath/cycle_data.json';

  /// Where the copy lives on the sharer's pod, for the recipient to fetch.
  /// [podRoot] is the sharer's storage root; the app folder and data folder
  /// follow solidpod's layout.
  Uri documentUrl(Uri podRoot) =>
      podRoot.resolve('${SolidClient.appDirName}/data/$documentPath');

  /// The folder's `.acl`: the owner keeps everything, the recipient reads,
  /// and the rule carries down to the files in the folder. Nothing for any
  /// class of agent.
  Future<String> aclTurtle({
    required String ownerWebId,
    required String folderUrl,
  }) => solid.genAclTurtle(
    folderUrl,
    externalWebId: ownerWebId,
    isFile: false,
    thirdPartyAccess: {
      recipientWebId: {solid.AccessMode.read},
    },
  );
}
