// Cuenta del pasajero (opcional: consultar rutas nunca exige sesión).
// POST /auth/login y /auth/register devuelven { accessToken, expiresIn, usuario }.
// GET /usuarios/me/favoritos devuelve { rutas: […], embarcaderos: […] }.

import 'package:flutter/foundation.dart';

import 'geo.dart';
import 'json.dart';

@immutable
class UsuarioCuenta {
  const UsuarioCuenta({required this.id, required this.nombre, required this.correo});

  final String id;
  final String nombre;
  final String correo;

  factory UsuarioCuenta.fromJson(JsonMap json) =>
      UsuarioCuenta(id: json.str('id'), nombre: json.str('nombre'), correo: json.str('correo'));

  Map<String, Object?> toJson() => {'id': id, 'nombre': nombre, 'correo': correo};
}

/// Sesión iniciada. El token se guarda solo en el almacenamiento seguro del
/// teléfono (flutter_secure_storage), nunca en la caché ni en el registro.
@immutable
class Sesion {
  const Sesion({required this.token, required this.venceEn, required this.usuario});

  final String token;
  final DateTime venceEn;
  final UsuarioCuenta usuario;

  bool vencida(DateTime ahora) => !ahora.isBefore(venceEn);

  factory Sesion.fromLogin(JsonMap json, DateTime ahora) => Sesion(
    token: json.str('accessToken'),
    // Un minuto de margen para no usar un token a punto de vencer
    venceEn: ahora.add(Duration(seconds: (json.integerOrNull('expiresIn') ?? 3600) - 60)),
    usuario: UsuarioCuenta.fromJson(json.obj('usuario')),
  );

  factory Sesion.fromJson(JsonMap json) => Sesion(
    token: json.str('token'),
    venceEn: json.date('venceEn'),
    usuario: UsuarioCuenta.fromJson(json.obj('usuario')),
  );

  Map<String, Object?> toJson() => {
    'token': token,
    'venceEn': venceEn.toUtc().toIso8601String(),
    'usuario': usuario.toJson(),
  };
}

@immutable
class RutaFavorita {
  const RutaFavorita({required this.id, required this.codigo, required this.nombre});

  final String id;
  final String codigo;
  final String nombre;

  factory RutaFavorita.fromJson(JsonMap json) =>
      RutaFavorita(id: json.str('id'), codigo: json.str('codigo'), nombre: json.str('nombre'));
}

@immutable
class EmbarcaderoFavorito {
  const EmbarcaderoFavorito({
    required this.id,
    required this.nombre,
    required this.referencia,
    required this.ubicacion,
  });

  final String id;
  final String nombre;
  final String? referencia;
  final GeoPoint ubicacion;

  factory EmbarcaderoFavorito.fromJson(JsonMap json) => EmbarcaderoFavorito(
    id: json.str('id'),
    nombre: json.str('nombre'),
    referencia: json.strOrNull('referencia'),
    ubicacion: GeoPoint(json.number('latitud'), json.number('longitud')),
  );
}

@immutable
class Favoritos {
  const Favoritos({required this.rutas, required this.embarcaderos});

  static const vacio = Favoritos(rutas: [], embarcaderos: []);

  final List<RutaFavorita> rutas;
  final List<EmbarcaderoFavorito> embarcaderos;

  bool tieneRuta(String id) => rutas.any((r) => r.id == id);
  bool tieneEmbarcadero(String id) => embarcaderos.any((e) => e.id == id);

  factory Favoritos.fromJson(JsonMap json) => Favoritos(
    rutas: json.list('rutas', RutaFavorita.fromJson),
    embarcaderos: json.list('embarcaderos', EmbarcaderoFavorito.fromJson),
  );
}
