import 'package:app_finanzas/data/models/tipo_cuenta.dart';

class Cuenta {
  const Cuenta({
    required this.id,
    required this.nombre,
    required this.tipoId,
    required this.saldoInicial,
    required this.saldoActual,
    required this.moneda,
    required this.activa,
    this.tipo,
  });

  factory Cuenta.fromJson(Map<String, dynamic> json) => Cuenta(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        tipoId: json['account_type_id'] as int,
        saldoInicial: double.parse(json['saldo_inicial'].toString()),
        // saldo_actual solo viene en los listados y el detalle, no al crear.
        saldoActual: double.parse((json['saldo_actual'] ?? json['saldo_inicial']).toString()),
        moneda: json['moneda'] as String,
        activa: json['activa'] as bool,
        tipo: json['tipo'] == null
            ? null
            : TipoCuenta.fromJson(json['tipo'] as Map<String, dynamic>),
      );

  final int id;
  final String nombre;
  final int tipoId;
  final double saldoInicial;
  final double saldoActual;
  final String moneda;
  final bool activa;
  final TipoCuenta? tipo;
}
