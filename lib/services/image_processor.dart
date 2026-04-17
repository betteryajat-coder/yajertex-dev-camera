import 'dart:io';

import 'package:image/image.dart' as img;

/// Utilities for stamping the geo-overlay onto captured frames and for
/// rotating saved images 90 degrees at a time.
class ImageProcessor {
  /// Burns the overlay badge into the bottom-left corner of [srcPath]
  /// and writes the result to [dstPath]. Returns [dstPath].
  ///
  /// Format (top → bottom):
  ///   1. Society / area name (if provided)
  ///   2. Lat: XX.XXXXXX
  ///   3. Lng: XX.XXXXXX
  ///   4. 17 Apr 2026, 5:42 PM
  static Future<String> stampGeoOverlay({
    required String srcPath,
    required String dstPath,
    required double? latitude,
    required double? longitude,
    required String societyName,
    required DateTime timestamp,
    bool mirror = false,
  }) async {
    final bytes = await File(srcPath).readAsBytes();
    var decoded = img.decodeImage(bytes);
    if (decoded == null) {
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
    final titleFont = _pickFont(baseFontSize * 1.15);
    final bodyFont = _pickFont(baseFontSize);

    final lat = latitude?.toStringAsFixed(6) ?? '—';
    final lng = longitude?.toStringAsFixed(6) ?? '—';
    final dt = _formatDateTime(timestamp);

    final hasSociety = societyName.trim().isNotEmpty;
    final titleLine = hasSociety ? societyName.trim() : null;
    final bodyLines = <String>[
      'Lat: $lat',
      'Lng: $lng',
      dt,
    ];

    // Measure approximate panel size.
    final padding = (w * 0.02).round();
    final titleLineH = titleFont.lineHeight + 6;
    final bodyLineH = bodyFont.lineHeight + 4;
    final totalLinesH =
        (titleLine != null ? titleLineH : 0) + bodyLines.length * bodyLineH;
    final panelH = totalLinesH + padding * 2;
    final panelW = (w * 0.58).round();

    final left = padding;
    final top = h - panelH - padding;

    // Translucent panel.
    img.fillRect(
      decoded,
      x1: left,
      y1: top,
      x2: left + panelW,
      y2: top + panelH,
      color: img.ColorRgba8(0, 20, 40, 140),
    );

    // Thin blue accent on the left edge.
    img.fillRect(
      decoded,
      x1: left,
      y1: top,
      x2: left + 4,
      y2: top + panelH,
      color: img.ColorRgba8(61, 169, 252, 255),
    );

    var cursorY = top + padding;

    // Title (society name) — larger, bold-feeling (rendered twice for weight).
    if (titleLine != null) {
      _drawTextWithShadow(
        decoded,
        text: titleLine,
        font: titleFont,
        x: left + padding + 8,
        y: cursorY,
        fgColor: img.ColorRgba8(255, 255, 255, 255),
      );
      // Extra overlay pass for faux-bold weight.
      img.drawString(
        decoded,
        titleLine,
        font: titleFont,
        x: left + padding + 9,
        y: cursorY,
        color: img.ColorRgba8(255, 255, 255, 255),
      );
      cursorY += titleLineH;
    }

    // Body lines.
    for (final line in bodyLines) {
      _drawTextWithShadow(
        decoded,
        text: line,
        font: bodyFont,
        x: left + padding + 8,
        y: cursorY,
        fgColor: img.ColorRgba8(235, 245, 255, 255),
      );
      cursorY += bodyLineH;
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

  static void _drawTextWithShadow(
    img.Image target, {
    required String text,
    required img.BitmapFont font,
    required int x,
    required int y,
    required img.Color fgColor,
  }) {
    // Soft drop-shadow for legibility on bright backgrounds.
    img.drawString(
      target,
      text,
      font: font,
      x: x + 1,
      y: y + 2,
      color: img.ColorRgba8(0, 0, 0, 200),
    );
    img.drawString(
      target,
      text,
      font: font,
      x: x,
      y: y,
      color: fgColor,
    );
  }

  static img.BitmapFont _pickFont(double size) {
    if (size >= 44) return img.arial48;
    if (size >= 30) return img.arial24;
    return img.arial14;
  }

  static String _formatDateTime(DateTime t) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final hour24 = t.hour;
    final h12 = hour24 == 0 ? 12 : (hour24 > 12 ? hour24 - 12 : hour24);
    final suffix = hour24 >= 12 ? 'PM' : 'AM';
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${months[t.month - 1]} ${t.year}, $h12:$mm $suffix';
  }
}
