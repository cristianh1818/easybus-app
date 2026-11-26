// Historial de consultas en el teléfono (caché SQLite, clave "local/historial").

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/historial.dart';
import '../models/json.dart';
import 'cache_providers.dart';
import 'clock_provider.dart';

const historyCacheKey = 'local/historial';

final historyProvider = AsyncNotifierProvider<HistoryNotifier, List<Consulta>>(HistoryNotifier.new);

class HistoryNotifier extends AsyncNotifier<List<Consulta>> {
  @override
  Future<List<Consulta>> build() async {
    try {
      final saved = await ref.read(responseCacheProvider).read(historyCacheKey);
      return saved == null ? const [] : asJsonList(saved.json, Consulta.fromJson);
    } on Object catch (e) {
      debugPrint('[historial] no se pudo leer: $e');
      return const [];
    }
  }

  Future<void> recordRoute({required String rutaId, required String codigo, String? nombre}) => _record(
    Consulta(tipo: TipoConsulta.ruta, id: rutaId, titulo: 'Ruta $codigo', detalle: nombre, cuando: _now()),
  );

  Future<void> recordPier({required String id, required String nombre, String? referencia}) => _record(
    Consulta(tipo: TipoConsulta.embarcadero, id: id, titulo: nombre, detalle: referencia, cuando: _now()),
  );

  Future<void> clear() async {
    state = const AsyncData([]);
    await ref.read(responseCacheProvider).remove(historyCacheKey).catchError((Object _) {});
  }

  DateTime _now() => ref.read(nowProvider)();

  Future<void> _record(Consulta c) async {
    final actual = await future;
    final nuevo = agregarConsulta(actual, c);
    state = AsyncData(nuevo);
    try {
      await ref.read(responseCacheProvider).write(historyCacheKey, [
        for (final x in nuevo) x.toJson(),
      ], _now());
    } on Object catch (e) {
      debugPrint('[historial] no se pudo guardar: $e');
    }
  }
}
