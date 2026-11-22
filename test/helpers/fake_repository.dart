// Repository falso para pruebas de pantallas: datos de los fixtures reales, con
// retraso o error configurables.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:easybus_app/models/aviso.dart';
import 'package:easybus_app/models/embarcadero.dart';
import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/models/horario.dart';
import 'package:easybus_app/models/json.dart';
import 'package:easybus_app/models/proxima_salida.dart';
import 'package:easybus_app/models/ruta.dart';
import 'package:easybus_app/repositories/easybus_repository.dart';
import 'package:easybus_app/repositories/fetched.dart';
import 'package:easybus_app/services/api_exception.dart';

Object? readFixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

class FakeRepository implements EasybusRepository {
  FakeRepository({
    this.embarcaderos,
    this.avisosList = const [],
    this.delay = Duration.zero,
    this.error,
    this.never = false,
    this.avisosError,
    this.rutasError,
    this.proximaSalidaFixture = 'proxima_salida_next.json',
    this.staleError,
  });

  /// null = los 8 embarcaderos del fixture real.
  List<Embarcadero>? embarcaderos;
  final List<Aviso> avisosList;
  final Duration delay;

  /// Si no es null, todas las consultas fallan con este error (se puede quitar para
  /// probar "Reintentar").
  Object? error;

  /// La consulta no termina nunca (para probar tiempos máximos).
  final bool never;

  /// Falla solo la consulta de avisos.
  Object? avisosError;

  /// Fallan solo las rutas (la lista de embarcaderos sí carga).
  Object? rutasError;

  /// Si no es null, los datos llegan "de la caché" con este error (sin conexión).
  ApiException? staleError;

  /// Respuesta de /proxima-salida que se devuelve (fixture).
  String proximaSalidaFixture;

  int embarcaderosCalls = 0;
  int proximaSalidaCalls = 0;

  static final updatedAt = DateTime(2026, 11, 10, 8);

  Future<T> _answer<T>(T Function() value, {Object? failWith}) async {
    if (never) return Completer<T>().future;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    final e = error ?? failWith;
    if (e != null) throw e;
    return value();
  }

  Stream<Fetched<T>> _stream<T>(T Function() value, {Object? failWith}) async* {
    final data = await _answer(value, failWith: failWith);
    yield staleError == null
        ? Fetched(data, updatedAt: updatedAt, origin: DataOrigin.network)
        : Fetched(data, updatedAt: updatedAt, origin: DataOrigin.cache, refreshError: staleError);
  }

  @override
  Stream<Fetched<List<Embarcadero>>> watchEmbarcaderos() {
    embarcaderosCalls++;
    return _stream(() => embarcaderos ?? asJsonList(readFixture('embarcaderos.json'), Embarcadero.fromJson));
  }

  @override
  Future<List<Aviso>> avisos({String? rutaId, String? embarcaderoId}) =>
      _answer(() => avisosList, failWith: avisosError);

  @override
  Stream<Fetched<EmbarcaderoDetalle>> watchEmbarcadero(String id) =>
      _stream(() => EmbarcaderoDetalle.fromJson(asJsonMap(readFixture('embarcadero_detalle.json'))));

  @override
  Stream<Fetched<List<Ruta>>> watchRutas() =>
      _stream(() => asJsonList(readFixture('rutas.json'), Ruta.fromJson), failWith: rutasError);

  @override
  Stream<Fetched<RutaDetalle>> watchRuta(String id) =>
      _stream(() => RutaDetalle.fromJson(asJsonMap(readFixture('ruta_detalle.json'))));

  @override
  Stream<Fetched<HorariosSentido>> watchHorarios(String rutaId, Sentido sentido, {TipoDia? tipoDia}) =>
      _stream(() => HorariosSentido.fromJson(asJsonMap(readFixture('horarios.json'))));

  @override
  Future<ProximaSalida> proximaSalida(String rutaId, Sentido sentido, {String? desdeEmbarcaderoId}) {
    proximaSalidaCalls++;
    return _answer(() => ProximaSalida.fromJson(asJsonMap(readFixture(proximaSalidaFixture))));
  }
}
