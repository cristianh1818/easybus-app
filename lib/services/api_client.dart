// Cliente HTTP de la API de EASYBUS (dio). Solo sabe hacer peticiones y convertir
// cualquier fallo en ApiException; los endpoints con tipos van en easybus_api.dart.
//
// Privacidad (RNF-07): la ubicación del usuario nunca se envía al servidor. El
// "cerca de mí" se calcula en el teléfono con la lista de /embarcaderos, por eso
// este cliente no expone /embarcaderos/cercanos.

import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exception.dart';

/// Convierte el JSON ya decodificado en el modelo.
typedef JsonParser<T> = T Function(Object? json);

class ApiClient {
  ApiClient({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              sendTimeout: const Duration(seconds: 10),
              responseType: ResponseType.json,
              headers: {Headers.acceptHeader: Headers.jsonContentType},
            ),
          ) {
    _dio.options.baseUrl = baseUrl;
    if (kDebugMode) _dio.interceptors.add(_DebugLog());
  }

  final Dio _dio;

  String get baseUrl => _dio.options.baseUrl;

  /// GET a [path] (siempre empieza con "/", p. ej. "/rutas") y convierte la
  /// respuesta con [parse]. Los parámetros nulos de [query] no se envían.
  Future<T> get<T>(
    String path, {
    Map<String, Object?>? query,
    required JsonParser<T> parse,
    CancelToken? cancelToken,
  }) async {
    assert(path.startsWith('/'), 'La ruta debe empezar con "/": $path');
    final Response<Object?> response;
    try {
      response = await _dio.get<Object?>(
        path,
        queryParameters: _withoutNulls(query),
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }

    try {
      return parse(response.data);
    } on Object catch (e) {
      // FormatException, TypeError (un campo con otro tipo), etc.
      debugPrint('[api] respuesta inesperada en $path: $e');
      throw const ApiException(
        kind: ApiErrorKind.invalidResponse,
        code: 'RESPUESTA_INVALIDA',
        message: 'La respuesta del servidor no tiene el formato esperado. Intenta más tarde.',
      );
    }
  }

  void close() => _dio.close();

  static Map<String, Object?>? _withoutNulls(Map<String, Object?>? query) {
    if (query == null) return null;
    return {
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value,
    };
  }

  /// Traduce un DioException al error único de la app.
  @visibleForTesting
  static ApiException mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          kind: ApiErrorKind.timeout,
          code: 'TIEMPO_AGOTADO',
          message: 'El servidor está tardando demasiado en responder. Intenta de nuevo.',
        );
      case DioExceptionType.connectionError:
        return _noConnection;
      case DioExceptionType.badCertificate:
        return const ApiException(
          kind: ApiErrorKind.insecure,
          code: 'CONEXION_INSEGURA',
          message: 'No se pudo verificar la conexión segura con el servidor.',
        );
      case DioExceptionType.cancel:
        return const ApiException(
          kind: ApiErrorKind.cancelled,
          code: 'CANCELADA',
          message: 'La consulta se canceló.',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      case DioExceptionType.unknown:
        if (e.error is SocketException) return _noConnection;
        return const ApiException(
          kind: ApiErrorKind.unknown,
          code: 'ERROR_DESCONOCIDO',
          message: 'Ocurrió un error inesperado. Intenta de nuevo.',
        );
    }
  }

  static const _noConnection = ApiException(
    kind: ApiErrorKind.noConnection,
    code: 'SIN_CONEXION',
    message: 'No hay conexión con EASYBUS. Revisa tu internet e intenta de nuevo.',
  );

  // Errores de la API: { statusCode, code, message, errores? }. Si el cuerpo no tiene
  // esa forma (p. ej. una página HTML de Nginx con un 502), se usa un mensaje genérico.
  static ApiException _fromResponse(Response<Object?>? response) {
    final status = response?.statusCode;
    final isServer = status == null || status >= 500 || status == 429;
    final kind = isServer ? ApiErrorKind.server : ApiErrorKind.client;
    final body = response?.data;

    if (body is Map && body['code'] is String && body['message'] is String) {
      final errores = body['errores'];
      return ApiException(
        kind: kind,
        statusCode: status,
        code: body['code'] as String,
        message: body['message'] as String,
        errors: errores is List ? errores.whereType<String>().toList() : const [],
      );
    }

    final (code, message) = switch (status) {
      404 => ('NO_ENCONTRADO', 'No encontramos la información solicitada.'),
      429 => (
        'DEMASIADAS_SOLICITUDES',
        'Hiciste muchas consultas seguidas. Espera un momento e intenta de nuevo.',
      ),
      final s? when s >= 500 => (
        'SERVICIO_NO_DISPONIBLE',
        'El servicio no está disponible en este momento. Intenta más tarde.',
      ),
      _ => ('ERROR_DESCONOCIDO', 'Ocurrió un error inesperado. Intenta de nuevo.'),
    };
    return ApiException(kind: kind, statusCode: status, code: code, message: message);
  }
}

/// Log de depuración de una línea por petición: "GET /rutas → 200 (45 ms)".
/// Nunca imprime cabeceras (tokens) ni cuerpos (datos del usuario).
class _DebugLog extends Interceptor {
  static const _start = 'eb_start';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_start] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log(response.requestOptions, '${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions, '${err.response?.statusCode ?? err.type.name}');
    handler.next(err);
  }

  void _log(RequestOptions o, String result) {
    final start = o.extra[_start];
    final ms = start is DateTime ? DateTime.now().difference(start).inMilliseconds : null;
    debugPrint(
      '[api] ${o.method} ${o.uri.path}${o.uri.hasQuery ? '?${o.uri.query}' : ''} → $result'
      '${ms == null ? '' : ' ($ms ms)'}',
    );
  }
}
