import 'package:easybus_app/domain/historial.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Últimas consultas: la más reciente primero, sin repetir y máximo 10', () {
    Consulta c(TipoConsulta t, String id, int min) =>
        Consulta(tipo: t, id: id, titulo: id, cuando: DateTime(2026, 11, 26, 8, min));

    var h = <Consulta>[];
    for (var i = 0; i < 12; i++) {
      h = agregarConsulta(h, c(TipoConsulta.embarcadero, 'e$i', i));
    }
    expect(h, hasLength(maxHistorial));
    expect(h.first.id, 'e11');
    expect(h.last.id, 'e2', reason: 'Las dos más viejas salen');

    // Volver a abrir uno lo sube al principio sin duplicarlo
    h = agregarConsulta(h, c(TipoConsulta.embarcadero, 'e5', 30));
    expect(h.first.id, 'e5');
    expect(h.where((x) => x.id == 'e5'), hasLength(1));
    expect(h, hasLength(maxHistorial));

    // Una ruta con el mismo id que un embarcadero es otra consulta
    h = agregarConsulta(h, c(TipoConsulta.ruta, 'e5', 31));
    expect(h.where((x) => x.id == 'e5'), hasLength(2));

    // Ida y vuelta por JSON (se guarda en el teléfono)
    final again = Consulta.fromJson(h.first.toJson());
    expect((again.tipo, again.id, again.cuando), (TipoConsulta.ruta, 'e5', h.first.cuando.toUtc()));
  });
}
