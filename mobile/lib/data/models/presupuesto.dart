import 'package:app_finanzas/data/models/categoria.dart';

/// Aviso del RF-004: al llegar al 80 % y al 100 % del límite.
enum AlertaPresupuesto {
  atencion,
  limite;

  static AlertaPresupuesto? desdeValor(String? valor) => switch (valor) {
        'atencion' => AlertaPresupuesto.atencion,
        'limite' => AlertaPresupuesto.limite,
        _ => null,
      };
}

/// Límite de gasto de una categoría en un mes (RF-004).
///
/// Lo gastado, el porcentaje y la alerta los calcula el servidor a partir de
/// los movimientos del mes.
class Presupuesto {
  const Presupuesto({
    required this.id,
    required this.categoriaId,
    required this.anio,
    required this.mes,
    required this.limite,
    required this.gastado,
    required this.disponible,
    required this.porcentaje,
    required this.categoria,
    this.alerta,
  });

  factory Presupuesto.fromJson(Map<String, dynamic> json) => Presupuesto(
        id: json['id'] as int,
        categoriaId: json['category_id'] as int,
        anio: json['anio'] as int,
        mes: json['mes'] as int,
        limite: double.parse(json['limite'].toString()),
        gastado: double.parse(json['gastado'].toString()),
        disponible: double.parse(json['disponible'].toString()),
        porcentaje: (json['porcentaje'] as num).toDouble(),
        alerta: AlertaPresupuesto.desdeValor(json['alerta'] as String?),
        categoria: Categoria.fromJson(json['categoria'] as Map<String, dynamic>),
      );

  final int id;
  final int categoriaId;
  final int anio;
  final int mes;
  final double limite;
  final double gastado;

  /// Lo que queda por gastar. Negativo si ya se pasó del límite.
  final double disponible;
  final double porcentaje;
  final AlertaPresupuesto? alerta;
  final Categoria categoria;

  bool get excedido => disponible < 0;

  String get porcentajeTexto => '${porcentaje.round()} %';

  /// Texto del aviso para mostrar al usuario, o null si todavía no corresponde.
  String? get mensajeDeAlerta => switch (alerta) {
        AlertaPresupuesto.limite when excedido =>
          'Te pasaste del presupuesto de ${categoria.nombre}: '
              'ya usaste el $porcentajeTexto del límite.',
        AlertaPresupuesto.limite =>
          'Llegaste al límite del presupuesto de ${categoria.nombre}.',
        AlertaPresupuesto.atencion =>
          'Ya usaste el $porcentajeTexto del presupuesto de ${categoria.nombre}.',
        null => null,
      };
}
