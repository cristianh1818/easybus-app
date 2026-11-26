// Cuenta del pasajero: inicio de sesión, registro y favoritos contra la API, y la
// sesión guardada en el almacenamiento seguro del teléfono (Keystore en Android,
// Keychain en iOS). El token nunca se escribe en la caché ni en el registro.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/cuenta.dart';
import '../models/json.dart';
import 'api_client.dart';

class AccountApi {
  const AccountApi(this._client);

  final ApiClient _client;

  Future<Sesion> login({required String correo, required String password, required DateTime ahora}) =>
      _client.send(
        'POST',
        '/auth/login',
        data: {'correo': correo.trim(), 'password': password},
        parse: (j) => Sesion.fromLogin(asJsonMap(j), ahora),
      );

  Future<Sesion> register({
    required String nombre,
    required String correo,
    required String password,
    required DateTime ahora,
  }) => _client.send(
    'POST',
    '/auth/register',
    data: {'nombre': nombre.trim(), 'correo': correo.trim(), 'password': password},
    parse: (j) => Sesion.fromLogin(asJsonMap(j), ahora),
  );

  Future<Favoritos> favoritos(String token) => _client.send(
    'GET',
    '/usuarios/me/favoritos',
    token: token,
    parse: (j) => Favoritos.fromJson(asJsonMap(j)),
  );

  Future<Favoritos> agregarFavorito(String token, {required String tipo, required String id}) => _client.send(
    'POST',
    '/usuarios/me/favoritos',
    token: token,
    data: {'tipo': tipo, 'id': id},
    parse: (j) => Favoritos.fromJson(asJsonMap(j)),
  );

  Future<void> quitarFavorito(String token, {required String tipo, required String id}) => _client.send(
    'DELETE',
    '/usuarios/me/favoritos/${Uri.encodeComponent(tipo)}/${Uri.encodeComponent(id)}',
    token: token,
    parse: (_) {},
  );
}

/// Sesión guardada en el almacenamiento seguro.
class SessionStore {
  SessionStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'easybus_sesion';

  Future<Sesion?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      return raw == null ? null : Sesion.fromJson(asJsonMap(jsonDecode(raw)));
    } on Object catch (e) {
      // Dañada o de otra versión: se descarta (el pasajero vuelve a iniciar sesión)
      debugPrint('[cuenta] no se pudo leer la sesión guardada: ${e.runtimeType}');
      await clear();
      return null;
    }
  }

  Future<void> write(Sesion sesion) => _storage.write(key: _key, value: jsonEncode(sesion.toJson()));

  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // Nada que borrar
    }
  }
}
