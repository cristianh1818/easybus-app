import 'package:easybus_app/models/aviso.dart';
import 'package:easybus_app/models/embarcadero.dart';
import 'package:easybus_app/models/json.dart';
import 'package:easybus_app/models/transport_mode.dart';
import 'package:easybus_app/providers/clock_provider.dart';
import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/screens/pier_detail_screen.dart';
import 'package:easybus_app/screens/piers_screen.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:easybus_app/widgets/eb_alert_banner.dart';
import 'package:easybus_app/widgets/eb_pier_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart';
import '../helpers/layout_checks.dart';

final _now = DateTime(2026, 11, 10, 7, 3);

/// El embarcadero tal como llega en la lista (Calle 37).
Embarcadero get _calle37 =>
    EmbarcaderoDetalle.fromJson(asJsonMap(readFixture('embarcadero_detalle.json'))).embarcadero;

List<Object> _overrides(FakeRepository repo) => [
  easybusRepositoryProvider.overrideWithValue(repo),
  nowProvider.overrideWithValue(() => _now),
  clockProvider.overrideWith((ref) => Stream.value(_now)),
];

Future<List<Uri>> _pumpDetail(WidgetTester tester, FakeRepository repo, {double scale = 1.0}) async {
  final opened = <Uri>[];
  await pumpScreen(
    tester,
    ProviderScope(
      retry: (_, _) => null,
      overrides: _overrides(repo).cast(),
      child: PierDetailScreen(
        embarcadero: _calle37,
        openUrl: (url) async {
          opened.add(url);
          return true;
        },
      ),
    ),
    scale: scale,
  );
  return opened;
}

void main() {
  testWidgets('Muestra el embarcadero, sus rutas, el próximo zarpe y los siguientes', (tester) async {
    await _pumpDetail(tester, FakeRepository());
    expect(find.text('Embarcadero Calle 37'), findsOneWidget);
    expect(find.text('Ronda del Sinú a la altura de la Calle 37'), findsOneWidget);
    expect(find.text('Parada 2 de 5 · hacia Embarcadero Sur'), findsOneWidget);
    expect(find.text('Parada 4 de 5 · hacia Embarcadero Ronda Norte'), findsOneWidget);
    expect(find.text('07:30 · en 27 min'), findsWidgets);
    expect(find.text('Luego: 08:00 · 08:30 · 09:00'), findsWidgets);
    expect(find.text('Horarios programados, no ubicación en tiempo real.'), findsOneWidget);
  });

  testWidgets('Accesibilidad: sin datos dice "Sin información", no "No"', (tester) async {
    await _pumpDetail(tester, FakeRepository());
    await tester.scrollUntilVisible(find.text('Accesibilidad'), 200);
    expect(find.text('Sin información'), findsNWidgets(3));
    expect(find.text('No'), findsNothing);
  });

  testWidgets('Los avisos van antes que las rutas', (tester) async {
    final avisos = asJsonList(readFixture('avisos_sintetico.json'), Aviso.fromJson);
    await _pumpDetail(tester, FakeRepository(avisosList: avisos));
    // Pantalla alta: así se construyen a la vez los avisos y las rutas
    tester.view.physicalSize = const Size(360, 3000);
    await tester.pumpAndSettle();
    final banner = tester.getBottomLeft(find.byType(EbAlertBanner).last).dy;
    expect(banner, lessThan(tester.getTopLeft(find.text('Rutas y próximos zarpes')).dy));
  });

  testWidgets('"Cómo llegar" abre Google Maps con el embarcadero como destino', (tester) async {
    final opened = await _pumpDetail(tester, FakeRepository());
    await tester.scrollUntilVisible(find.text('Cómo llegar'), 200);
    await tester.ensureVisible(find.text('Cómo llegar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cómo llegar'));
    final url = opened.single;
    expect(url.host, 'www.google.com');
    expect(url.queryParameters['destination'], '8.761,-75.8815');
    expect(url.queryParameters['travelmode'], 'walking');
  });

  testWidgets('Si el detalle no carga: el encabezado sigue, con el error y Reintentar', (tester) async {
    const offline = ApiException(
      kind: ApiErrorKind.noConnection,
      code: 'SIN_CONEXION',
      message: 'Sin conexión a internet. Revisa tus datos o tu Wi-Fi e intenta de nuevo.',
    );
    final repo = FakeRepository(error: offline);
    await _pumpDetail(tester, repo);
    expect(find.text('Embarcadero Calle 37'), findsOneWidget, reason: 'Lo que ya se sabía de la lista');
    expect(find.text('No se pudieron cargar las rutas y los zarpes'), findsOneWidget);
    expect(find.text(offline.message), findsOneWidget);

    repo.error = null;
    // Hay dos "Reintentar": el de los avisos y el de las rutas
    expect(find.text('Reintentar'), findsNWidgets(2));
    final retry = find.widgetWithText(OutlinedButton, 'Reintentar');
    await tester.ensureVisible(retry);
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Parada 2 de 5 · hacia Embarcadero Sur'), 200);
    expect(find.text('No se pudieron cargar las rutas y los zarpes'), findsNothing);
  });

  testWidgets('Tocar una tarjeta de la lista abre su detalle', (tester) async {
    await pumpScreen(
      tester,
      const Scaffold(body: PiersScreen(mode: TransportMode.fluvial)),
      // Como en la app: el ProviderScope envuelve todo, también las pantallas que se abren
      wrapApp: (app) =>
          ProviderScope(retry: (_, _) => null, overrides: _overrides(FakeRepository()).cast(), child: app),
    );
    await tester.tap(find.text('Embarcadero Ronda Norte'));
    await tester.pumpAndSettle();
    expect(find.byType(PierDetailScreen), findsOneWidget);
    expect(find.bySemanticsLabel('Ver Embarcadero Calle 37'), findsNothing, reason: 'Ya en el detalle');
    expect(find.byType(EbPierCard), findsNothing);
  });

  for (final scale in fontScales) {
    testWidgets('Sin desbordes ni palabras partidas con la fuente al ${(scale * 100).round()} %', (
      tester,
    ) async {
      final avisos = asJsonList(readFixture('avisos_sintetico.json'), Aviso.fromJson);
      await _pumpDetail(tester, FakeRepository(avisosList: avisos), scale: scale);
      expectNoBrokenWords(tester);
      await expectLastItemAboveNavBar(
        tester,
        find.text('Se abre Google Maps con el embarcadero como destino.'),
      );
      expectNoBrokenWords(tester);
    });
  }
}
