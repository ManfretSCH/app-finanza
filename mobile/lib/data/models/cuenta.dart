enum TipoCuenta {
  ahorro('ahorro', 'Caja de ahorro'),
  corriente('corriente', 'Cuenta corriente'),
  tarjeta('tarjeta', 'Tarjeta de credito'),
  efectivo('efectivo', 'Efectivo');

  const TipoCuenta(this.valor, this.etiqueta);

  final String valor;
  final String etiqueta;

  static TipoCuenta desdeValor(String valor) =>
      TipoCuenta.values.firstWhere((t) => t.valor == valor, orElse: () => TipoCuenta.efectivo);
}

class Cuenta {
  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.saldoInicial,
    required this.saldoActual,
    required this.moneda,
    required this.activa,
  });

  factory Cuenta.fromJson(Map<String, dynamic> json) => Cuenta(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        tipo: TipoCuenta.desdeValor(json['tipo'] as String),
        saldoInicial: double.parse(json['saldo_inicial'].toString()),
        // saldo_actual solo viene en los listados y el detalle, no al crear.
        saldoActual: double.parse((json['saldo_actual'] ?? json['saldo_inicial']).toString()),
        moneda: json['moneda'] as String,
        activa: json['activa'] as bool,
      );

  final int id;
  final String nombre;
  final TipoCuenta tipo;
  final double saldoInicial;
  final double saldoActual;
  final String moneda;
  final bool activa;
}
