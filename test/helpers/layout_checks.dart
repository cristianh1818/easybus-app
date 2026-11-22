// Comprobaciones de diseño reutilizables para cada pantalla nueva:
// textos largos, fuente del sistema grande y barras del sistema.

import 'package:easybus_app/theme/eb_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Escalas de fuente a probar: normal, 130 % (requisito de accesibilidad) y 200 %.
const fontScales = [1.0, 1.3, 2.0];

/// Teléfono pequeño (360×640 dp) con barra de estado y barra de navegación por
/// botones (48 dp), como un Android de gama baja.
const smallPhone = Size(360, 640);
const systemBars = EdgeInsets.only(top: 24, bottom: 48);

bool _poppinsLoaded = false;

/// Carga Poppins real: por defecto las pruebas usan una fuente de prueba con otras
/// medidas, y los desbordes no saldrían igual que en el teléfono.
Future<void> _loadPoppins() async {
  if (_poppinsLoaded) return;
  final loader = FontLoader(EbTheme.fontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/Poppins-$weight.ttf'));
  }
  await loader.load();
  _poppinsLoaded = true;
}

/// Monta [screen] en el teléfono pequeño con la escala [scale].
/// Cualquier desbordamiento (RenderFlex overflowed…) hace fallar la prueba.
Future<void> pumpScreen(WidgetTester tester, Widget screen, {double scale = 1.0, bool settle = true}) async {
  await tester.runAsync(_loadPoppins);
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = smallPhone;
  tester.view.padding = FakeViewPadding(top: systemBars.top, bottom: systemBars.bottom);
  tester.view.viewPadding = FakeViewPadding(top: systemBars.top, bottom: systemBars.bottom);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(MaterialApp(theme: EbTheme.light(), home: screen));
  if (settle) await tester.pumpAndSettle();
}

/// Desplaza la lista principal hasta el final y verifica que el último elemento
/// termina por encima de la barra de navegación del sistema.
Future<void> expectLastItemAboveNavBar(WidgetTester tester, Finder lastItem) async {
  await tester.scrollUntilVisible(lastItem, 300, scrollable: find.byType(Scrollable).first);
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
  await tester.pumpAndSettle();
  final bottom = tester.getBottomLeft(lastItem).dy;
  expect(
    bottom,
    lessThanOrEqualTo(smallPhone.height - systemBars.bottom),
    reason: 'El último elemento queda debajo de la barra de navegación',
  );
}

/// Falla si algún texto en pantalla parte una palabra entre dos líneas
/// ("registrars / e"). Una palabra partida tiene recuadros en dos alturas distintas.
void expectNoBrokenWords(WidgetTester tester) {
  final broken = <String>[];
  for (final p in tester.allRenderObjects.whereType<RenderParagraph>()) {
    if (!p.hasSize || p.size.isEmpty) continue;
    final text = p.text.toPlainText(includeSemanticsLabels: false, includePlaceholders: false);
    for (final match in RegExp(r'\S+').allMatches(text)) {
      final boxes = p.getBoxesForSelection(TextSelection(baseOffset: match.start, extentOffset: match.end));
      final tops = boxes.map((b) => b.top.round()).toSet();
      if (tops.length > 1) broken.add('"${match.group(0)}" en "$text"');
    }
  }
  expect(broken, isEmpty, reason: 'Palabras partidas entre líneas: ${broken.join(', ')}');
}

/// Falla si los dos elementos se superponen en pantalla.
void expectNoOverlap(WidgetTester tester, Finder a, Finder b, {String? reason}) {
  final ra = tester.getRect(a), rb = tester.getRect(b);
  final overlap = ra.intersect(rb);
  expect(overlap.width <= 0.5 || overlap.height <= 0.5, isTrue, reason: reason ?? 'Se superponen: $ra y $rb');
}

/// Falla si [inner] se sale de [outer] (con [tolerance] px de margen).
void expectInside(WidgetTester tester, Finder inner, Finder outer, {double tolerance = 0.5, String? reason}) {
  final ri = tester.getRect(inner), ro = tester.getRect(outer).inflate(tolerance);
  expect(
    ro.contains(ri.topLeft) && ro.contains(ri.bottomRight - const Offset(0.01, 0.01)),
    isTrue,
    reason: reason ?? '$ri se sale de $ro',
  );
}
