// Pruebas del Modulo 2: presupuestos (RF-004) y metas de ahorro (RF-005).
//
// Los JSON son respuestas reales de la API: si alguien cambia un campo en el
// backend, estas pruebas lo detectan antes de que falle en el telefono.

import 'package:app_finanzas/data/models/meta_ahorro.dart';
import 'package:app_finanzas/data/models/presupuesto.dart';
import 'package:app_finanzas/features/planificacion/metas_tab.dart';
import 'package:app_finanzas/features/planificacion/presupuestos_tab.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

const _jsonPresupuesto = {
  'id': 1,
  'category_id': 1,
  'anio': 2026,
  'mes': 11,
  'limite': '1500000.00',
  'gastado': '1275000.00',
  'disponible': '225000.00',
  'porcentaje': 85.0,
  'alerta': 'atencion',
  'categoria': {
    'id': 1,
    'nombre': 'Alimentación',
    'tipo': 'gasto',
    'icono': 'restaurant',
    'color': '#FF7043',
    'es_predefinida': true,
  },
};

const _jsonMeta = {
  'id': 1,
  'nombre': 'Vacaciones',
  'descripcion': 'Viaje a Encarnación',
  'monto_objetivo': '5000000.00',
  'monto_actual': '1250000.00',
  'fecha_objetivo': '2027-03-15',
  'estado': 'activa',
  'progreso': 25.0,
};

Presupuesto _presupuesto({
  String gastado = '1275000.00',
  String disponible = '225000.00',
  double porcentaje = 85,
  String? alerta = 'atencion',
}) =>
    Presupuesto.fromJson({
      ..._jsonPresupuesto,
      'gastado': gastado,
      'disponible': disponible,
      'porcentaje': porcentaje,
      'alerta': alerta,
    });

MetaAhorro _meta({String actual = '1250000.00', String estado = 'activa', String? fecha}) =>
    MetaAhorro.fromJson({
      ..._jsonMeta,
      'monto_actual': actual,
      'estado': estado,
      'fecha_objetivo': fecha ?? _jsonMeta['fecha_objetivo'],
    });

Future<void> _montar(WidgetTester tester, Widget pantalla, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(home: pantalla),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('presupuesto', () {
    test('se leen los montos, la alerta y la categoría anidada', () {
      final p = Presupuesto.fromJson(_jsonPresupuesto);

      expect(p.categoriaId, 1);
      expect(p.mes, 11);
      expect(p.limite, 1500000.0);
      expect(p.gastado, 1275000.0);
      expect(p.disponible, 225000.0);
      expect(p.porcentaje, 85.0);
      expect(p.alerta, AlertaPresupuesto.atencion);
      expect(p.categoria.nombre, 'Alimentación');
      expect(p.excedido, isFalse);
    });

    test('el mensaje de alerta depende de cuánto se usó', () {
      expect(_presupuesto(alerta: null, porcentaje: 50).mensajeDeAlerta, isNull);
      expect(
        _presupuesto().mensajeDeAlerta,
        'Ya usaste el 85 % del presupuesto de Alimentación.',
      );
      expect(
        _presupuesto(alerta: 'limite', porcentaje: 100, disponible: '0.00').mensajeDeAlerta,
        'Llegaste al límite del presupuesto de Alimentación.',
      );
      final pasado = _presupuesto(alerta: 'limite', porcentaje: 120, disponible: '-300000.00');
      expect(pasado.excedido, isTrue);
      expect(pasado.mensajeDeAlerta, contains('Te pasaste'));
      expect(pasado.mensajeDeAlerta, contains('120 %'));
    });
  });

  group('meta de ahorro', () {
    test('se leen los montos, el estado y la fecha', () {
      final m = MetaAhorro.fromJson(_jsonMeta);

      expect(m.nombre, 'Vacaciones');
      expect(m.descripcion, 'Viaje a Encarnación');
      expect(m.montoObjetivo, 5000000.0);
      expect(m.montoActual, 1250000.0);
      expect(m.fechaObjetivo, DateTime(2027, 3, 15));
      expect(m.estado, EstadoMeta.activa);
      expect(m.progreso, 25.0);
      expect(m.faltante, 3750000.0);
    });

    test('reparte lo que falta entre los meses que quedan, contando el actual', () {
      // De noviembre a marzo inclusive son 5 meses.
      final m = _meta();
      expect(m.ahorroMensualNecesario(DateTime(2026, 11, 12)), 750000.0);
      // En el mismo mes de la fecha objetivo hay que juntar todo lo que falta.
      expect(m.ahorroMensualNecesario(DateTime(2027, 3, 1)), 3750000.0);
    });

    test('una meta vencida, cumplida o cancelada no sugiere cuánto ahorrar', () {
      final hoy = DateTime(2026, 11, 12);
      final vencida = _meta(fecha: '2026-10-01');
      expect(vencida.vencida(hoy), isTrue);
      expect(vencida.ahorroMensualNecesario(hoy), isNull);
      expect(_meta(actual: '5000000.00', estado: 'completada').ahorroMensualNecesario(hoy),
          isNull);
      expect(_meta(estado: 'cancelada').ahorroMensualNecesario(hoy), isNull);
      // Vence hoy: todavía está a tiempo.
      expect(_meta(fecha: '2026-11-12').vencida(hoy), isFalse);
    });
  });

  group('pantallas', () {
    testWidgets('el presupuesto muestra el porcentaje, lo que queda y la alerta', (tester) async {
      await _montar(tester, const PresupuestosTab(), [
        presupuestosProvider.overrideWith((ref) async => [_presupuesto()]),
      ]);

      expect(find.text('Alimentación'), findsOneWidget);
      expect(find.text('85 %'), findsOneWidget);
      expect(find.textContaining('Quedan 225.000'), findsOneWidget);
      expect(find.text('Ya usaste más del 80 % del límite'), findsOneWidget);
    });

    testWidgets('al pasarse del límite dice cuánto', (tester) async {
      await _montar(tester, const PresupuestosTab(), [
        presupuestosProvider.overrideWith(
          (ref) async => [
            _presupuesto(alerta: 'limite', porcentaje: 120, disponible: '-300000.00'),
          ],
        ),
      ]);

      expect(find.textContaining('Te pasaste 300.000'), findsOneWidget);
      expect(find.text('Superaste el límite'), findsOneWidget);
    });

    testWidgets('sin presupuestos ofrece copiar los del mes anterior', (tester) async {
      await _montar(tester, const PresupuestosTab(), [
        presupuestosProvider.overrideWith((ref) async => <Presupuesto>[]),
      ]);

      expect(find.text('Sin presupuestos este mes'), findsOneWidget);
      expect(find.text('Copiar del mes anterior'), findsOneWidget);
    });

    testWidgets('una meta activa muestra el progreso y deja sumar ahorro', (tester) async {
      await _montar(tester, const MetasTab(), [
        metasProvider.overrideWith((ref) async => [_meta()]),
      ]);

      expect(find.text('Vacaciones'), findsOneWidget);
      expect(find.text('25 %'), findsOneWidget);
      expect(find.text('Sumar ahorro'), findsOneWidget);
    });

    testWidgets('una meta cumplida no ofrece sumar más', (tester) async {
      await _montar(tester, const MetasTab(), [
        metasProvider.overrideWith(
          (ref) async => [_meta(actual: '5000000.00', estado: 'completada')],
        ),
      ]);

      expect(find.text('¡Meta cumplida!'), findsOneWidget);
      expect(find.text('Sumar ahorro'), findsNothing);
    });
  });
}
