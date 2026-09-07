/// Tipo de cuenta. Los que tienen esPredefinido son los cuatro del sistema;
/// el resto los creo el usuario y puede editarlos o borrarlos.
class TipoCuenta {
  const TipoCuenta({
    required this.id,
    required this.nombre,
    required this.icono,
    required this.esPredefinido,
  });

  factory TipoCuenta.fromJson(Map<String, dynamic> json) => TipoCuenta(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        icono: json['icono'] as String,
        esPredefinido: json['es_predefinido'] as bool,
      );

  final int id;
  final String nombre;
  final String icono;
  final bool esPredefinido;
}
