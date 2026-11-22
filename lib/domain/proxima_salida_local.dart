// Próxima salida calculada en el teléfono, para cuando no hay conexión.
//
// Es una traducción directa de la API (easybus-backend, src/publico/
// proxima-salida.util.ts y proxima-salida.service.ts): misma zona horaria, misma
// regla de tipo de día, mismo manejo de las salidas de ayer que pasan después de
// medianoche y los mismos textos. Las pruebas comparan el resultado con respuestas
// reales del backend (test/domain/proxima_salida_local_test.dart).
//
// Lo único que no puede saber sin conexión son los avisos de suspensión: por eso
// la app siempre consulta primero la API y usa este cálculo solo si falla.

import '../models/enums.dart';
import '../models/horario.dart';
import '../models/proxima_salida.dart';
import '../models/ruta.dart';

const zonaHoraria = 'America/Bogota';

/// Mismo texto que la API.
const avisoHorarioProgramado =
    'Hora estimada según el horario programado. No corresponde a la ubicación real de la embarcación.';

const _minutosDia = 24 * 60;

/// Fecha y hora LOCALES de Montería. Colombia no tiene horario de verano: siempre
/// es UTC−5, sin importar la zona horaria configurada en el teléfono.
class MomentoBogota {
  MomentoBogota(DateTime instante) : _local = instante.toUtc().subtract(const Duration(hours: 5));

  final DateTime _local;

  /// "AAAA-MM-DD".
  String get fecha => '${_local.year}-${_dos(_local.month)}-${_dos(_local.day)}';

  /// "HH:MM".
  String get hora => '${_dos(_local.hour)}:${_dos(_local.minute)}';

  /// Minutos desde la medianoche (0 - 1439).
  int get minutos => _local.hour * 60 + _local.minute;

  /// 0 = domingo … 6 = sábado (como en la API).
  int get diaSemana => _local.weekday % 7;

  int get anio => _local.year;
}

String _dos(int v) => v.toString().padLeft(2, '0');

/// Regla del documento (sección 8.3): festivo o domingo → domingo/festivo;
/// sábado → sábado; cualquier otro día → laboral.
TipoDia tipoDiaPara(int diaSemana, bool esFestivo) {
  if (esFestivo || diaSemana == 0) return TipoDia.domingoFestivo;
  if (diaSemana == 6) return TipoDia.sabado;
  return TipoDia.laboral;
}

const _dayType = {
  TipoDia.laboral: DayType.weekday,
  TipoDia.sabado: DayType.saturday,
  TipoDia.domingoFestivo: DayType.sundayHoliday,
};

int _aMinutos(String hhmm) => int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

/// Minutos desde la medianoche → "HH:MM" (1460 → "00:20").
String formatoHoraMinutos(int minutos) {
  final m = ((minutos % _minutosDia) + _minutosDia) % _minutosDia;
  return '${_dos(m ~/ 60)}:${_dos(m % 60)}';
}

String sumarMinutos(String hhmm, int minutos) => formatoHoraMinutos(_aMinutos(hhmm) + minutos);

class ProximoPaso {
  const ProximoPaso({
    required this.salidaOrigen,
    required this.horaPaso,
    required this.minutosRestantes,
    required this.pasaDespuesDeMedianoche,
  });

  final String salidaOrigen;
  final String horaPaso;
  final int minutosRestantes;
  final bool pasaDespuesDeMedianoche;
}

/// Próximo paso por un embarcadero que está a [minutosDesdeOrigen] del origen,
/// considerando las salidas de ayer que pasan hoy después de medianoche. Un paso
/// "en este mismo minuto" todavía se muestra (0 minutos).
ProximoPaso? buscarProximoPaso(
  List<String> horasHoy,
  List<String> horasAyer,
  int minutosDesdeOrigen,
  int minutosAhora,
) {
  final candidatos = [
    for (final h in horasAyer) (h: h, paso: _aMinutos(h) + minutosDesdeOrigen - _minutosDia),
    for (final h in horasHoy) (h: h, paso: _aMinutos(h) + minutosDesdeOrigen),
  ].where((c) => c.paso >= minutosAhora).toList()..sort((a, b) => a.paso.compareTo(b.paso));
  if (candidatos.isEmpty) return null;
  final c = candidatos.first;
  return ProximoPaso(
    salidaOrigen: c.h,
    horaPaso: formatoHoraMinutos(c.paso),
    minutosRestantes: c.paso - minutosAhora,
    pasaDespuesDeMedianoche: c.paso >= _minutosDia,
  );
}

/// Calcula la próxima salida como lo haría GET /rutas/{id}/proxima-salida, sin avisos.
///
/// Lanza [StateError] si los datos guardados no alcanzan (sentido o embarcadero que
/// no están en la ruta): quien llama muestra entonces el error de conexión.
ProximaSalida calcularProximaSalidaLocal({
  required RutaDetalle ruta,
  required Sentido sentido,
  String? desdeEmbarcaderoId,
  required List<Horario> horarios,
  required Set<String> festivos,
  required DateTime instante,
}) {
  final rs = ruta.sentido(sentido);
  if (rs == null) throw StateError('El sentido ${sentido.apiValue} no está guardado');

  ParadaEnRuta? parada = rs.paradas.isEmpty ? null : rs.paradas.first;
  if (desdeEmbarcaderoId != null) {
    parada = rs.paradas.where((p) => p.embarcadero.id == desdeEmbarcaderoId).firstOrNull;
    if (parada == null) throw StateError('Ese embarcadero no está en el sentido ${sentido.apiValue}');
  }
  final desfase = parada?.minutosDesdeOrigen ?? 0;

  final ahora = MomentoBogota(instante);
  TipoDia tipoDe(MomentoBogota m) => tipoDiaPara(m.diaSemana, festivos.contains(m.fecha));
  List<String> horasDe(TipoDia tipo) =>
      (horarios.where((h) => h.tipoDia == tipo).map((h) => h.horaSalida).toList()..sort());
  final tipoDia = tipoDe(ahora);

  ProximaSalida resultado({
    required DepartureStatus status,
    required String message,
    String? departureTime,
    String? originDepartureTime,
    int? minutesRemaining,
    bool? crossesMidnight,
    NextDayDeparture? nextDayFirstDeparture,
  }) => ProximaSalida(
    route: DepartureRoute(id: ruta.ruta.id, code: ruta.ruta.codigo, name: ruta.ruta.nombre),
    direction: sentido,
    destination: rs.destino,
    fromStop: parada == null
        ? null
        : DepartureStop(
            id: parada.embarcadero.id,
            name: parada.embarcadero.nombre,
            order: parada.orden,
            isOrigin: parada.orden == 1,
            minutesFromOrigin: desfase,
            isEstimatedTime: parada.tiempoEstimado,
          ),
    isScheduled: true,
    dayType: _dayType[tipoDia]!,
    localDate: ahora.fecha,
    localTime: ahora.hora,
    timeZone: zonaHoraria,
    scheduleUpdatedAt: rs.actualizadoEn,
    notice: avisoHorarioProgramado,
    alerts: const [],
    status: status,
    message: message,
    departureTime: departureTime,
    originDepartureTime: originDepartureTime,
    minutesRemaining: minutesRemaining,
    crossesMidnight: crossesMidnight,
    nextDayFirstDeparture: nextDayFirstDeparture,
  );

  // 1. Ruta fuera de servicio
  if (ruta.ruta.estado != EstadoRuta.activa) {
    return resultado(status: DepartureStatus.outOfService, message: 'La ruta está fuera de servicio.');
  }
  // 2. (Avisos de suspensión: solo los conoce la API)
  // 3. Embarcadero cerrado temporalmente
  if (parada?.embarcadero.estado == EstadoEmbarcadero.cerradoTemporal) {
    return resultado(
      status: DepartureStatus.outOfService,
      message: 'El ${parada!.embarcadero.nombre} está cerrado temporalmente.',
    );
  }

  // 4. Horario: salidas de hoy y de ayer (las de ayer pueden pasar hoy después de medianoche)
  final ayer = MomentoBogota(instante.subtract(const Duration(days: 1)));
  final horasHoy = horasDe(tipoDia);
  final horasAyer = horasDe(tipoDe(ayer));
  final lugar = parada != null && parada.orden > 1 ? ' desde el ${parada.embarcadero.nombre}' : '';
  final proximo = buscarProximoPaso(horasHoy, horasAyer, desfase, ahora.minutos);

  if (proximo != null) {
    return resultado(
      status: DepartureStatus.nextDeparture,
      departureTime: proximo.horaPaso,
      originDepartureTime: proximo.salidaOrigen,
      minutesRemaining: proximo.minutosRestantes,
      crossesMidnight: proximo.pasaDespuesDeMedianoche,
      message: proximo.minutosRestantes == 0
          ? 'La embarcación ${lugar.isNotEmpty ? 'pasa ahora por el ${parada!.embarcadero.nombre}' : 'sale ahora'} '
                '(${proximo.horaPaso}).'
          : 'Próxima salida$lugar a las ${proximo.horaPaso}, en ${proximo.minutosRestantes} min.',
    );
  }

  final manana = MomentoBogota(instante.add(const Duration(days: 1)));
  final tipoManana = tipoDe(manana);
  final horasManana = horasDe(tipoManana);
  final primeraManana = horasManana.isEmpty ? null : horasManana.first;

  return resultado(
    status: DepartureStatus.noMoreDeparturesToday,
    message: horasHoy.isEmpty
        ? 'Esta ruta no tiene salidas programadas hoy.'
        : 'No hay más salidas programadas hoy$lugar.',
    nextDayFirstDeparture: primeraManana == null
        ? null
        : NextDayDeparture(
            date: manana.fecha,
            dayType: _dayType[tipoManana]!,
            departureTime: sumarMinutos(primeraManana, desfase),
            originDepartureTime: primeraManana,
          ),
  );
}

/// Años de festivos que necesita el cálculo para [instante]: ayer, hoy y mañana
/// (el 1 de enero mira el 31 de diciembre, y el 31 de diciembre mira el 1 de enero).
Set<int> aniosNecesarios(DateTime instante) => {
  MomentoBogota(instante.subtract(const Duration(days: 1))).anio,
  MomentoBogota(instante).anio,
  MomentoBogota(instante.add(const Duration(days: 1))).anio,
};
