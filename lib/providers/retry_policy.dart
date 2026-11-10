import '../services/api_exception.dart';

/// Reintentos automáticos de los providers (ProviderScope.retry).
///
/// Riverpod 3 reintenta por defecto cualquier error hasta 10 veces. Aquí solo se
/// reintenta lo que puede arreglarse solo (sin conexión, tiempo agotado, 5xx), como
/// máximo 3 veces (a 1, 2 y 4 s). Un 400 o un 404 se muestra de inmediato.
Duration? apiRetryPolicy(int retryCount, Object error) {
  if (error is! ApiException || !error.isRetryable) return null;
  if (retryCount >= 3) return null;
  return Duration(seconds: 1 << retryCount);
}
