// Configuración de la app que cambia según dónde corre. Se pasa al compilar:
//
//   Teléfono físico por USB (con `adb reverse tcp:3000 tcp:3000`), valor por defecto:
//     flutter run
//   Emulador Android (10.0.2.2 es el localhost del computador):
//     flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
//   Producción (HTTPS obligatorio):
//     flutter build apk --release --dart-define=API_BASE_URL=https://api.ejemplo.co/api/v1
//
// Aquí no van secretos: todo lo que se compila en la app se puede extraer del APK.

import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const _rawApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api/v1',
  );

  /// URL base de la API, sin "/" final (las rutas se piden como "/rutas").
  static final String apiBaseUrl = parseApiBaseUrl(_rawApiBaseUrl, release: kReleaseMode);

  /// Valida y normaliza la URL base. En release solo se acepta HTTPS.
  @visibleForTesting
  static String parseApiBaseUrl(String raw, {required bool release}) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty || !{'http', 'https'}.contains(uri.scheme)) {
      throw StateError('API_BASE_URL no es una URL válida: "$raw"');
    }
    if (release && uri.scheme != 'https') {
      throw StateError('En release la API debe usar HTTPS (API_BASE_URL="$raw")');
    }
    final text = uri.toString();
    return text.endsWith('/') ? text.substring(0, text.length - 1) : text;
  }
}
