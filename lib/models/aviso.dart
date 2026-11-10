// Aviso de servicio (GET /avisos y dentro de GET /rutas/{id}). Suspensión por
// nivel del río, retrasos, cambios de horario o información general.

import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

@immutable
class Aviso {
  const Aviso({
    required this.id,
    required this.tipo,
    required this.motivo,
    required this.titulo,
    required this.mensaje,
    required this.alcance,
    required this.ruta,
    required this.embarcadero,
    required this.vigenteDesde,
    required this.vigenteHasta,
    required this.vigencia,
    required this.actualizadoEn,
  });

  final String id;
  final TipoAviso tipo;
  final MotivoAviso motivo;
  final String titulo;
  final String mensaje;
  final AlcanceAviso alcance;

  /// Ruta afectada (null si el aviso es general o solo de un embarcadero).
  final AvisoRuta? ruta;

  /// Embarcadero afectado (null si el aviso es general o de toda la ruta).
  final AvisoEmbarcadero? embarcadero;
  final DateTime vigenteDesde;

  /// null = hasta que un administrador lo cierre.
  final DateTime? vigenteHasta;
  final VigenciaAviso vigencia;
  final DateTime actualizadoEn;

  bool get esSuspension => tipo == TipoAviso.suspendido;

  factory Aviso.fromJson(JsonMap json) {
    final ruta = json.objOrNull('ruta');
    final embarcadero = json.objOrNull('embarcadero');
    return Aviso(
      id: json.str('id'),
      // Un tipo nuevo que la app no conoce se muestra como informativo: el banner
      // aparece igual con su título y mensaje.
      tipo: json.enumValue('tipo', TipoAviso.values, TipoAviso.informativo),
      motivo: json.enumValue('motivo', MotivoAviso.values, MotivoAviso.otro),
      titulo: json.str('titulo'),
      mensaje: json.str('mensaje'),
      alcance: json.enumValue('alcance', AlcanceAviso.values, AlcanceAviso.general),
      ruta: ruta == null ? null : AvisoRuta.fromJson(ruta),
      embarcadero: embarcadero == null ? null : AvisoEmbarcadero.fromJson(embarcadero),
      vigenteDesde: json.date('vigenteDesde'),
      vigenteHasta: json.dateOrNull('vigenteHasta'),
      vigencia: json.enumValue('vigencia', VigenciaAviso.values, VigenciaAviso.vigente),
      actualizadoEn: json.date('actualizadoEn'),
    );
  }
}

@immutable
class AvisoRuta {
  const AvisoRuta({required this.id, required this.codigo, required this.nombre});

  final String id;
  final String codigo;
  final String nombre;

  factory AvisoRuta.fromJson(JsonMap json) =>
      AvisoRuta(id: json.str('id'), codigo: json.str('codigo'), nombre: json.str('nombre'));
}

@immutable
class AvisoEmbarcadero {
  const AvisoEmbarcadero({required this.id, required this.nombre});

  final String id;
  final String nombre;

  factory AvisoEmbarcadero.fromJson(JsonMap json) =>
      AvisoEmbarcadero(id: json.str('id'), nombre: json.str('nombre'));
}
