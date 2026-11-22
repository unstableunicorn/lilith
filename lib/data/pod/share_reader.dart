// Reading a share somebody else made, from their pod, with this user's login.

abstract interface class ShareReader {
  /// The sharer's storage root: `pim:storage` on their public profile card,
  /// or the WebID's own folder when the card does not say.
  Future<Uri> podRootOf(String webId);

  /// The document at [url] as text. Throws [PodAccessException] when it is
  /// missing or refused: the share has ended or was never made for this user.
  Future<String> readDocument(Uri url);
}
