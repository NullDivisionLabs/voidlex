// Generates the VoidLex launcher-icon source PNGs.
//
//   source:     assets/icon/app_icon_source.png      user-provided artwork
//   master:     assets/icon/app_icon.png             1024x1024, solid bg
//   foreground: assets/icon/app_icon_foreground.png  1024x1024, transparent
//
// Run: `dart run tool/generate_app_icon.dart`. After this, run
// `dart run flutter_launcher_icons` to fan the master out to each platform.

import 'dart:io';

import 'package:image/image.dart' as img;

const int _canvas = 1024;
const String _sourcePath = 'assets/icon/app_icon_source.png';

// Keep these aligned with the launcher icon config in pubspec.yaml.
final _bg = img.ColorRgba8(0x08, 0x09, 0x0B, 0xFF);
final _transparent = img.ColorRgba8(0, 0, 0, 0);

void main() {
  Directory('assets/icon').createSync(recursive: true);

  final sourceFile = File(_sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing launcher icon source: $_sourcePath');
    exitCode = 1;
    return;
  }

  final source = img.decodeImage(sourceFile.readAsBytesSync());
  if (source == null) {
    stderr.writeln('Unable to decode launcher icon source: $_sourcePath');
    exitCode = 1;
    return;
  }

  final master = _composeIcon(source, background: _bg, scale: 1);
  File('assets/icon/app_icon.png').writeAsBytesSync(img.encodePng(master));

  final foreground = _composeIcon(
    source,
    background: _transparent,
    scale: 0.84,
  );
  File(
    'assets/icon/app_icon_foreground.png',
  ).writeAsBytesSync(img.encodePng(foreground));

  stdout.writeln(
    'Wrote assets/icon/app_icon.png and assets/icon/app_icon_foreground.png',
  );
}

img.Image _composeIcon(
  img.Image source, {
  required img.Color background,
  required double scale,
}) {
  final canvas = img.Image(width: _canvas, height: _canvas, numChannels: 4);
  img.fill(canvas, color: background);

  final size = (_canvas * scale).round();
  final artwork = img.copyResize(
    source,
    width: size,
    height: size,
    interpolation: img.Interpolation.cubic,
  );

  img.compositeImage(
    canvas,
    artwork,
    dstX: (_canvas - artwork.width) ~/ 2,
    dstY: (_canvas - artwork.height) ~/ 2,
  );

  return canvas;
}
