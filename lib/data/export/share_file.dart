// The FileSharer the app uses: the platform share sheet via share_plus, which
// downloads the file instead on a browser that cannot share files.

import 'package:lilith/domain/export_file.dart';
import 'package:share_plus/share_plus.dart';

Future<void> shareExportFile(ExportFile file) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(file.bytes, mimeType: file.mimeType, name: file.name),
      ],
      fileNameOverrides: [file.name],
    ),
  );
}
