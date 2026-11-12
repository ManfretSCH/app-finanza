import 'dart:math';

enum EstadoMeta {
  activa('activa', 'Activa'),
  completada('completada', 'Cumplida'),
  cancelada('cancelada', 'Cancelada');

  const EstadoMeta(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static EstadoMeta desdeValor(String valor) =>
      EstadoMeta.values.firstWhere((e) => e.valor == valor, orElse: () => EstadoMeta.activa);
}

/// Meta de ahorro con fecha objetivo (RF-005).
///
/// El estado lo decide el servidor: pasa a cumplida sola cuando lo ahorrado
/// alcanza el objetivo.
class MetaAhorro {
  const MetaAhorro({
    required this.id,
    required this.nombre,
    required this.montoObjetivo,
    required this.montoActual,
    required this.fechaObjetivo,
    required this.estado,
    required this.progreso,
    this.descripcion,
  });

  factory MetaAhorro.fromJson(Map<String, dynamic> json) => MetaAhorro(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String?,
        montoObjetivo: double.parse(json['monto_objetivo'].toString()),
        montoActual: double.parse(json['monto_actual'].toString()),
        fechaObjetivo: DateTime.parse(json['fecha_objetivo'] as String),
        estado: EstadoMeta.desdeValor(json['estado'] as String),
        progreso: (json['progreso'] as num).toDouble(),
      );

  final int id;
  final String nombre;
  final String? descripcion;
  final double montoObjetivo;
  final double montoActual;
  final DateTime fechaObjetivo;
  final EstadoMeta estado;

  /// Porcentaje ahorrado, de 0 a 100.
  final double progreso;

  bool get activa => estado == EstadoMeta.activa;

  double get faltante => max(0, montoObjetivo - montoActual);

  /// Una meta activa cuya fecha ya pasó sin juntar el total.
  bool vencida(DateTime hoy) =>
      activa && fechaObjetivo.isBefore(DateTime(hoy.year, hoy.month, hoy.day));

  /// Cuánto habría que ahorrar por mes para llegar a la fecha objetivo.
  ///
  /// Reparte lo que falta entre los meses que quedan, contando el actual. Es
  /// null si la meta no está activa o ya venció: ahí la cuenta no tiene sentido.
  double? ahorroMensualNecesario(DateTime hoy) {
    if (!activa || vencida(hoy) || faltante == 0) return null;
    final meses =
        (fechaObjetivo.year - hoy.year) * 12 + fechaObjetivo.month - hoy.month + 1;
    return faltante / max(1, meses);
  }
}
