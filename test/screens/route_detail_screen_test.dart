import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/providers/clock_provider.dart';
import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/screens/route_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart';
import '../helpers/layout_checks.dart';

final _now = DateTime(2026, 11, 10, 7, 3);

void main() {
  testWidgets('Línea del río: hora de paso = salida del origen + minutos desde el origen', (tester) async {
    await pumpScreen(
      tester,
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          easybusRepositoryProvider.overrideWithValue(FakeRepository()),
          nowProvider.overrideWithValue(() => _now),
          clockProvider.overrideWith((ref) => Stream.value(_now)),
        ],
        child: const RouteDetailScreen(
          rutaId: '54169054-7fad-4f70-afd8-7c568855abff',
          codigo: 'BS-1',
          initialSentido: Sentido.ida,
        ),
      ),
      // El trazado animado del mapa no termina nunca: se avanza unos cuadros
      settle: false,
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.scrollUntilVisible(
      find.text('Embarcadero Sur').last,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Próxima salida del origen (Ronda Norte) 07:30: Calle 37 a +12 min, Sur (destino) a +60
    expect(
      find.text('Hora estimada de paso para la salida de las 07:30 desde Embarcadero Ronda Norte.'),
      findsOneWidget,
    );
    expect(find.text('07:42'), findsOneWidget);
    expect(find.text('08:30'), findsWidgets, reason: 'Llegada al destino (y también una salida del horario)');

    // Elegir otra salida recalcula las horas
    final salida0800 = find.bySemanticsLabel('Salida de las 08:00');
    await tester.ensureVisible(salida0800);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(salida0800);
    await tester.pump();
    expect(find.text('08:12'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
