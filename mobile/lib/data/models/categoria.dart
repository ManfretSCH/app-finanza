enum TipoMovimiento {
  ingreso('ingreso', 'Ingreso'),
  gasto('gasto', 'Gasto');

  const TipoMovimiento(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static TipoMovimiento desdeValor(String valor) =>
      valor == 'ingreso' ? TipoMovimiento.ingreso : TipoMovimiento.gasto;
}

class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.color,
    required this.esPredefinida,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) => Categoria(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        tipo: TipoMovimiento.desdeValor(json['tipo'] as String),
        color: json['color'] as String,
        esPredefinida: json['es_predefinida'] as bool,
      );

  final int id;
  final String nombre;
  final TipoMovimiento tipo;
  final String color;
  final bool esPredefinida;

  /// Convierte "#RRGGBB" del backend al entero que usa Flutter.
  int get colorEntero => int.parse('FF${color.substring(1)}', radix: 16);
}
