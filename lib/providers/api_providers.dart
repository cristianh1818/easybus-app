import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../services/api_client.dart';

/// Cliente único de la API. En las pruebas se reemplaza con overrideWithValue.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});
