// El nombre del archivo lo arman por separado el backend y la app.
// Si se separan, el usuario baja un archivo con un nombre distinto al esperado.

import 'package:app_finanzas/core/exportador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('el nombre del archivo lleva el mes con dos dígitos', () {
    expect(nombreDeArchivo(9, 2026, 'csv'), 'finanzas-2026-09.csv');
    expect(nombreDeArchivo(12, 2026, 'pdf'), 'finanzas-2026-12.pdf');
    expect(nombreDeArchivo(1, 2026, 'csv'), 'finanzas-2026-01.csv');
  });

  test('los dos formatos ofrecidos son csv y pdf', () {
    expect(
      FormatoExportacion.values.map((f) => f.extension),
      ['csv', 'pdf'],
    );
    // Cada opcion se muestra al usuario, asi que ninguna puede quedar sin texto.
    for (final formato in FormatoExportacion.values) {
      expect(formato.titulo, isNotEmpty);
      expect(formato.detalle, isNotEmpty);
    }
  });
}
