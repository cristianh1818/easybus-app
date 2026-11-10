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

Object? readFixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync());

class FakeRepository implements EasybusRepository {
  FakeRepository({
    this.embarcaderos,
    this.avisosList = const [],
    this.delay = Duration.zero,
    this.error,
    this.never = false,
  });

  /// null = los 8 embarcaderos del fixture real.
  final List<Embarcadero>? embarcaderos;
  final List<Aviso> avisosList;
  final Duration delay;

  /// Si no es null, todas las consultas fallan con este error.
  final Object? error;

  /// La consulta no termina nunca (para probar tiempos máximos).
  final bool never;

  int embarcaderosCalls = 0;

  static final updatedAt = DateTime(2026, 11, 10, 8);

  Future<T> _answer<T>(T Function() value) async {
    if (never) return Completer<T>().future;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (error != null) throw error!;
    return value();
  }

  Stream<Fetched<T>> _stream<T>(T Function() value) async* {
    final data = await _answer(value);
    yield Fetched(data, updatedAt: updatedAt, origin: DataOrigin.network);
  }

  @override
  Stream<Fetched<List<Embarcadero>>> watchEmbarcaderos() {
    embarcaderosCalls++;
    return _stream(() => embarcaderos ?? asJsonList(readFixture('embarcaderos.json'), Embarcadero.fromJson));
  }

  @override
  Future<List<Aviso>> avisos({String? rutaId, String? embarcaderoId}) => _answer(() => avisosList);

  @override
  Stream<Fetched<EmbarcaderoDetalle>> watchEmbarcadero(String id) =>
      _stream(() => EmbarcaderoDetalle.fromJson(asJsonMap(readFixture('embarcadero_detalle.json'))));

  @override
  Stream<Fetched<List<Ruta>>> watchRutas() =>
      _stream(() => asJsonList(readFixture('rutas.json'), Ruta.fromJson));

  @override
  Stream<Fetched<RutaDetalle>> watchRuta(String id) =>
      _stream(() => RutaDetalle.fromJson(asJsonMap(readFixture('ruta_detalle.json'))));

  @override
  Stream<Fetched<HorariosSentido>> watchHorarios(String rutaId, Sentido sentido, {TipoDia? tipoDia}) =>
      _stream(() => HorariosSentido.fromJson(asJsonMap(readFixture('horarios.json'))));

  @override
  Future<ProximaSalida> proximaSalida(String rutaId, Sentido sentido, {String? desdeEmbarcaderoId}) =>
      _answer(() => ProximaSalida.fromJson(asJsonMap(readFixture('proxima_salida_next.json'))));
}
