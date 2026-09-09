import 'package:app_finanzas/data/models/categoria.dart';

class Transaccion {
  const Transaccion({
    required this.id,
    required this.cuentaId,
    required this.categoriaId,
    required this.tipo,
    required this.monto,
    required this.fecha,
    this.descripcion,
    this.categoria,
    this.recurrenteId,
  });

  factory Transaccion.fromJson(Map<String, dynamic> json) => Transaccion(
        id: json['id'] as int,
        cuentaId: json['account_id'] as int,
        categoriaId: json['category_id'] as int,
        tipo: TipoMovimiento.desdeValor(json['tipo'] as String),
        monto: double.parse(json['monto'].toString()),
        fecha: DateTime.parse(json['fecha'] as String),
        descripcion: json['descripcion'] as String?,
        recurrenteId: json['recurring_id'] as int?,
        categoria: json['categoria'] == null
            ? null
            : Categoria.fromJson(json['categoria'] as Map<String, dynamic>),
      );

  final int id;
  final int cuentaId;
  final int categoriaId;
  final TipoMovimiento tipo;
  final double monto;
  final DateTime fecha;
  final String? descripcion;
  final Categoria? categoria;
  /// Id del movimiento fijo que lo genero, si salio de uno.
  final int? recurrenteId;

  /// Los generados por un movimiento fijo se marcan en la lista, para que
  /// nadie se pregunte de donde salio algo que no cargo a mano.
  bool get esFijo => recurrenteId != null;

  bool get esIngreso => tipo == TipoMovimiento.ingreso;
}
