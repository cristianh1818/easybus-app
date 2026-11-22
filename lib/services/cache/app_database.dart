// Base SQLite local (drift) para la caché offline.
//
// Guarda cada respuesta de la API tal como llegó (JSON), una fila por consulta:
// "embarcaderos", "rutas", "ruta/{id}", "horarios/{rutaId}/{sentido}/{tipoDia}"…
// Así no se duplica el esquema de los modelos en SQLite: al leer se usan los mismos
// fromJson que con la red. Solo datos públicos: nada personal ni la ubicación.

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class CacheEntries extends Table {
  /// Consulta a la que corresponde la respuesta.
  TextColumn get key => text()();

  /// Respuesta de la API, sin cambios.
  TextColumn get json => text()();

  /// Cuándo se descargó (milisegundos UTC).
  IntColumn get updatedAt => integer()();

  /// Formato de los modelos con que se guardó: si cambia, la fila se ignora.
  IntColumn get formatVersion => integer()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [CacheEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'easybus_cache'));

  @override
  int get schemaVersion => 1;
}
