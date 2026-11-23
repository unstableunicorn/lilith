// A QR code on a white tile, so a phone camera reads it in either theme.

import 'package:lilith/ui/theme/lilith_theme.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeBox extends StatelessWidget {
  const QrCodeBox({required this.data, required this.label, super.key});

  /// What the code carries, usually a link.
  final String data;

  /// What a screen reader says instead of the picture.
  final String label;

  static const double size = 200;

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      padding: const EdgeInsets.all(Space.md),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.all(Radius.circular(Radii.tile)),
      ),
      child: QrImageView(
        data: data,
        size: size,
        padding: EdgeInsets.zero,
        semanticsLabel: label,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Color(0xFF000000),
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Color(0xFF000000),
        ),
      ),
    ),
  );
}
