import 'dart:math' as math;

import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/providers/retry_policy.dart';
import 'package:easybus_app/screens/splash_screen.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:easybus_app/theme/eb_theme.dart';
import 'package:easybus_app/widgets/eb_animated_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart';

const _next = Key('siguiente');

Widget _app(FakeRepository repo, {bool reduceMotion = false, Duration maxWait = SplashScreen.maxDuration}) =>
    ProviderScope(
      retry: apiRetryPolicy,
      overrides: [easybusRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: EbTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
          child: child!,
        ),
        home: SplashScreen(
          next: (_) => const Scaffold(key: _next),
          maxWait: maxWait,
        ),
      ),
    );

void main() {
  testWidgets('Con datos rápidos espera el mínimo de 600 ms y precarga embarcaderos', (tester) async {
    final repo = FakeRepository();
    await tester.pumpWidget(_app(repo));

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(_next), findsNothing, reason: 'No debe cortar la animación antes de 600 ms');

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300)); // transición
    expect(find.byKey(_next), findsOneWidget);
    expect(repo.embarcaderosCalls, 1);
  });

  testWidgets('Si la red no responde, entra a los 2 s como máximo', (tester) async {
    await tester.pumpWidget(_app(FakeRepository(never: true)));
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byKey(_next), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_next), findsOneWidget);
  });

  testWidgets('Si la API falla, entra igual (la pantalla mostrará el error)', (tester) async {
    const error = ApiException(kind: ApiErrorKind.client, code: 'X', message: 'x', statusCode: 400);
    await tester.pumpWidget(_app(FakeRepository(error: error)));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(_next), findsOneWidget);
  });

  testWidgets('El logo aparece centrado al 90 % (como el nativo), crece a 1 y luego pulsa', (tester) async {
    await tester.pumpWidget(_app(FakeRepository(never: true), maxWait: const Duration(seconds: 10)));
    await _waitForLogo(tester);

    final logo = find.byType(EbAnimatedLogo);
    final screen = tester.getSize(find.byType(Scaffold));
    expect(tester.getCenter(logo), Offset(screen.width / 2, screen.height / 2));
    expect(tester.getSize(logo), const Size.square(EbAnimatedLogo.splashSize));
    expect(
      _scale(tester),
      closeTo(EbAnimatedLogo.startScale, 0.001),
      reason: 'Primer cuadro = splash nativo',
    );

    await tester.pump(const Duration(milliseconds: 400)); // entrada
    expect(_scale(tester), closeTo(1.0, 0.005));

    // Pulso: se muestrea cada 50 ms durante 2.4 s
    final scales = <double>[];
    final opacities = <double>[];
    for (var t = 0; t < 2400; t += 50) {
      await tester.pump(const Duration(milliseconds: 50));
      scales.add(_scale(tester));
      opacities.add(_opacity(tester));
    }
    expect(scales.reduce(math.max), closeTo(1.03, 0.003), reason: 'Pulso leve: hasta 1.03');
    expect(scales.reduce(math.min), greaterThanOrEqualTo(0.999));
    expect(opacities.reduce(math.min), closeTo(0.9, 0.01));
    // Suave: nunca salta más de 0.01 de escala entre cuadros de 50 ms
    for (var i = 1; i < scales.length; i++) {
      expect((scales[i] - scales[i - 1]).abs(), lessThan(0.01));
    }
    // Sin parpadeos: a lo sumo 2 picos en 2.4 s (menos de 1 por segundo)
    var peaks = 0;
    for (var i = 1; i < scales.length - 1; i++) {
      if (scales[i] > scales[i - 1] && scales[i] >= scales[i + 1] && scales[i] > 1.02) peaks++;
    }
    expect(peaks, inInclusiveRange(1, 2));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Con "reducir movimiento": solo un fade corto, sin escala ni bucle', (tester) async {
    await tester.pumpWidget(_app(FakeRepository(never: true), reduceMotion: true));
    await _waitForLogo(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_scale(tester), 1.0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(SplashScreen.maxDuration);
    await tester.pump(const Duration(milliseconds: 300));
  });
}

/// El splash monta el logo cuando la imagen está decodificada (eso ocurre fuera
/// del reloj falso de las pruebas).
Future<void> _waitForLogo(WidgetTester tester) async {
  await tester.runAsync(() async {
    final context = tester.element(find.byType(SplashScreen));
    await precacheImage(const AssetImage(EbAnimatedLogo.asset), context);
  });
  await tester.pump();
  expect(find.byType(EbAnimatedLogo), findsOneWidget);
}

double _scale(WidgetTester tester) {
  final transforms = tester.widgetList<Transform>(
    find.descendant(of: find.byType(EbAnimatedLogo), matching: find.byType(Transform)),
  );
  // Escala en X (Transform.scale no escala Z, así que getMaxScaleOnAxis daría 1)
  return transforms.isEmpty ? 1.0 : transforms.first.transform.entry(0, 0);
}

double _opacity(WidgetTester tester) => tester
    .widget<Opacity>(find.descendant(of: find.byType(EbAnimatedLogo), matching: find.byType(Opacity)))
    .opacity;
