import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cache/app_database.dart';
import '../services/cache/response_cache.dart';

/// Base SQLite de la caché offline (una sola en toda la app). En las pruebas se
/// reemplaza por una en memoria.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final responseCacheProvider = Provider<ResponseCache>((ref) => ResponseCache(ref.watch(appDatabaseProvider)));
