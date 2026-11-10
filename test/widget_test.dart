import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:easybus_app/app.dart';
import 'package:easybus_app/models/transport_mode.dart';
import 'package:easybus_app/theme/eb_theme.dart';
import 'package:easybus_app/theme/eb_tokens.dart';
import 'package:easybus_app/theme/mode_style.dart';

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

  testWidgets('La app arranca en español', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EasyBusApp()));
    final context = tester.element(find.byType(Scaffold));
    expect(Localizations.localeOf(context).languageCode, 'es');
  });
}
