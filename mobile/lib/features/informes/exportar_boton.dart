import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/exportador.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Boton de la barra superior para bajar el informe del mes que se esta viendo
/// (caso de uso "Exportar Datos" del diagrama 05).
class BotonExportar extends ConsumerStatefulWidget {
  const BotonExportar({super.key});

  @override
  ConsumerState<BotonExportar> createState() => _BotonExportarState();
}

class _BotonExportarState extends ConsumerState<BotonExportar> {
  bool _descargando = false;

  Future<void> _exportar(FormatoExportacion formato) async {
    final mes = ref.read(mesSeleccionadoProvider);
    setState(() => _descargando = true);
    try {
      final bytes = await ref.read(informesRepositoryProvider).descargarInforme(
            formato: formato.extension,
            mes: mes.month,
            anio: mes.year,
          );
      await compartirArchivo(
        bytes: bytes,
        nombre: nombreDeArchivo(mes.month, mes.year, formato.extension),
        descripcion: 'Informe de ${nombreMesYAnio(mes)}',
      );
    } catch (e) {
      if (mounted) mostrarAviso(context, mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  Future<void> _elegirFormato() async {
    final formato = await showModalBottomSheet<FormatoExportacion>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Exportar informe',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final formato in FormatoExportacion.values)
              ListTile(
                leading: Icon(
                  formato == FormatoExportacion.pdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.table_chart_outlined,
                ),
                title: Text(formato.titulo),
                subtitle: Text(formato.detalle),
                onTap: () => Navigator.of(context).pop(formato),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (formato != null) await _exportar(formato);
  }

  @override
  Widget build(BuildContext context) {
    if (_descargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 18),
        child: Center(
          child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }
    return IconButton(
      onPressed: _elegirFormato,
      icon: const Icon(Icons.ios_share),
      tooltip: 'Exportar informe',
    );
  }
}
