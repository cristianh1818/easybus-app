import 'package:easybus_app/domain/propuesta_viaje.dart';
import 'package:easybus_app/models/enums.dart';
import 'package:easybus_app/models/geo.dart';
import 'package:easybus_app/models/json.dart';
import 'package:easybus_app/models/proxima_salida.dart';
import 'package:easybus_app/models/ruta.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_repository.dart';

void main() {
  // BS-1 del fixture: ida Ronda Norte (0) → Calle 37 (12) → Centro (21) → Corrección (30) → Sur (60)
  final ruta = RutaDetalle.fromJson(asJsonMap(readFixture('ruta_detalle.json')));

  test('Propone subir cerca del origen, bajar cerca del destino y en el sentido correcto', () {
    // Cerca de Calle 37 → cerca de Sur: ida, subir en Calle 37, bajar en Sur
    final ida = calcularPropuesta(
      rutas: [ruta],
      origen: const PuntoViaje.punto(GeoPoint(8.7612, -75.8812)),
      destino: const PuntoViaje.punto(GeoPoint(8.7497, -75.9005)),
    )!;
    expect(ida.sentido.sentido, Sentido.ida);
    expect(ida.subida.embarcadero.nombre, 'Embarcadero Calle 37');
    expect(ida.bajada.embarcadero.nombre, 'Embarcadero Sur');
    expect(ida.minutosEnEmbarcacion, 48);
    expect(ida.subida.orden, lessThan(ida.bajada.orden), reason: 'La bajada va después de la subida');

    // Al revés (desde el embarcadero Centro elegido en la lista, hacia Ronda Norte): vuelta
    final centro = ruta
        .sentido(Sentido.vuelta)!
        .paradas
        .firstWhere((p) => p.embarcadero.nombre == 'Embarcadero Centro');
    final vuelta = calcularPropuesta(
      rutas: [ruta],
      origen: PuntoViaje.embarcadero(
        centro.embarcadero.id,
        ubicacion: centro.embarcadero.ubicacion,
        nombre: 'Centro',
      ),
      destino: const PuntoViaje.punto(GeoPoint(8.7721, -75.8791)),
    )!;
    expect(vuelta.sentido.sentido, Sentido.vuelta);
    expect(vuelta.subida.embarcadero.nombre, 'Embarcadero Centro');
    expect(vuelta.metrosHastaSubida, 0);
    expect(vuelta.bajada.embarcadero.nombre, 'Embarcadero Ronda Norte');

    // Llegada: salida del origen 07:30 + 60 min hasta Sur
    final proxima = ProximaSalida.fromJson(asJsonMap(readFixture('proxima_salida_next.json')));
    expect(horaLlegada(proxima, ida.bajada), (hora: '08:30', manana: false));

    // Mismo embarcadero de origen y destino: no hay propuesta
    final sur = ida.bajada.embarcadero;
    final mismo = PuntoViaje.embarcadero(sur.id, ubicacion: sur.ubicacion, nombre: sur.nombre);
    expect(calcularPropuesta(rutas: [ruta], origen: mismo, destino: mismo), isNull);
  });
}
