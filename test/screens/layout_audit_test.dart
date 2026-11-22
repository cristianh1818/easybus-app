// Auditoría de diseño en un teléfono angosto (360 dp) con la fuente al 100, 130 y
// 200 %: sin palabras partidas, sin superposiciones, etiquetas de la barra dentro
// de su espacio y el final de cada pestaña visible por encima de la barra inferior.

import 'package:easybus_app/providers/clock_provider.dart';
import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/screens/help_screen.dart';
import 'package:easybus_app/screens/home_shell.dart';
import 'package:easybus_app/screens/settings_screen.dart';
import 'package:easybus_app/widgets/eb_bottom_nav.dart';
import 'package:easybus_app/widgets/eb_menu_button.dart';
import 'package:easybus_app/widgets/eb_side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/fake_repository.dart';
import '../helpers/layout_checks.dart';

Future<void> _pumpShell(WidgetTester tester, double scale) => pumpScreen(
  tester,
  ProviderScope(
    overrides: [
      easybusRepositoryProvider.overrideWithValue(FakeRepository()),
      clockProvider.overrideWith((ref) => Stream.value(DateTime(2026, 11, 10, 7, 3))),
    ],
    child: const HomeShell(),
  ),
  scale: scale,
);

Finder _navLabel(String label) => find.descendant(of: find.byType(EbBottomNav), matching: find.text(label));

/// Título del encabezado de la pestaña visible (el texto grande junto al ☰).
Finder _visibleHeaderTitle(String title) =>
    find.descendant(of: find.byType(IndexedStack), matching: find.text(title)).hitTestable();

Future<void> _selectTab(WidgetTester tester, String label) async {
  await tester.tap(_navLabel(label));
  await tester.pumpAndSettle();
}

/// Desplaza la pestaña visible hasta el final.
Future<void> _scrollToEnd(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable).hitTestable().first;
  for (var i = 0; i < 6; i++) {
    await tester.drag(scrollable, const Offset(0, -600));
    await tester.pumpAndSettle();
  }
}

double _navBarTop(WidgetTester tester) =>
    tester.getTopLeft(find.byType(EbBottomNav)).dy + EbBottomNav.bubbleOverflow;

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'EASYBUS',
      packageName: 'co.easybus.easybus_app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  for (final scale in fontScales) {
    final pct = '${(scale * 100).round()} %';

    group('Fuente al $pct (360 dp)', () {
      testWidgets('Barra inferior: cada etiqueta cabe en su espacio; la activa, en su burbuja', (
        tester,
      ) async {
        await _pumpShell(tester, scale);
        final width = smallPhone.width / 3;
        for (final (i, label) in ['Embarcaderos', 'Mapa', 'Cuenta'].indexed) {
          await _selectTab(tester, label);
          for (final (j, other) in ['Embarcaderos', 'Mapa', 'Cuenta'].indexed) {
            final finder = _navLabel(other);
            if (finder.evaluate().isEmpty) continue; // etiqueta oculta: permitido
            final r = tester.getRect(finder);
            expect(r.left, greaterThanOrEqualTo(j * width + 2), reason: '"$other" toca el borde izquierdo');
            expect(r.right, lessThanOrEqualTo((j + 1) * width - 2), reason: '"$other" toca el borde derecho');
          }
          // Dentro de la forma REAL de la burbuja (esquinas redondeadas), no solo de su rectángulo
          final bubble = RRect.fromRectAndRadius(
            tester.getRect(find.byKey(EbBottomNav.bubbleKey)),
            const Radius.circular(EbBottomNav.bubbleRadius),
          );
          final r = tester.getRect(_navLabel(label));
          for (final corner in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
            expect(
              bubble.contains(corner),
              isTrue,
              reason: '"$label" se sale de la burbuja (pestaña $i): $r',
            );
          }
        }
        // Las tres etiquetas con el mismo tamaño de letra
        final heights = {
          for (final l in ['Embarcaderos', 'Mapa', 'Cuenta']) tester.getSize(_navLabel(l)).height.round(),
        };
        expect(heights, hasLength(1), reason: 'Etiquetas de tamaños distintos: $heights');
      });

      for (final tab in ['Embarcaderos', 'Mapa', 'Cuenta']) {
        testWidgets('$tab: sin palabras partidas, ☰ sin tapar el título, final visible', (tester) async {
          await _pumpShell(tester, scale);
          await _selectTab(tester, tab);
          expectNoBrokenWords(tester);

          final menu = find.byType(EbMenuButton).hitTestable();
          expect(menu, findsOneWidget);
          final title = _visibleHeaderTitle(tab);
          if (title.evaluate().isNotEmpty) {
            expectNoOverlap(tester, menu, title, reason: 'El ☰ tapa el título "$tab"');
          }

          if (tab != 'Mapa') {
            await _scrollToEnd(tester);
            expectNoBrokenWords(tester);
            final lastCard = find.byType(Card).hitTestable().last;
            expect(
              tester.getBottomLeft(lastCard).dy,
              lessThanOrEqualTo(_navBarTop(tester)),
              reason: 'La última tarjeta de $tab queda tapada por la barra inferior',
            );
          }
        });
      }

      testWidgets('Cuenta: cabecera de todo el ancho y avatar completo y centrado', (tester) async {
        await _pumpShell(tester, scale);
        await _selectTab(tester, 'Cuenta');
        final avatar = tester.getRect(find.byType(CircleAvatar).hitTestable());
        expect(avatar.left, greaterThanOrEqualTo(0));
        expect(avatar.right, lessThanOrEqualTo(smallPhone.width));
        expect(avatar.center.dx, closeTo(smallPhone.width / 2, 1));
        expect(find.text('Gastos mensuales'), findsNothing, reason: 'Fuera de la beta (documento 2.2)');
      });

      testWidgets('Menú lateral: sin palabras partidas', (tester) async {
        await _pumpShell(tester, scale);
        await tester.tap(find.byType(EbMenuButton).hitTestable());
        await tester.pumpAndSettle();
        expectNoBrokenWords(tester);
        await tester.drag(find.byType(EbSideMenu), const Offset(0, -2000));
        await tester.pumpAndSettle();
        expectNoBrokenWords(tester);
      });

      testWidgets('Configuración y Ayuda: sin palabras partidas', (tester) async {
        await pumpScreen(tester, SettingsScreen(openAppSettings: () async => true), scale: scale);
        expectNoBrokenWords(tester);
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
        await tester.pumpAndSettle();
        expectNoBrokenWords(tester);

        await pumpScreen(tester, const HelpScreen(), scale: scale);
        expectNoBrokenWords(tester);
      });
    });
  }
}
