// "Tus últimas consultas": rutas y embarcaderos abiertos, guardados SOLO en el
// teléfono (no necesita cuenta y nunca se envía a la API).

import 'package:flutter/foundation.dart';

import '../models/json.dart';

/// Cuántas consultas se guardan.
const maxHistorial = 10;

enum TipoConsulta { ruta, embarcadero }

@immutable
class Consulta {
  const Consulta({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.cuando,
    this.detalle,
  });

  final TipoConsulta tipo;
  final String id;

  /// "Ruta BS-1" o el nombre del embarcadero.
  final String titulo;
  final String? detalle;
  final DateTime cuando;

  factory Consulta.fromJson(JsonMap json) => Consulta(
    tipo: json.str('tipo') == 'ruta' ? TipoConsulta.ruta : TipoConsulta.embarcadero,
    id: json.str('id'),
    titulo: json.str('titulo'),
    detalle: json.strOrNull('detalle'),
    cuando: json.date('cuando'),
  );

  Map<String, Object?> toJson() => {
    'tipo': tipo.name,
    'id': id,
    'titulo': titulo,
    'detalle': detalle,
    'cuando': cuando.toUtc().toIso8601String(),
  };
}

/// Agrega [nueva] al principio, sin repetir la misma ruta o embarcadero, y deja
/// como máximo [maxHistorial].
List<Consulta> agregarConsulta(List<Consulta> historial, Consulta nueva) =>
    [nueva, ...historial.where((c) => c.tipo != nueva.tipo || c.id != nueva.id)].take(maxHistorial).toList();
