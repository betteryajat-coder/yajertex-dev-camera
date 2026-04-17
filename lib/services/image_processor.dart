import 'dart:io';

import 'package:image/image.dart' as img;

/// Utilities for stamping GPS coordinates onto captured frames and for
/// rotating saved images 90 degrees at a time.
class ImageProcessor {
  /// Burns a small, readable lat/lon badge into the bottom-left corner of
  /// [srcPath] and writes the result to [dstPath]. Returns [dstPath].
  static Future<String> stampGeoOverlay({
    required String srcPath,
    required String dstPath,
    required double? latitude,
    required double? longitude,
    required String userName,
    required DateTime timestamp,
    bool mirror = false,
  }) async {
    final bytes = await File(srcPath).readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
      // If we can't decode, just copy the original to the destination.
      await File(srcPath).copy(dstPath);
      return dstPath;
    }

    // Front-camera frames are mirrored by some devices — un-mirror if asked.
    if (mirror) {
      decoded = img.flipHorizontal(decoded);
    }

    final w = decoded.width;
    final h = decoded.height;

    // Scale text size relative to image width so it's legible on any device.
    final baseFontSize = (w / 55).clamp(18.0, 48.0);
    final font = _pickFont(baseFontSize);

    final lat = latitude?.toStringAsFixed(6) ?? '—';
    final lon = longitude?.toStringAsFixed(6) ?? '—';
    final ts = _formatTs(timestamp);
    final lines = <String>[
      'YajerTex Dev Camera',
      'Lat: $lat',
      'Lon: $lon',
      '$ts  •  $userName',
    ];

    // Opaque translucent panel behind the text.
    final padding = (w * 0.018).round();
    final lineHeight = font.lineHeight + 4;
    final panelH = lines.length * lineHeight + padding * 2;
    final panelW = (w * 0.55).round();

    final left = padding;
    final top = h - panelH - padding;

    img.fillRect(
      decoded,
      x1: left,
      y1: top,
      x2: left + panelW,
      y2: top + panelH,
      color: img.ColorRgba8(0, 20, 40, 140),
    );

    // Thin blue accent line on the left edge.
    img.fillRect(
      decoded,
      x1: left,
      y1: top,
      x2: left + 4,
      y2: top + panelH,
      color: img.ColorRgba8(61, 169, 252, 255),
    );

    // Subtle drop-shadow for the text, then the bright foreground.
    for (var i = 0; i < lines.length; i++) {
      final y = top + padding + i * lineHeight;
      img.drawString(
        decoded,
        lines[i],
        font: font,
        x: left + padding + 9,
        y: y + 2,
        color: img.ColorRgba8(0, 0, 0, 180),
      );
      img.drawString(
        decoded,
        lines[i],
        font: font,
        x: left + padding + 8,
        y: y,
        color: img.ColorRgba8(245, 250, 255, 255),
      );
    }

    final out = img.encodeJpg(decoded, quality: 92);
    await File(dstPath).writeAsBytes(out, flush: true);
    return dstPath;
  }

  /// Rotates the image at [path] by [degrees] (multiples of 90), writing
  /// the rotated image back to the same path.
  static Future<void> rotateInPlace(String path, int degrees) async {
    final bytes = await File(path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final rotated = img.copyRotate(decoded, angle: degrees);
    final out = img.encodeJpg(rotated, quality: 92);
    await File(path).writeAsBytes(out, flush: true);
  }

  static img.BitmapFont _pickFont(double size) {
    if (size >= 44) return img.arial48;
    if (size >= 30) return img.arial24;
    return img.arial14;
  }

  static String _formatTs(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}';
  }
}
