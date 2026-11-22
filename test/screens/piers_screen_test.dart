import 'package:easybus_app/models/aviso.dart';
import 'package:easybus_app/models/json.dart';
import 'package:easybus_app/models/transport_mode.dart';
import 'package:easybus_app/providers/clock_provider.dart';
import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/screens/piers_screen.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:easybus_app/widgets/eb_alert_banner.dart';
import 'package:easybus_app/widgets/eb_pier_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart';
import '../helpers/layout_checks.dart';

/// Misma hora en que "se consultó" la próxima salida: los minutos no se descuentan.
final _now = DateTime(2026, 11, 10, 7, 3);

const _offline = ApiException(
  kind: ApiErrorKind.noConnection,
  code: 'SIN_CONEXION',
  message: 'No hay conexión con EASYBUS. Revisa tu internet e intenta de nuevo.',
);
const _serverDown = ApiException(
  kind: ApiErrorKind.server,
  code: 'SERVICIO_NO_DISPONIBLE',
  message: 'El servicio no está disponible en este momento. Intenta más tarde.',
  statusCode: 503,
);

Future<void> _pump(WidgetTester tester, FakeRepository repo, {double scale = 1.0, bool settle = true}) async {
  await pumpScreen(
    tester,
    ProviderScope(
      // Sin reintentos automáticos: las pruebas ven el error de inmediato
      retry: (_, _) => null,
      overrides: [
        easybusRepositoryProvider.overrideWithValue(repo),
        nowProvider.overrideWithValue(() => _now),
        clockProvider.overrideWith((ref) => Stream.value(_now)),
      ],
      child: const Scaffold(body: PiersScreen(mode: TransportMode.fluvial)),
    ),
    scale: scale,
    settle: settle,
  );
}

/// El skeleton usa tarjetas de ejemplo con este nombre (find.byType(Skeletonizer) no
/// sirve: el constructor crea un widget de otra clase).
final _skeleton = find.text('Embarcadero de ejemplo');

List<String> _cardTitles(WidgetTester tester) => [
  for (final card in tester.widgetList<EbPierCard>(find.byType(EbPierCard))) card.item.embarcadero.nombre,
];

void main() {
  testWidgets('Lista ordenada a lo largo del río, con el próximo zarpe de cada sentido', (tester) async {
    await _pump(tester, FakeRepository());

    // Los primeros, en el orden de la ruta (ida)
    expect(find.text('Embarcadero Ronda Norte'), findsOneWidget);
    final titles = <String>[];
    for (var i = 0; i < 10 && titles.length < 8; i++) {
      for (final t in _cardTitles(tester)) {
        if (!titles.contains(t)) titles.add(t);
      }
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
    }
    expect(titles, [
      'Embarcadero Ronda Norte',
      'Embarcadero Calle 37',
      'Embarcadero Centro',
      'Embarcadero Corrección',
      'Embarcadero Sur',
      // Sin ruta: al final, por nombre
      'Embarcadero Batallón',
      'Embarcadero Margen Izquierda',
      'Embarcadero Puente Metálico',
    ]);
  });

  testWidgets('Próximo zarpe: hora, minutos y aviso de horario programado', (tester) async {
    await _pump(tester, FakeRepository());
    expect(find.text('07:30 · en 27 min'), findsWidgets);
    expect(find.text('BS-1 · Hacia Embarcadero Sur'), findsWidgets);
    expect(find.text('Horarios programados, no ubicación en tiempo real.'), findsOneWidget);
    expect(find.text('Actualizado hace un momento'), findsOneWidget);
  });

  testWidgets('Ronda Norte (origen de ida) solo tiene salida hacia el sur', (tester) async {
    await _pump(tester, FakeRepository());
    final card = tester.widget<EbPierCard>(find.byType(EbPierCard).first);
    expect(card.item.embarcadero.nombre, 'Embarcadero Ronda Norte');
    expect(card.item.services.map((s) => s.destino), ['Embarcadero Sur']);
  });

  testWidgets('Sin más salidas hoy: muestra la primera de mañana', (tester) async {
    await _pump(tester, FakeRepository(proximaSalidaFixture: 'proxima_salida_no_more.json'));
    expect(find.text('Sin más salidas hoy · mañana 05:42'), findsWidgets);
  });

  testWidgets('Suspensión: el zarpe dice "Suspendido", no una hora', (tester) async {
    await _pump(tester, FakeRepository(proximaSalidaFixture: 'proxima_salida_suspended_sintetico.json'));
    expect(find.text('Suspendido'), findsWidgets);
    expect(find.textContaining('07:30'), findsNothing);
  });

  testWidgets('Los avisos van arriba, antes que los horarios, y la suspensión primero', (tester) async {
    final avisos = asJsonList(readFixture('avisos_sintetico.json'), Aviso.fromJson);
    await _pump(tester, FakeRepository(avisosList: avisos.reversed.toList()));

    final banners = find.byType(EbAlertBanner);
    // El tercero del fixture está "programado" (aún no vigente): no se muestra
    expect(banners, findsNWidgets(2));
    expect(tester.widget<EbAlertBanner>(banners.first).aviso.esSuspension, isTrue);
    expect(find.text('Servicio suspendido · Ruta BS-1'), findsOneWidget);

    final lastBanner = tester.getBottomLeft(banners.last).dy;
    expect(lastBanner, lessThan(tester.getTopLeft(find.byType(EbPierCard).first).dy));
  });

  testWidgets('Si los avisos no se pueden consultar, lo dice (no los oculta)', (tester) async {
    await _pump(tester, FakeRepository(avisosError: _offline));
    expect(find.textContaining('No se pudieron verificar los avisos'), findsOneWidget);
    expect(find.byType(EbPierCard), findsWidgets, reason: 'La lista se muestra igual');
  });

  testWidgets('Si fallan las rutas, la lista se muestra sin zarpes y con una nota', (tester) async {
    await _pump(tester, FakeRepository(rutasError: _serverDown));
    expect(find.byType(EbPierCard), findsWidgets);
    expect(find.textContaining('No se pudieron consultar las rutas'), findsOneWidget);
    expect(find.textContaining('· en '), findsNothing);
  });

  testWidgets('Todos son datos de ejemplo: lo dice una vez, no en cada tarjeta', (tester) async {
    await _pump(tester, FakeRepository());
    expect(find.textContaining('Datos de ejemplo'), findsOneWidget);
    expect(find.text('Dato de ejemplo'), findsNothing);
  });

  testWidgets('Sin conexión: mensaje propio y Reintentar que vuelve a consultar', (tester) async {
    final repo = FakeRepository(error: _offline);
    await _pump(tester, repo);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text(_offline.message), findsOneWidget);

    repo.error = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.byType(EbPierCard), findsWidgets);
    expect(repo.embarcaderosCalls, 2);
  });

  testWidgets('Sin conexión con datos guardados: los muestra y lo dice', (tester) async {
    await _pump(tester, FakeRepository(staleError: _offline));
    expect(find.text('Sin conexión. Estás viendo los datos guardados en tu teléfono.'), findsOneWidget);
    expect(find.byType(EbPierCard), findsWidgets);
    expect(find.text('Sin conexión'), findsNothing, reason: 'No es la pantalla de error');
  });

  testWidgets('Error del servidor: "No pudimos cargar los embarcaderos" con el mensaje de la API', (
    tester,
  ) async {
    await _pump(tester, FakeRepository(error: _serverDown));
    expect(find.text('No pudimos cargar los embarcaderos'), findsOneWidget);
    expect(find.text(_serverDown.message), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('Vacío: "Todavía no hay embarcaderos"', (tester) async {
    await _pump(tester, FakeRepository(embarcaderos: const []));
    expect(find.text('Todavía no hay embarcaderos'), findsOneWidget);
  });

  group('Skeleton sin parpadeos', () {
    testWidgets('Si los datos llegan en menos de 300 ms, nunca se ve el skeleton', (tester) async {
      // 100 ms por consulta: embarcaderos y rutas en paralelo, luego el detalle de la
      // ruta → los datos están listos a los ~200 ms
      await _pump(tester, FakeRepository(delay: const Duration(milliseconds: 100)), settle: false);
      for (var t = 0; t < 300; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(_skeleton, findsNothing, reason: 'a los $t ms');
      }
      await tester.pumpAndSettle();
      expect(find.byType(EbPierCard), findsWidgets);
    });

    testWidgets('Si tarda, el skeleton aparece a los 300 ms y dura al menos 400 ms', (tester) async {
      await _pump(tester, FakeRepository(delay: const Duration(milliseconds: 400)), settle: false);
      await tester.pump(const Duration(milliseconds: 250));
      expect(_skeleton, findsNothing);
      await tester.pump(const Duration(milliseconds: 100)); // 350 ms
      expect(_skeleton, findsWidgets);
      // Los datos llegan a los 400 ms, pero el skeleton se queda hasta los 700 ms
      await tester.pump(const Duration(milliseconds: 100)); // 450 ms
      await tester.pump(const Duration(milliseconds: 100)); // 550 ms
      expect(find.text('Embarcadero de ejemplo'), findsWidgets);
      await tester.pumpAndSettle();
      expect(find.text('Embarcadero de ejemplo'), findsNothing);
      expect(find.text('Embarcadero Ronda Norte'), findsOneWidget);
    });
  });

  for (final scale in fontScales) {
    testWidgets('Sin desbordes con la fuente al ${(scale * 100).round()} %', (tester) async {
      final avisos = asJsonList(readFixture('avisos_sintetico.json'), Aviso.fromJson);
      await _pump(tester, FakeRepository(avisosList: avisos), scale: scale);
      await expectLastItemAboveNavBar(tester, find.text('Embarcadero Puente Metálico'));
    });
  }
}
