import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Caso de uso "Recibir alertas" del diagrama 04 (RF-004).
///
/// Se llama después de guardar un gasto: si con él la categoría llegó al 80 %
/// o al 100 % de su presupuesto de ese mes, se avisa en el momento, que es
/// cuando el aviso sirve para algo.
Future<void> avisarSiCorrespondePresupuesto(
  BuildContext context,
  WidgetRef ref, {
  required int categoriaId,
  required DateTime fecha,
}) async {
  try {
    final presupuestos = await ref
        .read(presupuestosRepositoryProvider)
        .listar(mes: fecha.month, anio: fecha.year);
    final mensaje =
        presupuestos.where((p) => p.categoriaId == categoriaId).firstOrNull?.mensajeDeAlerta;
    if (mensaje == null || !context.mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(child: Text(mensaje)),
            ],
          ),
          duration: const Duration(seconds: 6),
        ),
      );
  } catch (_) {
    // El aviso es un extra: si la consulta falla, el gasto igual quedó guardado
    // y no tiene sentido mostrar un error por algo que el usuario no pidió.
  }
}
