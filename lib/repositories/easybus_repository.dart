// Fuente de datos de las pantallas. Dos implementaciones con la misma interfaz:
//   - CachedEasybusRepository (la que usa la app): primero lo guardado en el
//     teléfono y luego lo actualizado desde la API.
//   - ApiEasybusRepository: solo la API, sin caché.
//
// Los métodos watch* devuelven un Stream de Fetched (datos + de dónde vienen + cuándo).
// Avisos y próxima salida siempre van a la API: un aviso de suspensión desactualizado
// o una hora calculada con otro reloj serían engañosos.

import '../models/aviso.dart';
import '../models/embarcadero.dart';
import '../models/enums.dart';
import '../models/horario.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';

import 'package:flutter/foundation.dart';

import '../domain/proxima_salida_local.dart';

import '../services/api_exception.dart';
import '../services/cache/response_cache.dart';
import '../services/easybus_api.dart';
import 'fetched.dart';

abstract interface class EasybusRepository {
  Stream<Fetched<List<Embarcadero>>> watchEmbarcaderos();
  Stream<Fetched<EmbarcaderoDetalle>> watchEmbarcadero(String id);
  Stream<Fetched<List<Ruta>>> watchRutas();
  Stream<Fetched<RutaDetalle>> watchRuta(String id);
  Stream<Fetched<HorariosSentido>> watchHorarios(String rutaId, Sentido sentido, {TipoDia? tipoDia});

  /// Siempre desde la API.
  Future<List<Aviso>> avisos({String? rutaId, String? embarcaderoId});

  /// Primero la API (conoce los avisos de suspensión). Si no hay conexión o el
  /// servidor no responde, la implementación con caché la calcula en el teléfono
  /// (origin: cache, refreshError: el error de la API).
  Future<Fetched<ProximaSalida>> proximaSalida(String rutaId, Sentido sentido, {String? desdeEmbarcaderoId});

  /// Guarda en el teléfono lo necesario para calcular la próxima salida sin
  /// conexión: horarios de cada sentido de [rutaIds] y festivos de ayer, hoy y
  /// mañana. No falla: si no hay conexión, se intentará la próxima vez.
  Future<void> prepareOffline({required List<String> rutaIds});
}

/// Implementación actual: todo desde la API, sin caché.
class ApiEasybusRepository implements EasybusRepository {
  ApiEasybusRepository(this._api, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final EasybusApi _api;
  final DateTime Function() _now;

  Stream<Fetched<T>> _once<T>(Future<T> Function() load) async* {
    final data = await load();
    yield Fetched(data, updatedAt: _now(), origin: DataOrigin.network);
  }

  @override
  Stream<Fetched<List<Embarcadero>>> watchEmbarcaderos() => _once(_api.embarcaderos);

  @override
  Stream<Fetched<EmbarcaderoDetalle>> watchEmbarcadero(String id) => _once(() => _api.embarcadero(id));

  @override
  Stream<Fetched<List<Ruta>>> watchRutas() => _once(_api.rutas);

  @override
  Stream<Fetched<RutaDetalle>> watchRuta(String id) => _once(() => _api.ruta(id));

  @override
  Stream<Fetched<HorariosSentido>> watchHorarios(String rutaId, Sentido sentido, {TipoDia? tipoDia}) =>
      _once(() => _api.horarios(rutaId, sentido, tipoDia: tipoDia));

  @override
  Future<List<Aviso>> avisos({String? rutaId, String? embarcaderoId}) =>
      _api.avisos(rutaId: rutaId, embarcaderoId: embarcaderoId);

  @override
  Future<Fetched<ProximaSalida>> proximaSalida(
    String rutaId,
    Sentido sentido, {
    String? desdeEmbarcaderoId,
  }) async {
    final p = await _api.proximaSalida(rutaId, sentido, desdeEmbarcaderoId: desdeEmbarcaderoId);
    return Fetched(p, updatedAt: _now(), origin: DataOrigin.network);
  }

  @override
  Future<void> prepareOffline({required List<String> rutaIds}) async {}
}

/// Caché offline + API. Para embarcaderos, rutas y horarios:
///   1. Emite lo guardado en el teléfono (si hay y se puede leer).
///   2. Consulta la API, guarda la respuesta y la emite.
///   3. Si la API falla y había algo guardado, lo vuelve a emitir marcado con el
///      error (la pantalla dice "Sin conexión · Actualizado hace X"). Si no había
///      nada guardado, el error llega a la pantalla.
class CachedEasybusRepository implements EasybusRepository {
  CachedEasybusRepository(this._api, this._cache, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final EasybusApi _api;
  final ResponseCache _cache;
  final DateTime Function() _now;

  Stream<Fetched<T>> _cacheThenNetwork<T>(ApiEndpoint<T> endpoint) async* {
    Fetched<T>? cached;
    try {
      final saved = await _cache.read(endpoint.cacheKey);
      if (saved != null) {
        cached = Fetched(endpoint.parse(saved.json), updatedAt: saved.updatedAt, origin: DataOrigin.cache);
      }
    } on Object catch (e) {
      // Guardado con otro formato o dañado: se descarta y se usa la red
      debugPrint('[cache] no se pudo leer ${endpoint.cacheKey}: $e');
      await _cache.remove(endpoint.cacheKey).catchError((Object _) {});
    }
    if (cached != null) yield cached;

    final (T, Object?) fresh;
    try {
      fresh = await _api.fetchWithJson(endpoint);
    } on ApiException catch (e) {
      if (cached == null) rethrow;
      yield Fetched(cached.data, updatedAt: cached.updatedAt, origin: DataOrigin.cache, refreshError: e);
      return;
    }
    final now = _now();
    try {
      await _cache.write(endpoint.cacheKey, fresh.$2, now);
    } on Object catch (e) {
      // Sin espacio, base cerrada…: la app sigue con los datos de la red
      debugPrint('[cache] no se pudo guardar ${endpoint.cacheKey}: $e');
    }
    yield Fetched(fresh.$1, updatedAt: now, origin: DataOrigin.network);
  }

  @override
  Stream<Fetched<List<Embarcadero>>> watchEmbarcaderos() => _cacheThenNetwork(ApiEndpoint.embarcaderos());

  @override
  Stream<Fetched<EmbarcaderoDetalle>> watchEmbarcadero(String id) =>
      _cacheThenNetwork(ApiEndpoint.embarcadero(id));

  @override
  Stream<Fetched<List<Ruta>>> watchRutas() => _cacheThenNetwork(ApiEndpoint.rutas());

  @override
  Stream<Fetched<RutaDetalle>> watchRuta(String id) => _cacheThenNetwork(ApiEndpoint.ruta(id));

  @override
  Stream<Fetched<HorariosSentido>> watchHorarios(String rutaId, Sentido sentido, {TipoDia? tipoDia}) =>
      _cacheThenNetwork(ApiEndpoint.horarios(rutaId, sentido, tipoDia: tipoDia));

  /// Siempre desde la API: un aviso de suspensión guardado podría estar vencido o
  /// faltar uno nuevo.
  @override
  Future<List<Aviso>> avisos({String? rutaId, String? embarcaderoId}) =>
      _api.avisos(rutaId: rutaId, embarcaderoId: embarcaderoId);

  /// Primero la API. Sin conexión (o con el servidor caído) se calcula en el
  /// teléfono con la ruta, los horarios y los festivos guardados; si falta alguno,
  /// se muestra el error en vez de inventar una hora.
  @override
  Future<Fetched<ProximaSalida>> proximaSalida(
    String rutaId,
    Sentido sentido, {
    String? desdeEmbarcaderoId,
  }) async {
    try {
      final p = await _api.proximaSalida(rutaId, sentido, desdeEmbarcaderoId: desdeEmbarcaderoId);
      return Fetched(p, updatedAt: _now(), origin: DataOrigin.network);
    } on ApiException catch (e) {
      if (!e.allowsOfflineFallback) rethrow;
      final local = await _proximaSalidaLocal(rutaId, sentido, desdeEmbarcaderoId);
      if (local == null) rethrow;
      return Fetched(local, updatedAt: _now(), origin: DataOrigin.cache, refreshError: e);
    }
  }

  Future<ProximaSalida?> _proximaSalidaLocal(String rutaId, Sentido sentido, String? desde) async {
    final instante = _now();
    final ruta = await _readSaved(ApiEndpoint.ruta(rutaId));
    final horarios = await _readSaved(ApiEndpoint.horarios(rutaId, sentido));
    if (ruta == null || horarios == null) return null;
    final festivos = <String>{};
    for (final anio in aniosNecesarios(instante)) {
      final delAnio = await _readSaved(ApiEndpoint.festivos(anio));
      // Sin los festivos no se puede saber si hoy aplica el horario de festivo
      if (delAnio == null) return null;
      festivos.addAll(delAnio.map((f) => f.fecha));
    }
    try {
      return calcularProximaSalidaLocal(
        ruta: ruta,
        sentido: sentido,
        desdeEmbarcaderoId: desde,
        horarios: horarios.horarios,
        festivos: festivos,
        instante: instante,
      );
    } on StateError {
      return null;
    }
  }

  Future<T?> _readSaved<T>(ApiEndpoint<T> endpoint) async {
    try {
      final saved = await _cache.read(endpoint.cacheKey);
      return saved == null ? null : endpoint.parse(saved.json);
    } on Object {
      return null;
    }
  }

  /// Lo guardado hace menos de esto no se vuelve a descargar en prepareOffline.
  static const _offlineDataMaxAge = Duration(hours: 6);

  @override
  Future<void> prepareOffline({required List<String> rutaIds}) async {
    final now = _now();
    final endpoints = <ApiEndpoint<Object?>>[
      for (final id in rutaIds)
        for (final sentido in Sentido.values) ApiEndpoint.horarios(id, sentido),
      for (final anio in aniosNecesarios(now)) ApiEndpoint.festivos(anio),
    ];
    for (final endpoint in endpoints) {
      try {
        final saved = await _cache.read(endpoint.cacheKey);
        if (saved != null && now.difference(saved.updatedAt) < _offlineDataMaxAge) continue;
        await _cacheThenNetwork(endpoint).drain<void>();
      } on Object catch (e) {
        debugPrint('[cache] no se pudo preparar ${endpoint.cacheKey}: $e');
      }
    }
  }
}
