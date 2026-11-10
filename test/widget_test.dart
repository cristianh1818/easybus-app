import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easybus_app/app.dart';
import 'package:easybus_app/models/transport_mode.dart';
import 'package:easybus_app/providers/data_providers.dart';
import 'package:easybus_app/screens/splash_screen.dart';
import 'package:easybus_app/theme/eb_theme.dart';
import 'package:easybus_app/theme/eb_tokens.dart';
import 'package:easybus_app/theme/mode_style.dart';

import 'helpers/fake_repository.dart';

void main() {
  test('El tema usa Poppins y el azul marino institucional', () {
    final theme = EbTheme.light();
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Poppins');
    expect(theme.colorScheme.primary, EbColors.navy);
  });

  test('Cada modo de transporte tiene su estilo', () {
    for (final mode in TransportMode.values) {
      expect(modeStyle[mode], isNotNull, reason: '$mode sin estilo');
    }
    expect(TransportMode.fluvial.style.stopLabel, 'Embarcadero');
  });

  test('TransportMode.fromApi lee el valor de la API', () {
    expect(TransportMode.fromApi('bus'), TransportMode.bus);
    expect(TransportMode.fromApi('fluvial'), TransportMode.fluvial);
    expect(TransportMode.fromApi(null), TransportMode.fluvial);
  });

  testWidgets('La app arranca en español, con el splash', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [easybusRepositoryProvider.overrideWithValue(FakeRepository())],
        child: const EasyBusApp(),
      ),
    );
    expect(find.byType(SplashScreen), findsOneWidget);
    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context).languageCode, 'es');
    // Deja terminar el splash para no dejar temporizadores pendientes
    await tester.pump(SplashScreen.maxDuration);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SplashScreen), findsNothing);
  });
}
