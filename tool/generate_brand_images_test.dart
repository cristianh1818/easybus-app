// Genera las imágenes de marca a partir del logo VECTORIAL oficial
// (docs/diseño/logo/easybus_logo.svg):
//
//   flutter test tool/generate_brand_images_test.dart
//   dart run flutter_native_splash:create
//   dart run flutter_launcher_icons
//
// - assets/images/easybus_logo.png  1024×1024, el logo del splash animado.
// - assets/splash/splash_logo.png   1152×1152 transparente, logo de 576 px en el centro.
//   A 4x son 144 dp: el 90 % del logo del splash animado (160 dp), que arranca a esa
//   escala. Cabe en el círculo de 768 px que Android 12+ deja visible.
// - assets/icon/icon_full.png       1024×1024, logo sobre el azul del logo (iOS no
//   acepta transparencia y Android antiguo usa un ícono cuadrado).
// - assets/icon/icon_foreground.png 1024×1024 transparente, cuadro del logo al 55 %:
//   capa frontal del ícono adaptativo de Android (zona segura de 66/108).
//
// Además mide el "halo": la mayor diferencia de color entre el borde del cuadro del
// logo y el fondo del splash. Con SPLASH_PREVIEW=ruta guarda una vista previa.

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:easybus_app/screens/splash_screen.dart';
import 'package:easybus_app/theme/eb_tokens.dart';
import 'package:easybus_app/widgets/eb_animated_logo.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _svgPath = 'docs/diseño/logo/easybus_logo.svg';

/// Dibuja el SVG a [px]×[px] (vectorial: nítido a cualquier tamaño).
Future<ui.Image> _rasterizeSvg(int px) async {
  final info = await vg.loadPicture(SvgStringLoader(File(_svgPath).readAsStringSync()), null);
  final r = ui.PictureRecorder();
  Canvas(r)
    ..scale(px / info.size.width, px / info.size.height)
    ..drawPicture(info.picture);
  info.picture.dispose();
  return r.endRecording().toImage(px, px);
}

Future<void> _savePicture(ui.Picture picture, int w, int h, String path) async =>
    _saveImage(await picture.toImage(w, h), path);

Future<void> _saveImage(ui.Image image, String path) async {
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

/// Recuadro del cuadro azul del logo (sin el margen transparente de las esquinas).
Future<Rect> _tileBounds(ui.Image logo) async {
  final data = (await logo.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  int alpha(int x, int y) => data.getUint8((y * logo.width + x) * 4 + 3);
  final mid = logo.height ~/ 2;
  var left = 0, right = logo.width - 1, top = 0, bottom = logo.height - 1;
  while (alpha(left, mid) < 250) {
    left++;
  }
  while (alpha(right, mid) < 250) {
    right--;
  }
  while (alpha(logo.width ~/ 2, top) < 250) {
    top++;
  }
  while (alpha(logo.width ~/ 2, bottom) < 250) {
    bottom--;
  }
  return Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
}

void _drawLogo(Canvas canvas, ui.Image logo, Rect dst, {Rect? src}) {
  canvas.drawImageRect(
    logo,
    src ?? Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble()),
    dst,
    Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true,
  );
}

Rect _centered(double canvas, double size) =>
    Rect.fromLTWH((canvas - size) / 2, (canvas - size) / 2, size, size);

/// Mayor diferencia por canal entre el fondo y los píxeles de una franja alrededor
/// del borde del cuadro (donde aparecería el halo). 0 = invisible.
Future<int> _haloDelta(ui.Image logo, Color background, int px) async {
  final r = ui.PictureRecorder();
  final c = Canvas(r)..drawColor(background, BlendMode.src);
  _drawLogo(c, logo, Rect.fromLTWH(0, 0, px.toDouble(), px.toDouble()));
  final image = await r.endRecording().toImage(px, px);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final bg = [background.r, background.g, background.b].map((v) => (v * 255).round()).toList();
  final tile = await _tileBounds(logo);
  final scale = px / logo.width;
  final left = (tile.left * scale).round(), top = (tile.top * scale).round();
  var maxDelta = 0;
  // Franja de 3 px a cada lado del borde izquierdo y superior, más las esquinas
  for (var y = 0; y < px; y++) {
    for (var x = math.max(0, left - 3); x <= left + 3; x++) {
      if (y > top + px * 0.15 && y < px - top - px * 0.15) continue; // solo cerca de las esquinas
      final i = (y * px + x) * 4;
      for (var ch = 0; ch < 3; ch++) {
        maxDelta = math.max(maxDelta, (data.getUint8(i + ch) - bg[ch]).abs());
      }
    }
  }
  return maxDelta;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Imágenes de splash e ícono desde el SVG', () async {
    final logo = await _rasterizeSvg(2048);

    // Logo del splash animado (1024 px: nítido hasta 6x a 160 dp)
    final r0 = ui.PictureRecorder();
    _drawLogo(Canvas(r0), logo, const Rect.fromLTWH(0, 0, 1024, 1024));
    await _savePicture(r0.endRecording(), 1024, 1024, EbAnimatedLogo.asset);

    // Splash nativo
    const density = 4.0;
    final splashPx = EbAnimatedLogo.splashSize * EbAnimatedLogo.startScale * density; // 576
    var r = ui.PictureRecorder();
    _drawLogo(Canvas(r), logo, _centered(1152, splashPx));
    await _savePicture(r.endRecording(), 1152, 1152, 'assets/splash/splash_logo.png');

    // Para los íconos se usa solo el cuadro azul, sin las esquinas transparentes: el
    // sistema pone su propia forma (iOS redondea, Android recorta en círculo o squircle).
    final tile = await _tileBounds(logo);
    // ignore: avoid_print
    print('Cuadro del logo (en 2048 px): $tile');

    // Ícono completo (iOS y Android antiguo): el cuadro ocupa todo el lienzo
    r = ui.PictureRecorder();
    final c = Canvas(r)..drawColor(EbColors.logoBlue, BlendMode.src);
    _drawLogo(c, logo, const Rect.fromLTWH(0, 0, 1024, 1024), src: tile);
    await _savePicture(r.endRecording(), 1024, 1024, 'assets/icon/icon_full.png');

    // Capa frontal del ícono adaptativo: el cuadro al 55 %. La zona que queda visible
    // con cualquier máscara es un círculo de 66/108 del lienzo (radio 0.305); las
    // esquinas de "EASYBUS" están a ~0.52 del centro del cuadro → 0.305 / 0.52 ≈ 0.58;
    // se usa 0.55 para dejar aire. El fondo es del mismo azul: el borde no se nota.
    r = ui.PictureRecorder();
    _drawLogo(Canvas(r), logo, _centered(1024, 1024 * 0.55), src: tile);
    await _savePicture(r.endRecording(), 1024, 1024, 'assets/icon/icon_foreground.png');

    // Halo con el fondo elegido y, para comparar, con el navy anterior
    final halo = await _haloDelta(logo, splashBackground, 640);
    final haloNavy = await _haloDelta(logo, EbColors.navy, 640);
    // ignore: avoid_print
    print('Halo (máx. diferencia por canal, 0-255): fondo del splash = $halo · navy = $haloNavy');
    expect(halo, lessThanOrEqualTo(2), reason: 'El borde del cuadro no debe notarse');

    const preview = String.fromEnvironment('SPLASH_PREVIEW');
    if (preview.isNotEmpty) {
      const w = 393.0 * 2, h = 852.0 * 2;
      r = ui.PictureRecorder();
      final p = Canvas(r)..drawColor(splashBackground, BlendMode.src);
      const size = EbAnimatedLogo.splashSize * 2;
      _drawLogo(p, logo, Rect.fromLTWH((w - size) / 2, (h - size) / 2, size, size));
      await _savePicture(r.endRecording(), w.toInt(), h.toInt(), preview);
    }
  });
}
