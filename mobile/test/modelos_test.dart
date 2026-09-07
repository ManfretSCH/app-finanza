// Verifica que la app interprete bien lo que devuelve el backend.
//
// Los JSON de abajo son respuestas reales copiadas de la API en ejecucion.
// Si alguien cambia un nombre de campo en el backend, esta prueba lo detecta
// antes de que falle en el telefono.

import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/data/models/transaccion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cuenta: se lee el saldo calculado por el backend', () {
    final json = {
      'id': 1,
      'nombre': 'Caja de ahorro',
      'tipo': 'ahorro',
      'saldo_inicial': '1500000.00',
      'moneda': 'PYG',
      'activa': true,
      'saldo_actual': '4415000.00',
    };

    final cuenta = Cuenta.fromJson(json);

    expect(cuenta.nombre, 'Caja de ahorro');
    expect(cuenta.tipo, TipoCuenta.ahorro);
    expect(cuenta.saldoInicial, 1500000.00);
    expect(cuenta.saldoActual, 4415000.00);
    expect(cuenta.moneda, 'PYG');
    expect(cuenta.activa, isTrue);
  });

  test('cuenta: al crearla el backend no devuelve saldo_actual', () {
    // La respuesta de POST /accounts no incluye saldo_actual; debe caer al inicial.
    final cuenta = Cuenta.fromJson({
      'id': 2,
      'nombre': 'Efectivo',
      'tipo': 'efectivo',
      'saldo_inicial': '0.00',
      'moneda': 'PYG',
      'activa': true,
    });

    expect(cuenta.saldoActual, 0.0);
  });

  test('categoria: el color hexadecimal se convierte al entero de Flutter', () {
    final categoria = Categoria.fromJson({
      'id': 12,
      'nombre': 'Inversiones',
      'tipo': 'ingreso',
      'icono': 'trending_up',
      'color': '#9CCC65',
      'es_predefinida': true,
    });

    expect(categoria.nombre, 'Inversiones');
    expect(categoria.tipo, TipoMovimiento.ingreso);
    expect(categoria.esPredefinida, isTrue);
    expect(categoria.colorEntero, 0xFF9CCC65);
  });

  test('transaccion: incluye la categoria anidada que manda el backend', () {
    final movimiento = Transaccion.fromJson({
      'id': 1,
      'account_id': 1,
      'category_id': 1,
      'tipo': 'gasto',
      'monto': '85000.00',
      'fecha': '2026-09-05',
      'descripcion': 'Supermercado',
      'etiquetas': null,
      'categoria': {
        'id': 1,
        'nombre': 'Alimentacion',
        'tipo': 'gasto',
        'icono': 'restaurant',
        'color': '#FF7043',
        'es_predefinida': true,
      },
    });

    expect(movimiento.cuentaId, 1);
    expect(movimiento.monto, 85000.00);
    expect(movimiento.fecha, DateTime(2026, 9, 5));
    expect(movimiento.descripcion, 'Supermercado');
    expect(movimiento.esIngreso, isFalse);
    expect(movimiento.categoria?.nombre, 'Alimentacion');
  });

  test('transaccion: un ingreso se marca como tal', () {
    final movimiento = Transaccion.fromJson({
      'id': 2,
      'account_id': 1,
      'category_id': 10,
      'tipo': 'ingreso',
      'monto': '3000000.00',
      'fecha': '2026-09-01',
      'descripcion': 'Sueldo',
      'etiquetas': null,
      'categoria': null,
    });

    expect(movimiento.esIngreso, isTrue);
    expect(movimiento.categoria, isNull);
  });
}
