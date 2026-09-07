import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/tema.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/features/transacciones/transaccion_form.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Casos de uso "Ver transacciones", "Filtrar por categoria", "Registrar ingreso/gasto"
/// y "Editar transaccion" (RF-002).
class TransaccionesScreen extends ConsumerWidget {
  const TransaccionesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(transaccionesProvider);
    final filtro = ref.watch(filtroTipoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => abrirFormularioTransaccion(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                for (final opcion in [null, TipoMovimiento.ingreso, TipoMovimiento.gasto])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(opcion?.etiqueta ?? 'Todos'),
                      selected: filtro == opcion,
                      onSelected: (_) =>
                          ref.read(filtroTipoProvider.notifier).cambiar(opcion),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: movimientos.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => EstadoError(
                mensaje: mensajeDeError(e),
                alReintentar: () => ref.invalidate(transaccionesProvider),
              ),
              data: (lista) {
                if (lista.isEmpty) {
                  return const EstadoVacio(
                    icono: Icons.receipt_long_outlined,
                    titulo: 'Sin movimientos',
                    detalle: 'Registra tu primer ingreso o gasto con el boton de abajo.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(transaccionesProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: lista.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final m = lista[i];
                      final color = m.esIngreso ? colorIngreso : colorGasto;
                      final signo = m.esIngreso ? '+' : '-';

                      return Dismissible(
                        key: ValueKey(m.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: const Icon(Icons.delete_outline),
                        ),
                        confirmDismiss: (_) => _confirmarBorrado(context),
                        onDismissed: (_) async {
                          await ref.read(transaccionesRepositoryProvider).eliminar(m.id);
                          refrescarDatos(ref);
                        },
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(
                              m.categoria?.colorEntero ?? 0xFF607D8B,
                            ).withValues(alpha: 0.2),
                            child: Icon(
                              m.esIngreso ? Icons.arrow_downward : Icons.arrow_upward,
                              color: color,
                            ),
                          ),
                          title: Text(m.categoria?.nombre ?? 'Sin categoria'),
                          subtitle: Text(
                            [
                              formatearFecha(m.fecha),
                              if (m.descripcion != null && m.descripcion!.isNotEmpty)
                                m.descripcion!,
                            ].join(' · '),
                          ),
                          trailing: Text(
                            '$signo ${formatearMonto(m.monto)}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: color),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmarBorrado(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar movimiento'),
        content: const Text('Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return confirmado ?? false;
  }
}
