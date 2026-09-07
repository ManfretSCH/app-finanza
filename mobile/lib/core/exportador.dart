import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Formatos en los que se puede bajar el informe (RF-006, RF-007).
enum FormatoExportacion {
  csv('csv', 'CSV para planilla', 'Se abre en Excel o Google Sheets'),
  pdf('pdf', 'PDF para imprimir', 'Informe con el resumen y el detalle');

  const FormatoExportacion(this.extension, this.titulo, this.detalle);

  final String extension;
  final String titulo;
  final String detalle;
}

/// Guarda los bytes en un archivo temporal y abre el menu de compartir.
///
/// Se escribe en el directorio temporal de la app, que no necesita ningun
/// permiso de almacenamiento en Android. Desde el menu de compartir el usuario
/// elige que hacer: guardarlo en Archivos, mandarlo por correo o WhatsApp,
/// subirlo a Drive. Pedir permiso de escritura para dejarlo en Descargas seria
/// mas invasivo y daria el mismo resultado.
Future<void> compartirArchivo({
  required List<int> bytes,
  required String nombre,
  required String descripcion,
}) async {
  final carpeta = await getTemporaryDirectory();
  final archivo = File('${carpeta.path}/$nombre');
  await archivo.writeAsBytes(bytes, flush: true);

  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(archivo.path)],
      subject: descripcion,
    ),
  );
}

/// Nombre del archivo, igual al que arma el backend.
String nombreDeArchivo(int mes, int anio, String extension) =>
    'finanzas-$anio-${mes.toString().padLeft(2, '0')}.$extension';
