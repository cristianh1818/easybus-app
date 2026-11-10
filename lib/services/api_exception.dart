// Error único que ve el resto de la app al llamar a la API. Las pantallas
// muestran [message] tal cual (ya viene en español) y deciden si ofrecer
// "Reintentar" con [isRetryable].

enum ApiErrorKind {
  /// Sin internet o el servidor no responde (DNS, conexión rechazada…).
  noConnection,

  /// El servidor tardó demasiado.
  timeout,

  /// La API respondió con un error 4xx (datos inválidos, no encontrado…).
  client,

  /// La API respondió con un error 5xx o un 429.
  server,

  /// La respuesta llegó pero no tiene la forma esperada.
  invalidResponse,

  /// No se pudo verificar el certificado HTTPS.
  insecure,

  /// La petición se canceló (por ejemplo, al salir de la pantalla).
  cancelled,

  unknown,
}

class ApiException implements Exception {
  const ApiException({
    required this.kind,
    required this.code,
    required this.message,
    this.statusCode,
    this.errors = const [],
  });

  final ApiErrorKind kind;

  /// Código de la API (EMBARCADERO_FUERA_DE_RUTA, DATOS_INVALIDOS…) o uno local
  /// (SIN_CONEXION, TIEMPO_AGOTADO…) cuando el error no viene de la API.
  final String code;

  /// Mensaje en español para mostrar al usuario.
  final String message;

  final int? statusCode;

  /// Detalle de validación que la API envía en `errores` (puede venir vacío).
  final List<String> errors;

  bool get isRetryable => switch (kind) {
        ApiErrorKind.noConnection || ApiErrorKind.timeout || ApiErrorKind.server => true,
        _ => false,
      };

  /// Sin conexión o tiempo agotado: la pantalla puede mostrar los datos en caché.
  bool get isOffline => kind == ApiErrorKind.noConnection || kind == ApiErrorKind.timeout;

  @override
  String toString() => 'ApiException($code, ${statusCode ?? '-'}): $message';
}
