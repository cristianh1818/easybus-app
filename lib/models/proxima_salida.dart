// GET /rutas/{id}/proxima-salida?sentido=&desde=
//
// Esta respuesta usa claves en INGLÉS (status, departureTime, minutesRemaining…),
// a diferencia del resto de la API. Los campos del modelo respetan esos nombres
// tal como vienen, para que sea fácil compararlos con el JSON.
//
// Siempre es un horario PROGRAMADO (isScheduled: true), no la ubicación real de la
// embarcación. La pantalla debe mostrarlo junto con [notice].

import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json.dart';

enum DepartureStatus implements ApiEnum {
  nextDeparture('NEXT_DEPARTURE'),
  noMoreDeparturesToday('NO_MORE_DEPARTURES_TODAY'),
  outOfService('OUT_OF_SERVICE'),
  suspended('SUSPENDED'),

  /// Un estado nuevo que la app aún no conoce: se muestra solo [ProximaSalida.message].
  unknown('');

  const DepartureStatus(this.apiValue);
  @override
  final String apiValue;
}

enum DayType implements ApiEnum {
  weekday('WEEKDAY'),
  saturday('SATURDAY'),
  sundayHoliday('SUNDAY_HOLIDAY');

  const DayType(this.apiValue);
  @override
  final String apiValue;
}

@immutable
class ProximaSalida {
  const ProximaSalida({
    required this.route,
    required this.direction,
    required this.destination,
    required this.fromStop,
    required this.isScheduled,
    required this.dayType,
    required this.localDate,
    required this.localTime,
    required this.timeZone,
    required this.scheduleUpdatedAt,
    required this.notice,
    required this.alerts,
    required this.status,
    required this.message,
    this.departureTime,
    this.originDepartureTime,
    this.minutesRemaining,
    this.crossesMidnight,
    this.reason,
    this.detail,
    this.suspendedUntil,
    this.nextDayFirstDeparture,
  });

  final DepartureRoute route;
  final Sentido direction;
  final String destination;

  /// Embarcadero desde el que se calculó (el origen si no se pasó `desde`).
  /// null solo si el sentido no tiene embarcaderos.
  final DepartureStop? fromStop;
  final bool isScheduled;
  final DayType dayType;

  /// Fecha y hora locales de Montería usadas en el cálculo ("2026-11-10", "07:03").
  final String localDate;
  final String localTime;
  final String timeZone;
  final DateTime scheduleUpdatedAt;

  /// "Hora estimada según el horario programado…".
  final String notice;

  /// Avisos vigentes que afectan la ruta o el embarcadero.
  final List<DepartureAlert> alerts;
  final DepartureStatus status;

  /// Mensaje listo para mostrar, en español.
  final String message;

  // --- NEXT_DEPARTURE ---
  /// Hora de paso por [fromStop] ("05:42").
  final String? departureTime;

  /// Hora de salida desde el origen ("05:30").
  final String? originDepartureTime;
  final int? minutesRemaining;

  /// La salida es de ayer y pasa por este embarcadero después de medianoche.
  final bool? crossesMidnight;

  // --- SUSPENDED ---
  final MotivoAviso? reason;
  final String? detail;

  /// null = sin fecha de fin.
  final DateTime? suspendedUntil;

  // --- NO_MORE_DEPARTURES_TODAY ---
  /// null si mañana tampoco hay salidas.
  final NextDayDeparture? nextDayFirstDeparture;

  factory ProximaSalida.fromJson(JsonMap json) {
    final fromStop = json.objOrNull('fromStop');
    final nextDay = json.objOrNull('nextDayFirstDeparture');
    return ProximaSalida(
      route: DepartureRoute.fromJson(json.obj('route')),
      direction: json.enumValue('direction', Sentido.values, Sentido.ida),
      destination: json.str('destination'),
      fromStop: fromStop == null ? null : DepartureStop.fromJson(fromStop),
      isScheduled: json.booleanOrNull('isScheduled') ?? true,
      dayType: json.enumValue('dayType', DayType.values, DayType.weekday),
      localDate: json.str('localDate'),
      localTime: json.str('localTime'),
      timeZone: json.str('timeZone'),
      scheduleUpdatedAt: json.date('scheduleUpdatedAt'),
      notice: json.str('notice'),
      alerts: json.list('alerts', DepartureAlert.fromJson),
      status: json.enumValue('status', DepartureStatus.values, DepartureStatus.unknown),
      message: json.str('message'),
      departureTime: json.strOrNull('departureTime'),
      originDepartureTime: json.strOrNull('originDepartureTime'),
      minutesRemaining: json.integerOrNull('minutesRemaining'),
      crossesMidnight: json.booleanOrNull('crossesMidnight'),
      reason: json.enumOrNull('reason', MotivoAviso.values),
      detail: json.strOrNull('detail'),
      suspendedUntil: json.dateOrNull('suspendedUntil'),
      nextDayFirstDeparture: nextDay == null ? null : NextDayDeparture.fromJson(nextDay),
    );
  }
}

@immutable
class DepartureRoute {
  const DepartureRoute({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  factory DepartureRoute.fromJson(JsonMap json) =>
      DepartureRoute(id: json.str('id'), code: json.str('code'), name: json.str('name'));
}

@immutable
class DepartureStop {
  const DepartureStop({
    required this.id,
    required this.name,
    required this.order,
    required this.isOrigin,
    required this.minutesFromOrigin,
    required this.isEstimatedTime,
  });

  final String id;
  final String name;
  final int order;
  final bool isOrigin;
  final int minutesFromOrigin;
  final bool isEstimatedTime;

  factory DepartureStop.fromJson(JsonMap json) => DepartureStop(
        id: json.str('id'),
        name: json.str('name'),
        order: json.integer('order'),
        isOrigin: json.boolean('isOrigin'),
        minutesFromOrigin: json.integer('minutesFromOrigin'),
        isEstimatedTime: json.boolean('isEstimatedTime'),
      );
}

/// Aviso dentro de /proxima-salida. Las claves van en inglés, pero los VALORES de
/// type, reason y scope son los mismos del resto de la API ("suspendido", "nivel_rio"…).
@immutable
class DepartureAlert {
  const DepartureAlert({
    required this.id,
    required this.type,
    required this.reason,
    required this.title,
    required this.message,
    required this.scope,
    required this.until,
  });

  final String id;
  final TipoAviso type;
  final MotivoAviso reason;
  final String title;
  final String message;
  final AlcanceAviso scope;

  /// null = sin fecha de fin.
  final DateTime? until;

  factory DepartureAlert.fromJson(JsonMap json) => DepartureAlert(
        id: json.str('id'),
        type: json.enumValue('type', TipoAviso.values, TipoAviso.informativo),
        reason: json.enumValue('reason', MotivoAviso.values, MotivoAviso.otro),
        title: json.str('title'),
        message: json.str('message'),
        scope: json.enumValue('scope', AlcanceAviso.values, AlcanceAviso.general),
        until: json.dateOrNull('until'),
      );
}

@immutable
class NextDayDeparture {
  const NextDayDeparture({
    required this.date,
    required this.dayType,
    required this.departureTime,
    required this.originDepartureTime,
  });

  final String date;
  final DayType dayType;
  final String departureTime;
  final String originDepartureTime;

  factory NextDayDeparture.fromJson(JsonMap json) => NextDayDeparture(
        date: json.str('date'),
        dayType: json.enumValue('dayType', DayType.values, DayType.weekday),
        departureTime: json.str('departureTime'),
        originDepartureTime: json.str('originDepartureTime'),
      );
}
