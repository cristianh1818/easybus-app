// Festivo de Colombia (GET /festivos?anio=): ese día aplica el horario de
// domingo/festivo.

import 'package:flutter/foundation.dart';

import 'json.dart';

@immutable
class Festivo {
  const Festivo({required this.fecha, required this.nombre});

  /// "AAAA-MM-DD" (fecha local de Montería).
  final String fecha;
  final String nombre;

  factory Festivo.fromJson(JsonMap json) {
    final fecha = json.str('fecha');
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fecha)) {
      throw FormatException('Campo "fecha": se esperaba "AAAA-MM-DD"', fecha);
    }
    return Festivo(fecha: fecha, nombre: json.str('nombre'));
  }
}
