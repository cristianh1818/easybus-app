// GET /rutas/{id}/horarios?sentido=&tipoDia=: salidas desde el origen del sentido.

import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

@immutable
class HorariosSentido {
  const HorariosSentido({
    required this.rutaId,
    required this.sentido,
    required this.destino,
    required this.actualizadoEn,
    required this.horarios,
  });

  final String rutaId;
  final Sentido sentido;
  final String destino;
  final DateTime actualizadoEn;

  /// Salidas desde el embarcadero de origen, en orden.
  final List<Horario> horarios;

  factory HorariosSentido.fromJson(JsonMap json) => HorariosSentido(
    rutaId: json.str('rutaId'),
    sentido: json.enumValue('sentido', Sentido.values, Sentido.ida),
    destino: json.str('destino'),
    actualizadoEn: json.date('actualizadoEn'),
    horarios: json.list('horarios', Horario.fromJson),
  );
}

@immutable
class Horario {
  const Horario({required this.id, required this.tipoDia, required this.horaSalida});

  final String id;
  final TipoDia tipoDia;

  /// Hora local de Montería, "HH:mm" (por ejemplo "05:30").
  final String horaSalida;

  /// Minutos desde la medianoche, para ordenar y comparar.
  int get minutosDelDia {
    final [h, m] = horaSalida.split(':').take(2).map(int.parse).toList();
    return h * 60 + m;
  }

  factory Horario.fromJson(JsonMap json) {
    final hora = json.str('horaSalida');
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(hora)) {
      throw FormatException('Campo "horaSalida": se esperaba "HH:mm"', hora);
    }
    return Horario(
      id: json.str('id'),
      tipoDia: json.enumValue('tipoDia', TipoDia.values, TipoDia.laboral),
      horaSalida: hora,
    );
  }
}
