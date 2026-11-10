import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';
import '../services/easybus_api.dart';

/// Cliente único de la API. En las pruebas se reemplaza con overrideWithValue.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});

/// Endpoints con tipos. Las pantallas y providers de datos usan este, no el cliente.
final easybusApiProvider = Provider<EasybusApi>((ref) => EasybusApi(ref.watch(apiClientProvider)));
