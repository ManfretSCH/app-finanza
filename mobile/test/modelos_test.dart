// Verifica que la app interprete bien lo que devuelve el backend.
//
// Los JSON de abajo son respuestas reales copiadas de la API en ejecucion.
// Si alguien cambia un nombre de campo en el backend, esta prueba lo detecta
// antes de que falle en el telefono.

import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/data/models/informe.dart';
import 'package:app_finanzas/data/models/transaccion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cuenta: se lee el saldo calculado y el tipo anidado', () {
    final json = {
      'id': 1,
      'nombre': 'Caja de ahorro',
      'account_type_id': 1,
      'saldo_inicial': '1500000.00',
      'moneda': 'PYG',
      'activa': true,
      'saldo_actual': '4415000.00',
      'tipo': {
        'id': 1,
        'nombre': 'Caja de ahorro',
        'icono': 'savings',
        'es_predefinido': true,
      },
    };

    final cuenta = Cuenta.fromJson(json);

    expect(cuenta.nombre, 'Caja de ahorro');
    expect(cuenta.tipoId, 1);
    expect(cuenta.tipo?.nombre, 'Caja de ahorro');
    expect(cuenta.tipo?.esPredefinido, isTrue);
    expect(cuenta.saldoInicial, 1500000.00);
    expect(cuenta.saldoActual, 4415000.00);
    expect(cuenta.moneda, 'PYG');
    expect(cuenta.activa, isTrue);
  });

  test('cuenta: al crearla el backend no devuelve saldo_actual ni el tipo', () {
    // La respuesta de POST /accounts no incluye saldo_actual; debe caer al inicial.
    final cuenta = Cuenta.fromJson({
      'id': 2,
      'nombre': 'Efectivo',
      'account_type_id': 4,
      'saldo_inicial': '0.00',
      'moneda': 'PYG',
      'activa': true,
    });

    expect(cuenta.saldoActual, 0.0);
    expect(cuenta.tipo, isNull);
  });

  test('categoría: el color hexadecimal se convierte al entero de Flutter', () {
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

  test('transacción: incluye la categoría anidada que manda el backend', () {
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

  test('transacción: un ingreso se marca como tal', () {
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

  test('resumen mensual: se leen los totales y el promedio diario', () {
    final resumen = ResumenMensual.fromJson({
      'mes': 9,
      'anio': 2026,
      'ingresos': '3000000.00',
      'gastos': '300000.00',
      'balance': '2700000.00',
      'promedio_diario_gasto': '42857.14',
      'dias_considerados': 7,
      'cantidad_movimientos': 4,
    });

    expect(resumen.ingresos, 3000000.0);
    expect(resumen.gastos, 300000.0);
    expect(resumen.balance, 2700000.0);
    expect(resumen.promedioDiarioGasto, 42857.14);
    expect(resumen.diasConsiderados, 7);
    expect(resumen.sinDatos, isFalse);
  });

  test('resumen mensual: un mes sin movimientos se marca como vacio', () {
    final resumen = ResumenMensual.fromJson({
      'mes': 1,
      'anio': 2026,
      'ingresos': '0.00',
      'gastos': '0.00',
      'balance': '0.00',
      'promedio_diario_gasto': '0.00',
      'dias_considerados': 31,
      'cantidad_movimientos': 0,
    });

    expect(resumen.sinDatos, isTrue);
  });

  test('línea por categoría: trae el porcentaje ya calculado por el backend', () {
    final linea = LineaCategoria.fromJson({
      'categoria': {
        'id': 1,
        'nombre': 'Alimentacion',
        'tipo': 'gasto',
        'icono': 'restaurant',
        'color': '#FF7043',
        'es_predefinida': true,
      },
      'total': '200000.00',
      'cantidad': 1,
      'porcentaje': 66.7,
    });

    expect(linea.categoria.nombre, 'Alimentacion');
    expect(linea.total, 200000.0);
    expect(linea.porcentaje, 66.7);
  });

  test('línea por día: un día sin movimientos llega en cero', () {
    final dia = LineaDia.fromJson({
      'fecha': '2026-09-02',
      'ingresos': '0.00',
      'gastos': '0.00',
    });

    expect(dia.fecha, DateTime(2026, 9, 2));
    expect(dia.gastos, 0.0);
  });

  test('línea por mes: se detecta un mes sin datos para el gráfico anual', () {
    final conDatos = LineaMes.fromJson({
      'mes': 9,
      'ingresos': '3000000.00',
      'gastos': '300000.00',
      'balance': '2700000.00',
    });
    final vacio = LineaMes.fromJson({
      'mes': 1,
      'ingresos': '0.00',
      'gastos': '0.00',
      'balance': '0.00',
    });

    expect(conDatos.balance, 2700000.0);
    expect(conDatos.sinDatos, isFalse);
    expect(vacio.sinDatos, isTrue);
  });
}
