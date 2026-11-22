import 'package:easybus_app/providers/clock_provider.dart';
import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/screens/help_screen.dart';
import 'package:easybus_app/screens/home_shell.dart';
import 'package:easybus_app/screens/settings_screen.dart';
import 'package:easybus_app/widgets/eb_bottom_nav.dart';
import 'package:easybus_app/widgets/eb_side_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../helpers/fake_repository.dart';
import '../helpers/layout_checks.dart';

Future<void> _pumpShell(WidgetTester tester, {double scale = 1.0}) => pumpScreen(
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

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Abrir menú').first);
  await tester.pumpAndSettle();
}

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

  testWidgets('Abre en el Mapa, con la barra Embarcaderos · Mapa · Cuenta', (tester) async {
    await _pumpShell(tester);
    for (final label in ['Embarcaderos', 'Mapa', 'Cuenta']) {
      expect(find.descendant(of: find.byType(EbBottomNav), matching: find.text(label)), findsOneWidget);
    }
    expect(
      tester.getSemantics(find.bySemanticsLabel('Mapa')),
      matchesSemantics(
        hasSelectedState: true,
        isSelected: true,
        isButton: true,
        hasTapAction: true,
        label: 'Mapa',
      ),
    );
    expect(find.text('¿A dónde quieres ir hoy?'), findsOneWidget);
  });

  testWidgets('Cambiar de pestaña desliza el círculo y conserva las pestañas', (tester) async {
    await _pumpShell(tester);
    Alignment bubble() => tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).alignment as Alignment;
    expect(bubble().x, 0);

    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    expect(bubble().x, 1);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, HomeTab.account.index);

    await tester.tap(find.descendant(of: find.byType(EbBottomNav), matching: find.text('Embarcaderos')));
    await tester.pumpAndSettle();
    expect(bubble().x, -1);
    // Las tres pestañas siguen montadas (IndexedStack)
    expect(find.byType(IndexedStack), findsOneWidget);
  });

  testWidgets('Lectores de pantalla: los botones se pueden activar; "Próximamente" no', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpShell(tester);
    bool canTap(String label) => tester
        .getSemantics(find.bySemanticsLabel(label).first)
        .getSemanticsData()
        .hasAction(SemanticsAction.tap);

    for (final label in ['Embarcaderos', 'Mapa', 'Cuenta', 'Abrir menú', '¿A dónde quieres ir hoy?']) {
      expect(canTap(label), isTrue, reason: label);
    }
    await _openMenu(tester);
    expect(canTap('Centro de ayuda'), isTrue);
    expect(canTap('Viaje seguro. Próximamente'), isFalse);
    handle.dispose();
  });

  testWidgets('La píldora del mapa lleva a Embarcaderos', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.text('¿A dónde quieres ir hoy?'));
    await tester.pumpAndSettle();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, HomeTab.piers.index);
  });

  testWidgets('El ☰ abre el menú lateral con sus seis opciones', (tester) async {
    await _pumpShell(tester);
    await _openMenu(tester);
    expect(find.byType(EbSideMenu), findsOneWidget);
    for (final label in [
      'Centro de ayuda',
      'Centro de notificaciones',
      'Viaje seguro',
      'Compartir',
      'Configuración',
      'Acerca de EASYBUS',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('Notificaciones y Viaje seguro dicen "Próximamente" y no hacen nada', (tester) async {
    await _pumpShell(tester);
    await _openMenu(tester);
    for (final label in ['Centro de notificaciones', 'Viaje seguro']) {
      expect(find.bySemanticsLabel('$label. Próximamente'), findsOneWidget);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(EbSideMenu), findsOneWidget, reason: 'El menú sigue abierto');
    }
  });

  testWidgets('Configuración abre la pantalla de privacidad de la ubicación', (tester) async {
    await _pumpShell(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Configuración'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('Centro de ayuda abre las preguntas frecuentes', (tester) async {
    await _pumpShell(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Centro de ayuda'));
    await tester.pumpAndSettle();
    expect(find.byType(HelpScreen), findsOneWidget);
    expect(find.text('¿EASYBUS usa mi ubicación?'), findsOneWidget);
  });

  testWidgets('Acerca de EASYBUS muestra la versión', (tester) async {
    await _pumpShell(tester);
    await _openMenu(tester);
    await tester.tap(find.text('Acerca de EASYBUS'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('Versión 1.0.0 (1)'), findsOneWidget);
  });

  for (final scale in fontScales) {
    final pct = (scale * 100).round();
    testWidgets('Sin desbordes con la fuente al $pct % (pestañas y menú)', (tester) async {
      await _pumpShell(tester, scale: scale);
      for (final tab in ['Cuenta', 'Embarcaderos', 'Mapa']) {
        await tester.tap(find.descendant(of: find.byType(EbBottomNav), matching: find.text(tab)));
        await tester.pumpAndSettle();
      }
      await _openMenu(tester);
      await tester.drag(find.byType(EbSideMenu), const Offset(0, -2000));
      await tester.pumpAndSettle();
    });

    testWidgets('Ayuda sin desbordes con la fuente al $pct %', (tester) async {
      await pumpScreen(tester, const HelpScreen(), scale: scale);
      await expectLastItemAboveNavBar(tester, find.text('¿Necesito internet?'));
    });
  }

  testWidgets('La barra inferior no tapa el final de la pestaña Cuenta', (tester) async {
    await _pumpShell(tester);
    await tester.tap(find.text('Cuenta'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    final barTop = tester.getTopLeft(find.byType(EbBottomNav)).dy + EbBottomNav.bubbleOverflow;
    expect(tester.getBottomLeft(find.text('Tus últimas consultas')).dy, lessThan(barTop));
  });
}
