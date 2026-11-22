import 'package:easybus_app/screens/settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/layout_checks.dart';

void main() {
  testWidgets('Explica la privacidad de la ubicación y abre los ajustes del sistema', (tester) async {
    var opened = 0;
    await pumpScreen(
      tester,
      SettingsScreen(
        openAppSettings: () async {
          opened++;
          return true;
        },
      ),
    );
    expect(find.text('Se usa solo en tu teléfono'), findsOneWidget);
    expect(find.text('No se envía ni se guarda en el servidor'), findsOneWidget);
    expect(find.text('Ley 1581 de 2012'), findsOneWidget);
    expect(find.textContaining('RNF-07'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Abrir ajustes de permisos'), 200);
    await tester.ensureVisible(find.text('Abrir ajustes de permisos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir ajustes de permisos'));
    expect(opened, 1);
  });

  for (final scale in fontScales) {
    testWidgets('Sin desbordes con la fuente al ${(scale * 100).round()} %', (tester) async {
      await pumpScreen(tester, SettingsScreen(openAppSettings: () async => true), scale: scale);
      await expectLastItemAboveNavBar(
        tester,
        find.text('Se abre la configuración de EASYBUS en tu teléfono.'),
      );
    });
  }
}
