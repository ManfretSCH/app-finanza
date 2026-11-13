import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/formato.dart';
import 'package:app_finanzas/core/tema.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/meta_ahorro.dart';
import 'package:app_finanzas/features/planificacion/meta_form.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Casos de uso del diagrama 05: Crear meta de ahorro y Ver metas, con el
/// progreso de cada una a la vista (RF-005).
class MetasTab extends ConsumerWidget {
  const MetasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metas = ref.watch(metasProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nueva-meta',
        onPressed: () => abrirFormularioMeta(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
      ),
      body: metas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoError(
          mensaje: mensajeDeError(e),
          alReintentar: () => ref.invalidate(metasProvider),
        ),
        data: (lista) {
          if (lista.isEmpty) {
            return const EstadoVacio(
              icono: Icons.savings_outlined,
              titulo: 'Sin metas de ahorro',
              detalle: 'Creá una meta, por ejemplo unas vacaciones o un fondo de '
                  'emergencia, y andá sumando lo que vas juntando.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(metasProvider),
            child: ListView(
              padding: const EdgeInsets.only(top: 8, bottom: 88),
              children: [for (final m in lista) _TarjetaMeta(meta: m)],
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaMeta extends ConsumerWidget {
  const _TarjetaMeta({required this.meta});

  final MetaAhorro meta;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final hoy = DateTime.now();
    final vencida = meta.vencida(hoy);
    final color = switch (meta.estado) {
      EstadoMeta.completada => colorIngreso,
      EstadoMeta.cancelada => tema.colorScheme.outline,
      EstadoMeta.activa when vencida => tema.colorScheme.error,
      EstadoMeta.activa => tema.colorScheme.primary,
    };
    final porMes = meta.ahorroMensualNecesario(hoy);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _acciones(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnilloDeProgreso(progreso: meta.progreso, color: color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(meta.nombre, style: tema.textTheme.titleMedium),
                            ),
                            if (!meta.activa)
                              Text(
                                meta.estado.etiqueta,
                                style: tema.textTheme.labelMedium?.copyWith(color: color),
                              ),
                          ],
                        ),
                        if (meta.descripcion?.isNotEmpty ?? false)
                          Text(meta.descripcion!, style: tema.textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Text(
                          '${formatearMonto(meta.montoActual)} de '
                          '${formatearMonto(meta.montoObjetivo)}',
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _detalle(meta, vencida),
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: vencida ? color : null,
                          ),
                        ),
                        if (porMes != null)
                          Text(
                            'Juntando ${formatearMonto(porMes)} por mes llegás a tiempo',
                            style: tema.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (meta.activa) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonalIcon(
                    onPressed: () => _sumarAhorro(context, ref),
                    icon: const Icon(Icons.add),
                    label: const Text('Sumar ahorro'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _detalle(MetaAhorro meta, bool vencida) => switch (meta.estado) {
        EstadoMeta.completada => '¡Meta cumplida!',
        EstadoMeta.cancelada => 'Meta cancelada',
        EstadoMeta.activa when vencida =>
          'Venció el ${formatearFecha(meta.fechaObjetivo)} · '
              'faltan ${formatearMonto(meta.faltante)}',
        EstadoMeta.activa =>
          'Faltan ${formatearMonto(meta.faltante)} para el '
              '${formatearFecha(meta.fechaObjetivo)}',
      };

  Future<void> _sumarAhorro(BuildContext context, WidgetRef ref) async {
    final monto = await showDialog<double>(
      context: context,
      builder: (_) => _DialogoAporte(meta: meta),
    );
    if (monto == null || !context.mounted) return;

    try {
      final actualizada = await ref.read(metasRepositoryProvider).aportar(meta.id, monto);
      ref.invalidate(metasProvider);
      if (!context.mounted) return;
      mostrarAviso(
        context,
        actualizada.estado == EstadoMeta.completada
            ? '¡Cumpliste la meta "${meta.nombre}"!'
            : 'Sumaste ${formatearMonto(monto)} a "${meta.nombre}".',
      );
    } catch (e) {
      if (context.mounted) mostrarAviso(context, mensajeDeError(e));
    }
  }

  Future<void> _acciones(BuildContext context, WidgetRef ref) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (meta.activa)
              ListTile(
                leading: const Icon(Icons.add_circle_outline),
                title: const Text('Sumar ahorro'),
                onTap: () => Navigator.of(context).pop('sumar'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              subtitle: const Text('Nombre, objetivo, fecha o total ahorrado'),
              onTap: () => Navigator.of(context).pop('editar'),
            ),
            if (meta.estado == EstadoMeta.cancelada)
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Reactivar'),
                onTap: () => Navigator.of(context).pop('reactivar'),
              )
            else if (meta.activa)
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Cancelar meta'),
                subtitle: const Text('Queda guardada y la podés reactivar'),
                onTap: () => Navigator.of(context).pop('cancelar'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Eliminar'),
              onTap: () => Navigator.of(context).pop('eliminar'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (accion == null || !context.mounted) return;

    final repo = ref.read(metasRepositoryProvider);
    try {
      switch (accion) {
        case 'sumar':
          await _sumarAhorro(context, ref);
          return;
        case 'editar':
          await abrirFormularioMeta(context, ref, meta: meta);
          return;
        case 'cancelar':
          await repo.cambiarEstado(meta.id, EstadoMeta.cancelada);
        case 'reactivar':
          await repo.cambiarEstado(meta.id, EstadoMeta.activa);
        case 'eliminar':
          final confirmado = await confirmar(
            context,
            titulo: 'Eliminar meta',
            mensaje: 'Se borra "${meta.nombre}" y lo que llevabas anotado. '
                'No se puede deshacer.',
          );
          if (!confirmado) return;
          await repo.eliminar(meta.id);
      }
      ref.invalidate(metasProvider);
    } catch (e) {
      if (context.mounted) mostrarAviso(context, mensajeDeError(e));
    }
  }
}

/// Gráfico circular con el porcentaje ahorrado en el centro.
class AnilloDeProgreso extends StatelessWidget {
  const AnilloDeProgreso({required this.progreso, required this.color, super.key});

  /// De 0 a 100.
  final double progreso;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (progreso / 100).clamp(0, 1).toDouble(),
            strokeWidth: 7,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          Center(
            child: Text(
              '${progreso.round()} %',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pide cuánto se suma a la meta. Devuelve el monto, o null si se cancela.
class _DialogoAporte extends StatefulWidget {
  const _DialogoAporte({required this.meta});

  final MetaAhorro meta;

  @override
  State<_DialogoAporte> createState() => _DialogoAporteState();
}

class _DialogoAporteState extends State<_DialogoAporte> {
  final _formulario = GlobalKey<FormState>();
  final _monto = TextEditingController();

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  void _aceptar() {
    if (!_formulario.currentState!.validate()) return;
    Navigator.of(context).pop(double.parse(_monto.text.replaceAll(',', '.')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sumar a "${widget.meta.nombre}"'),
      content: Form(
        key: _formulario,
        child: TextFormField(
          controller: _monto,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Monto',
            suffixText: 'PYG',
            helperText: 'Faltan ${formatearMonto(widget.meta.faltante)}',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onFieldSubmitted: (_) => _aceptar(),
          validator: (v) {
            final n = double.tryParse((v ?? '').replaceAll(',', '.'));
            if (n == null) return 'Ingresa un número válido';
            if (n <= 0) return 'El monto debe ser mayor a cero';
            return null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _aceptar, child: const Text('Sumar')),
      ],
    );
  }
}
