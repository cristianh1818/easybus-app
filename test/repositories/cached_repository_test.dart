import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/models/proxima_salida.dart';
import 'package:easybus_app/repositories/easybus_repository.dart';
import 'package:easybus_app/repositories/fetched.dart';
import 'package:easybus_app/services/api_client.dart';
import 'package:easybus_app/services/api_exception.dart';
import 'package:easybus_app/services/cache/app_database.dart';
import 'package:easybus_app/services/cache/response_cache.dart';
import 'package:easybus_app/services/easybus_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// API falsa: responde con fixtures o simula "sin conexión".
class _Adapter implements HttpClientAdapter {
  bool offline = false;
  int calls = 0;
  final requested = <String>[];

  /// Responder 404 (error del cliente: no se debe calcular nada localmente).
  bool notFound = false;

  static const _files = {
    '/api/v1/embarcaderos': 'embarcaderos.json',
    '/api/v1/rutas': 'rutas.json',
    '/api/v1/avisos': 'avisos_sintetico.json',
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    calls++;
    requested.add(o.uri.toString());
    if (offline) throw DioException.connectionError(requestOptions: o, reason: 'sin red');
    if (notFound) {
      return ResponseBody.fromString(
        '{"statusCode":404,"code":"NO_ENCONTRADO","message":"Ruta no encontrada"}',
        404,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    final file = _fileFor(o.uri) ?? (throw StateError('Sin fixture para ${o.uri}'));
    return ResponseBody.fromString(
      File('test/fixtures/$file').readAsStringSync(),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  static String? _fileFor(Uri uri) {
    final path = uri.path;
    if (_files[path] case final f?) return f;
    if (path == '/api/v1/festivos') {
      return uri.queryParameters['anio'] == '2026' ? 'comparacion_festivos_2026.json' : 'vacio.json';
    }
    if (path.endsWith('/horarios')) return 'comparacion_horarios_${uri.queryParameters['sentido']}.json';
    if (path.endsWith('/proxima-salida')) return 'proxima_salida_next.json';
    if (path.startsWith('/api/v1/rutas/')) return 'comparacion_ruta_detalle.json';
    return null;
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AppDatabase db;
  late ResponseCache cache;
  late _Adapter adapter;
  late CachedEasybusRepository repo;
  var now = DateTime(2026, 11, 10, 8);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    cache = ResponseCache(db);
    adapter = _Adapter();
    final api = EasybusApi(ApiClient(baseUrl: 'http://x/api/v1', dio: Dio()..httpClientAdapter = adapter));
    now = DateTime(2026, 11, 10, 8);
    repo = CachedEasybusRepository(api, cache, now: () => now);
  });
  tearDown(() => db.close());

  test('Primera vez (sin caché): emite la respuesta de la red y la guarda', () async {
    final events = await repo.watchEmbarcaderos().toList();
    expect(events, hasLength(1));
    expect(events.single.origin, DataOrigin.network);
    expect(events.single.data, hasLength(8));
    expect(await cache.read('embarcaderos/todos'), isNotNull);
  });

  test('Con caché: primero lo guardado (al instante) y luego lo actualizado', () async {
    await repo.watchEmbarcaderos().toList(); // guarda a las 08:00
    now = DateTime(2026, 11, 10, 9);

    final events = await repo.watchEmbarcaderos().toList();
    expect(events.map((e) => e.origin), [DataOrigin.cache, DataOrigin.network]);
    expect(events.first.updatedAt, DateTime(2026, 11, 10, 8));
    expect(events.first.data, hasLength(8), reason: 'El JSON guardado se convierte con el mismo fromJson');
    expect(events.last.updatedAt, DateTime(2026, 11, 10, 9));
  });

  test('Sin conexión con caché: muestra lo guardado marcado como "sin conexión"', () async {
    await repo.watchEmbarcaderos().toList();
    adapter.offline = true;

    final events = await repo.watchEmbarcaderos().toList();
    expect(events, hasLength(2));
    expect(events.last.origin, DataOrigin.cache);
    expect(events.last.isStale, isTrue);
    expect(events.last.refreshError!.isOffline, isTrue);
    expect(events.last.updatedAt, DateTime(2026, 11, 10, 8));
  });

  test('Sin conexión y sin caché: el error llega a la pantalla', () async {
    adapter.offline = true;
    await expectLater(
      repo.watchEmbarcaderos().toList(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'SIN_CONEXION')),
    );
  });

  test('Una fila de otro formato o dañada se ignora y se vuelve a descargar', () async {
    await db
        .into(db.cacheEntries)
        .insert(
          CacheEntriesCompanion.insert(
            key: 'rutas',
            json: '{"esto": "no es una lista"}',
            updatedAt: 0,
            formatVersion: cacheFormatVersion,
          ),
        );
    final events = await repo.watchRutas().toList();
    expect(events.map((e) => e.origin), [DataOrigin.network], reason: 'La fila dañada no se muestra');
    expect(events.single.data.single.codigo, 'BS-1');

    await (db.update(db.cacheEntries)..where((t) => t.key.equals('rutas'))).write(
      const CacheEntriesCompanion(formatVersion: Value(cacheFormatVersion - 1)),
    );
    expect(await cache.read('rutas'), isNull, reason: 'Formato anterior: se ignora');
  });

  test('Los avisos nunca se guardan: sin conexión no se muestran avisos viejos', () async {
    expect(await repo.avisos(), hasLength(3));
    adapter.offline = true;
    await expectLater(repo.avisos(), throwsA(isA<ApiException>()));
    final rows = await db.select(db.cacheEntries).get();
    expect(rows.where((r) => r.key.startsWith('avisos')), isEmpty);
  });

  test('Borrar la caché', () async {
    await repo.watchEmbarcaderos().toList();
    await cache.clear();
    expect(await db.select(db.cacheEntries).get(), isEmpty);
  });

  group('Próxima salida sin conexión', () {
    const rutaId = '54169054-7fad-4f70-afd8-7c568855abff';
    // Lunes festivo 16/11/2026 08:00 en Montería: el backend dice 08:30 (horario de festivo)
    final lunesFestivo = DateTime.utc(2026, 11, 16, 13);

    Future<void> guardarDatos() async {
      await repo.watchRuta(rutaId).drain<void>();
      await repo.prepareOffline(rutaIds: [rutaId]);
    }

    test('Con conexión usa la API (conoce los avisos de suspensión)', () async {
      now = lunesFestivo;
      final p = await repo.proximaSalida(rutaId, Sentido.ida);
      expect(p.origin, DataOrigin.network);
      expect(adapter.requested.last, contains('/proxima-salida'));
    });

    test('Sin conexión la calcula en el teléfono, con la regla de festivos', () async {
      now = lunesFestivo;
      await guardarDatos();
      adapter.offline = true;
      final p = await repo.proximaSalida(rutaId, Sentido.ida);
      expect(p.origin, DataOrigin.cache);
      expect(p.refreshError!.isOffline, isTrue);
      expect(p.data.dayType, DayType.sundayHoliday);
      expect(p.data.departureTime, '08:30');
      expect(p.data.message, 'Próxima salida a las 08:30, en 30 min.');
    });

    test('Sin los festivos guardados no inventa una hora: muestra el error', () async {
      now = lunesFestivo;
      await repo.watchRuta(rutaId).drain<void>();
      await repo.watchHorarios(rutaId, Sentido.ida).drain<void>();
      adapter.offline = true;
      await expectLater(repo.proximaSalida(rutaId, Sentido.ida), throwsA(isA<ApiException>()));
    });

    test('Un error 4xx se muestra (no se calcula localmente)', () async {
      now = lunesFestivo;
      await guardarDatos();
      adapter.notFound = true;
      await expectLater(
        repo.proximaSalida(rutaId, Sentido.ida),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 404)),
      );
    });

    test('prepareOffline guarda horarios de ambos sentidos y festivos; no repite si es reciente', () async {
      now = lunesFestivo;
      await repo.prepareOffline(rutaIds: [rutaId]);
      for (final key in ['horarios/$rutaId/ida/todos', 'horarios/$rutaId/vuelta/todos', 'festivos/2026']) {
        expect(await cache.read(key), isNotNull, reason: key);
      }
      final antes = adapter.calls;
      now = lunesFestivo.add(const Duration(hours: 1));
      await repo.prepareOffline(rutaIds: [rutaId]);
      expect(adapter.calls, antes, reason: 'Menos de 6 h: no vuelve a descargar');
    });

    test('prepareOffline sin conexión no falla', () async {
      adapter.offline = true;
      await repo.prepareOffline(rutaIds: [rutaId]);
    });
  });
}
