// Lectura segura de JSON para los fromJson escritos a mano. Si un campo falta o
// trae otro tipo, lanza FormatException con el nombre del campo, y el ApiClient lo
// convierte en RESPUESTA_INVALIDA.

typedef JsonMap = Map<String, Object?>;

JsonMap asJsonMap(Object? value, [String what = 'respuesta']) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('Se esperaba un objeto en "$what"', value);
}

List<T> asJsonList<T>(Object? value, T Function(JsonMap json) fromJson, [String what = 'respuesta']) {
  if (value is! List) throw FormatException('Se esperaba una lista en "$what"', value);
  return [for (final item in value) fromJson(asJsonMap(item, what))];
}

extension JsonRead on JsonMap {
  Never _bad(String key, String expected) =>
      throw FormatException('Campo "$key": se esperaba $expected', this[key]);

  String str(String key) {
    final v = this[key];
    return v is String ? v : _bad(key, 'texto');
  }

  String? strOrNull(String key) {
    final v = this[key];
    return v == null || v is String ? v as String? : _bad(key, 'texto o null');
  }

  int integer(String key) {
    final v = this[key];
    return v is num ? v.toInt() : _bad(key, 'número');
  }

  int? integerOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    return v is num ? v.toInt() : _bad(key, 'número o null');
  }

  double number(String key) {
    final v = this[key];
    return v is num ? v.toDouble() : _bad(key, 'número');
  }

  bool boolean(String key) {
    final v = this[key];
    return v is bool ? v : _bad(key, 'true/false');
  }

  bool? booleanOrNull(String key) {
    final v = this[key];
    return v == null || v is bool ? v as bool? : _bad(key, 'true/false o null');
  }

  DateTime date(String key) => DateTime.tryParse(str(key)) ?? _bad(key, 'fecha ISO-8601');

  DateTime? dateOrNull(String key) {
    final s = strOrNull(key);
    if (s == null) return null;
    return DateTime.tryParse(s) ?? _bad(key, 'fecha ISO-8601 o null');
  }

  JsonMap obj(String key) => asJsonMap(this[key], key);

  JsonMap? objOrNull(String key) => this[key] == null ? null : asJsonMap(this[key], key);

  List<T> list<T>(String key, T Function(JsonMap json) fromJson) => asJsonList(this[key], fromJson, key);

  /// Enum de la API: [values] con su valor en `apiValue`. Si llega un valor nuevo que
  /// la app aún no conoce, se usa [fallback] en vez de fallar.
  T enumValue<T extends ApiEnum>(String key, List<T> values, T fallback) =>
      enumFromApi(values, strOrNull(key), fallback);

  T? enumOrNull<T extends ApiEnum>(String key, List<T> values) {
    final raw = strOrNull(key);
    if (raw == null) return null;
    for (final v in values) {
      if (v.apiValue == raw) return v;
    }
    return null;
  }
}

/// Enum cuyo valor en la API es [apiValue].
abstract interface class ApiEnum {
  String get apiValue;
}

T enumFromApi<T extends ApiEnum>(List<T> values, String? raw, T fallback) {
  for (final v in values) {
    if (v.apiValue == raw) return v;
  }
  return fallback;
}
