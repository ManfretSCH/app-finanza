import 'package:app_finanzas/data/models/categoria.dart';

/// Los numeros gruesos de un mes.
class ResumenMensual {
  const ResumenMensual({
    required this.mes,
    required this.anio,
    required this.ingresos,
    required this.gastos,
    required this.balance,
    required this.promedioDiarioGasto,
    required this.diasConsiderados,
    required this.cantidadMovimientos,
  });

  factory ResumenMensual.fromJson(Map<String, dynamic> json) => ResumenMensual(
        mes: json['mes'] as int,
        anio: json['anio'] as int,
        ingresos: double.parse(json['ingresos'].toString()),
        gastos: double.parse(json['gastos'].toString()),
        balance: double.parse(json['balance'].toString()),
        promedioDiarioGasto: double.parse(json['promedio_diario_gasto'].toString()),
        diasConsiderados: json['dias_considerados'] as int,
        cantidadMovimientos: json['cantidad_movimientos'] as int,
      );

  final int mes;
  final int anio;
  final double ingresos;
  final double gastos;
  final double balance;
  final double promedioDiarioGasto;
  final int diasConsiderados;
  final int cantidadMovimientos;

  bool get sinDatos => cantidadMovimientos == 0;
}

/// Cuanto se fue (o entro) en una categoria y que parte del total representa.
class LineaCategoria {
  const LineaCategoria({
    required this.categoria,
    required this.total,
    required this.cantidad,
    required this.porcentaje,
  });

  factory LineaCategoria.fromJson(Map<String, dynamic> json) => LineaCategoria(
        categoria: Categoria.fromJson(json['categoria'] as Map<String, dynamic>),
        total: double.parse(json['total'].toString()),
        cantidad: json['cantidad'] as int,
        porcentaje: (json['porcentaje'] as num).toDouble(),
      );

  final Categoria categoria;
  final double total;
  final int cantidad;
  final double porcentaje;
}

/// Un dia del mes con lo que entro y salio.
class LineaDia {
  const LineaDia({required this.fecha, required this.ingresos, required this.gastos});

  factory LineaDia.fromJson(Map<String, dynamic> json) => LineaDia(
        fecha: DateTime.parse(json['fecha'] as String),
        ingresos: double.parse(json['ingresos'].toString()),
        gastos: double.parse(json['gastos'].toString()),
      );

  final DateTime fecha;
  final double ingresos;
  final double gastos;
}

/// Un mes del ano, para la tendencia.
class LineaMes {
  const LineaMes({
    required this.mes,
    required this.ingresos,
    required this.gastos,
    required this.balance,
  });

  factory LineaMes.fromJson(Map<String, dynamic> json) => LineaMes(
        mes: json['mes'] as int,
        ingresos: double.parse(json['ingresos'].toString()),
        gastos: double.parse(json['gastos'].toString()),
        balance: double.parse(json['balance'].toString()),
      );

  final int mes;
  final double ingresos;
  final double gastos;
  final double balance;

  bool get sinDatos => ingresos == 0 && gastos == 0;
}
