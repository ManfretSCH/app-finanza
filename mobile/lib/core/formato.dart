import 'package:intl/intl.dart';

/// Formatea un monto con separador de miles.
///
/// El guarani no usa decimales; las demas monedas si.
String formatearMonto(num monto, [String moneda = 'PYG']) {
  final decimales = moneda == 'PYG' ? 0 : 2;
  final formato = NumberFormat.currency(
    locale: 'es',
    symbol: '',
    decimalDigits: decimales,
  );
  return '${formato.format(monto).trim()} $moneda';
}

String formatearFecha(DateTime fecha) => DateFormat('dd/MM/yyyy').format(fecha);

String formatearFechaLarga(DateTime fecha) =>
    DateFormat("d 'de' MMMM 'de' y", 'es').format(fecha);
