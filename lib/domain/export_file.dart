// A file the app generated for the user to keep or pass on.

import 'dart:typed_data';

class ExportFile {
  const ExportFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}
