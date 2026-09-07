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

/// Version corta para las etiquetas de los graficos, donde no entra el numero
/// completo: 3.250.000 se muestra como "3,3 M".
String formatearMontoCompacto(num monto) {
  final valor = monto.abs();
  if (valor >= 1000000) {
    return '${NumberFormat('#,##0.#', 'es').format(monto / 1000000)} M';
  }
  if (valor >= 1000) {
    return '${NumberFormat('#,##0', 'es').format(monto / 1000)} k';
  }
  return NumberFormat('#,##0', 'es').format(monto);
}

String formatearFecha(DateTime fecha) => DateFormat('dd/MM/yyyy').format(fecha);

String formatearFechaLarga(DateTime fecha) =>
    DateFormat("d 'de' MMMM 'de' y", 'es').format(fecha);

/// "Septiembre 2026", para el selector de mes de los informes.
String nombreMesYAnio(DateTime fecha) {
  final texto = DateFormat('MMMM y', 'es').format(fecha);
  return texto[0].toUpperCase() + texto.substring(1);
}

/// "Sep", para las etiquetas del grafico anual.
String abreviaturaMes(int mes) {
  final texto = DateFormat('MMM', 'es').format(DateTime(2000, mes));
  return texto[0].toUpperCase() + texto.substring(1).replaceAll('.', '');
}
