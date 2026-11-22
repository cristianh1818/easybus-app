// Cliente HTTP de la API de EASYBUS (dio). Solo sabe hacer peticiones y convertir
// cualquier fallo en ApiException; los endpoints con tipos van en easybus_api.dart.
//
// Privacidad (RNF-07): la ubicación del usuario nunca se envía al servidor. El
// "cerca de mí" se calcula en el teléfono con la lista de /embarcaderos, por eso
// este cliente no expone /embarcaderos/cercanos.

import 'dart:io' show HttpClient, HttpException, SocketException;

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
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
    if (dio == null) {
      // El servidor (Node) cierra las conexiones inactivas a los 5 s ("Keep-Alive:
      // timeout=5"), pero Dart las reutiliza hasta 15 s. A través de adb reverse (y en
      // algunas redes móviles) el teléfono no se entera del cierre y la siguiente
      // consulta sale por una conexión muerta. Se descartan antes: a los 3 s.
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () => HttpClient()..idleTimeout = const Duration(seconds: 3),
      );
    }
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
    Future<Response<Object?>> send() =>
        _dio.get<Object?>(path, queryParameters: _withoutNulls(query), cancelToken: cancelToken);
    Response<Object?> response;
    try {
      try {
        response = await send();
      } on DioException catch (e) {
        // Conexión reutilizada que el servidor ya había cerrado: un GET se puede
        // repetir sin riesgo, una sola vez y con una conexión nueva.
        if (!isBrokenConnection(e)) rethrow;
        debugPrint('[api] conexión cortada en $path; se reintenta una vez');
        response = await send();
      }
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

  /// La conexión se cortó a mitad de la consulta (no es "sin internet" ni un error
  /// del servidor): típico de una conexión keep-alive que el servidor ya cerró.
  @visibleForTesting
  static bool isBrokenConnection(DioException e) {
    final error = e.error;
    if (error is HttpException) return true; // "Connection closed before full header…"
    if (error is SocketException) {
      final code = error.osError?.errorCode;
      final text = error.message.toLowerCase();
      return const {104, 54, 10054, 32}.contains(code) ||
          text.contains('reset') ||
          text.contains('broken pipe');
    }
    return false;
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
        return _fromConnectionError(e.error);
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
        if (e.error is SocketException || e.error is HttpException) return _fromConnectionError(e.error);
        return const ApiException(
          kind: ApiErrorKind.unknown,
          code: 'ERROR_DESCONOCIDO',
          message: 'Ocurrió un error inesperado. Intenta de nuevo.',
        );
    }
  }

  /// El teléfono no llega a la red (sin datos ni Wi-Fi, DNS que no responde…).
  static const noInternet = ApiException(
    kind: ApiErrorKind.noConnection,
    code: 'SIN_CONEXION',
    message: 'Sin conexión a internet. Revisa tus datos o tu Wi-Fi e intenta de nuevo.',
  );

  /// Hay red, pero el servidor de EASYBUS rechaza o corta la conexión (caído,
  /// reiniciándose…). Mismo texto que un 5xx.
  static const serviceUnavailable = ApiException(
    kind: ApiErrorKind.server,
    code: 'SERVICIO_NO_DISPONIBLE',
    message: 'El servicio no está disponible en este momento. Intenta más tarde.',
  );

  // Códigos del sistema para "conexión rechazada" y "conexión cortada" en Android,
  // iOS/macOS, Linux y Windows: el equipo del servidor respondió, así que sí hay red.
  static const _refusedOrReset = {111, 104, 61, 54, 10061, 10054, 1225, 1236};

  static ApiException _fromConnectionError(Object? error) {
    if (error is SocketException) {
      final code = error.osError?.errorCode;
      final text = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
      if (_refusedOrReset.contains(code) || text.contains('refused') || text.contains('reset')) {
        return serviceUnavailable;
      }
      return noInternet;
    }
    // "Connection closed before full header was received": el servidor cortó
    if (error is HttpException) return serviceUnavailable;
    return noInternet;
  }

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
