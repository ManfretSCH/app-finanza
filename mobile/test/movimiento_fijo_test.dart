// Verifica que la app interprete bien lo que devuelve /recurring.
// Los JSON son respuestas reales del backend.

import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/movimiento_fijo.dart';
import 'package:app_finanzas/data/models/transaccion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('movimiento fijo: se leen el día, el rango y la categoría anidada', () {
    final fijo = MovimientoFijo.fromJson({
      'id': 1,
      'account_id': 3,
      'category_id': 3,
      'tipo': 'gasto',
      'monto': '1200000.00',
      'dia_del_mes': 1,
      'fecha_inicio': '2026-07-01',
      'fecha_fin': null,
      'descripcion': 'Alquiler',
      'activo': true,
      'categoria': {
        'id': 3,
        'nombre': 'Vivienda',
        'tipo': 'gasto',
        'icono': 'home',
        'color': '#8D6E63',
        'es_predefinida': true,
      },
    });

    expect(fijo.monto, 1200000.0);
    expect(fijo.diaDelMes, 1);
    expect(fijo.fechaInicio, DateTime(2026, 7, 1));
    expect(fijo.fechaFin, isNull);
    expect(fijo.activo, isTrue);
    expect(fijo.esIngreso, isFalse);
    expect(fijo.categoria?.nombre, 'Vivienda');
  });

  test('un fijo de fin de mes se explica distinto', () {
    MovimientoFijo conDia(int dia) => MovimientoFijo(
          id: 1,
          cuentaId: 1,
          categoriaId: 1,
          tipo: TipoMovimiento.gasto,
          monto: 1000,
          diaDelMes: dia,
          fechaInicio: DateTime(2026, 1, 1),
          activo: true,
        );

    expect(conDia(10).cuandoOcurre, 'Todos los meses el día 10');
    // A partir del 29 no todos los meses llegan, y el texto lo aclara.
    expect(conDia(31).cuandoOcurre, contains('o el último'));
  });

  test('una transacción generada por un fijo se reconoce', () {
    Transaccion desde(int? recurrenteId) => Transaccion.fromJson({
          'id': 1,
          'account_id': 1,
          'category_id': 1,
          'recurring_id': recurrenteId,
          'tipo': 'gasto',
          'monto': '1200000.00',
          'fecha': '2026-09-01',
          'descripcion': 'Alquiler',
          'etiquetas': null,
          'categoria': null,
        });

    expect(desde(7).esFijo, isTrue);
    expect(desde(7).recurrenteId, 7);
    // Una cargada a mano no lleva la marca.
    expect(desde(null).esFijo, isFalse);
  });
}
