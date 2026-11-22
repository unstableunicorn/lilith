// Handing a generated file to the user, injected so screens can be tested.

import 'package:lilith/domain/export_file.dart';

/// Offers [file] through the platform's share sheet, or a download on the web.
typedef FileSharer = Future<void> Function(ExportFile file);
