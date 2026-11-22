import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Hora actual. Se reemplaza en las pruebas para que no dependan del reloj real.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Reloj que se actualiza cada 30 s: recalcula "en X min" y "Actualizado hace X"
/// sin volver a consultar la API.
final clockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  final now = ref.watch(nowProvider);
  yield now();
  yield* Stream<DateTime>.periodic(const Duration(seconds: 30), (_) => now());
});
