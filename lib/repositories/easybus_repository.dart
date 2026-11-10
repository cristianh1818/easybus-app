// Fuente de datos de las pantallas. Hoy solo llama a la API; en el paso de caché
// offline se agrega otra implementación (caché + API) y las pantallas no cambian.
//
// Los métodos watch* devuelven un Stream: hoy emite una vez (la respuesta de la API);
// con caché emitirá primero lo guardado en el teléfono y luego lo actualizado.
// Avisos y próxima salida siempre van a la API: un aviso de suspensión desactualizado
// o una hora calculada con otro reloj serían engañosos.

import '../models/aviso.dart';
import '../models/embarcadero.dart';
import '../models/enums.dart';
import '../models/horario.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';
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

  /// Siempre desde la API.
  Future<ProximaSalida> proximaSalida(String rutaId, Sentido sentido, {String? desdeEmbarcaderoId});
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
  Future<ProximaSalida> proximaSalida(String rutaId, Sentido sentido, {String? desdeEmbarcaderoId}) =>
      _api.proximaSalida(rutaId, sentido, desdeEmbarcaderoId: desdeEmbarcaderoId);
}
