import 'package:app_finanzas/data/models/categoria.dart';

/// Plantilla de un movimiento que se repite todos los meses.
///
/// No es un movimiento: a partir de ella el servidor genera una transacción
/// real cada mes.
class MovimientoFijo {
  const MovimientoFijo({
    required this.id,
    required this.cuentaId,
    required this.categoriaId,
    required this.tipo,
    required this.monto,
    required this.diaDelMes,
    required this.fechaInicio,
    required this.activo,
    this.fechaFin,
    this.descripcion,
    this.categoria,
  });

  factory MovimientoFijo.fromJson(Map<String, dynamic> json) => MovimientoFijo(
        id: json['id'] as int,
        cuentaId: json['account_id'] as int,
        categoriaId: json['category_id'] as int,
        tipo: TipoMovimiento.desdeValor(json['tipo'] as String),
        monto: double.parse(json['monto'].toString()),
        diaDelMes: json['dia_del_mes'] as int,
        fechaInicio: DateTime.parse(json['fecha_inicio'] as String),
        fechaFin: json['fecha_fin'] == null
            ? null
            : DateTime.parse(json['fecha_fin'] as String),
        activo: json['activo'] as bool,
        descripcion: json['descripcion'] as String?,
        categoria: json['categoria'] == null
            ? null
            : Categoria.fromJson(json['categoria'] as Map<String, dynamic>),
      );

  final int id;
  final int cuentaId;
  final int categoriaId;
  final TipoMovimiento tipo;
  final double monto;
  final int diaDelMes;
  final DateTime fechaInicio;
  final DateTime? fechaFin;
  final bool activo;
  final String? descripcion;
  final Categoria? categoria;

  bool get esIngreso => tipo == TipoMovimiento.ingreso;

  /// "Todos los días 1" o "El último día de cada mes" cuando se pidió el 31.
  String get cuandoOcurre {
    if (diaDelMes >= 29) {
      return 'Cada mes el día $diaDelMes (o el último, si el mes no llega)';
    }
    return 'Todos los meses el día $diaDelMes';
  }
}
