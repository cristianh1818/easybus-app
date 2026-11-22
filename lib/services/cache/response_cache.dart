// Caché de respuestas de la API sobre SQLite (drift).

import 'dart:convert';

import 'app_database.dart';

/// Versión del formato de los modelos. Subirla cuando un fromJson deje de entender
/// respuestas guardadas antes: esas filas se ignoran y se vuelven a descargar.
const cacheFormatVersion = 1;

class CachedResponse {
  const CachedResponse(this.json, this.updatedAt);

  final Object? json;
  final DateTime updatedAt;
}

class ResponseCache {
  ResponseCache(this._db);

  final AppDatabase _db;

  Future<CachedResponse?> read(String key) async {
    final row = await (_db.select(_db.cacheEntries)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null || row.formatVersion != cacheFormatVersion) return null;
    try {
      return CachedResponse(
        jsonDecode(row.json),
        DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true).toLocal(),
      );
    } on FormatException {
      await remove(key);
      return null;
    }
  }

  Future<void> write(String key, Object? json, DateTime updatedAt) => _db
      .into(_db.cacheEntries)
      .insertOnConflictUpdate(
        CacheEntriesCompanion.insert(
          key: key,
          json: jsonEncode(json),
          updatedAt: updatedAt.toUtc().millisecondsSinceEpoch,
          formatVersion: cacheFormatVersion,
        ),
      );

  Future<void> remove(String key) => (_db.delete(_db.cacheEntries)..where((t) => t.key.equals(key))).go();

  /// Borra todo lo guardado.
  Future<void> clear() => _db.delete(_db.cacheEntries).go();
}
