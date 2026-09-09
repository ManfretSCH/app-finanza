import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/tema.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/movimiento_fijo.dart';
import 'package:app_finanzas/features/fijos/fijo_form.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gastos e ingresos que se repiten todos los meses.
///
/// Se cargan una vez y la app genera el movimiento de cada mes al abrirse.
class FijosScreen extends ConsumerWidget {
  const FijosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fijos = ref.watch(movimientosFijosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos fijos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFormularioFijo(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo fijo'),
      ),
      body: fijos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoError(
          mensaje: mensajeDeError(e),
          alReintentar: () => ref.invalidate(movimientosFijosProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const EstadoVacio(
              icono: Icons.event_repeat_outlined,
              titulo: 'Sin gastos fijos',
              detalle:
                  'Cargá acá lo que pagás todos los meses, como el alquiler o '
                  'una cuota. Se va a registrar solo, sin que tengas que anotarlo.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              const _Explicacion(),
              for (final fijo in lista) _FilaFijo(fijo: fijo),
            ],
          );
        },
      ),
    );
  }
}

class _Explicacion extends StatelessWidget {
  const _Explicacion();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Estos movimientos se registran solos cada mes. Si un mes cambia '
                'el monto, editá ese movimiento en la lista.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilaFijo extends ConsumerWidget {
  const _FilaFijo({required this.fijo});

  final MovimientoFijo fijo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = fijo.esIngreso ? colorIngreso : colorGasto;
    final signo = fijo.esIngreso ? '+' : '-';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Color(fijo.categoria?.colorEntero ?? 0xFF607D8B).withValues(alpha: 0.2),
        child: Icon(Icons.event_repeat, color: color),
      ),
      title: Text(fijo.descripcion?.isNotEmpty == true
          ? fijo.descripcion!
          : fijo.categoria?.nombre ?? 'Movimiento fijo'),
      subtitle: Text(
        [
          fijo.cuandoOcurre,
          if (!fijo.activo) 'Pausado',
        ].join(' · '),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$signo ${formatearMonto(fijo.monto)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: fijo.activo ? color : Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
      onTap: () => _acciones(context, ref),
    );
  }

  Future<void> _acciones(BuildContext context, WidgetRef ref) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(fijo.activo ? Icons.pause_circle_outline : Icons.play_circle_outline),
              title: Text(fijo.activo ? 'Pausar' : 'Reanudar'),
              subtitle: Text(
                fijo.activo
                    ? 'Deja de generar movimientos, sin borrar lo ya registrado'
                    : 'Vuelve a generarse todos los meses',
              ),
              onTap: () => Navigator.of(context).pop('alternar'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              subtitle: const Text('Los movimientos ya registrados se conservan'),
              onTap: () => Navigator.of(context).pop('eliminar'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (accion == null || !context.mounted) return;

    try {
      final repo = ref.read(movimientosFijosRepositoryProvider);
      if (accion == 'alternar') {
        await repo.editar(fijo.id, activo: !fijo.activo);
      } else {
        final confirmado = await confirmar(
          context,
          titulo: 'Eliminar gasto fijo',
          mensaje: 'Deja de generarse todos los meses. Los movimientos que ya '
              'se registraron no se borran.',
        );
        if (!confirmado) return;
        await repo.eliminar(fijo.id);
      }
      refrescarFijos(ref);
    } catch (e) {
      if (context.mounted) mostrarAviso(context, mensajeDeError(e));
    }
  }
}
