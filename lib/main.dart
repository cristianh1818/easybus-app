import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // De borde a borde en todas las versiones de Android (en Android 15+ ya es obligatorio).
  // Cada pantalla respeta las barras del sistema con SafeArea o ebScrollPadding.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  _registrarLicencias();
  runApp(const ProviderScope(child: EasyBusApp()));
}

// Poppins viene incluida en la app; su licencia OFL debe aparecer en "Licencias".
void _registrarLicencias() {
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Poppins'], ofl);
  });
}
