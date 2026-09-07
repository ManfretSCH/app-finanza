import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/features/catalogos/formulario_categoria.dart';
import 'package:app_finanzas/features/catalogos/formulario_tipo_cuenta.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Administracion de los catalogos del sistema: categorias (RF-003) y tipos de cuenta.
///
/// Los predefinidos se muestran pero no se pueden tocar; los propios del usuario
/// se editan y se borran.
class CatalogosScreen extends StatelessWidget {
  const CatalogosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorias y tipos'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Categorias', icon: Icon(Icons.label_outline)),
              Tab(text: 'Tipos de cuenta', icon: Icon(Icons.account_balance_wallet_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_PestanaCategorias(), _PestanaTiposDeCuenta()],
        ),
      ),
    );
  }
}

class _PestanaCategorias extends ConsumerWidget {
  const _PestanaCategorias();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categorias = ref.watch(categoriasProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nueva-categoria',
        onPressed: () => abrirFormularioCategoria(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nueva categoria'),
      ),
      body: categorias.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoError(
          mensaje: mensajeDeError(e),
          alReintentar: () => ref.invalidate(categoriasProvider),
        ),
        data: (lista) {
          final gastos = lista.where((c) => c.tipo == TipoMovimiento.gasto).toList();
          final ingresos = lista.where((c) => c.tipo == TipoMovimiento.ingreso).toList();

          return ListView(
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              const _Encabezado(texto: 'Gastos'),
              for (final c in gastos) _FilaCategoria(categoria: c),
              const _Encabezado(texto: 'Ingresos'),
              for (final c in ingresos) _FilaCategoria(categoria: c),
            ],
          );
        },
      ),
    );
  }
}

class _FilaCategoria extends ConsumerWidget {
  const _FilaCategoria({required this.categoria});

  final Categoria categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(categoria.colorEntero),
        radius: 14,
      ),
      title: Text(categoria.nombre),
      subtitle: categoria.esPredefinida ? const Text('Del sistema') : null,
      trailing: categoria.esPredefinida
          // Las del sistema son de todos: dejarlas editar romperia las de otros.
          ? Icon(Icons.lock_outline, color: Theme.of(context).colorScheme.outline, size: 18)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar',
                  onPressed: () => abrirFormularioCategoria(context, ref, categoria: categoria),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Eliminar',
                  onPressed: () => _eliminar(context, ref),
                ),
              ],
            ),
    );
  }

  Future<void> _eliminar(BuildContext context, WidgetRef ref) async {
    final confirmado = await confirmar(
      context,
      titulo: 'Eliminar categoria',
      mensaje: 'Se eliminara "${categoria.nombre}".',
    );
    if (!confirmado) return;

    try {
      await ref.read(categoriasRepositoryProvider).eliminar(categoria.id);
      refrescarCatalogos(ref);
    } catch (e) {
      if (context.mounted) mostrarAviso(context, mensajeDeError(e));
    }
  }
}

class _PestanaTiposDeCuenta extends ConsumerWidget {
  const _PestanaTiposDeCuenta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipos = ref.watch(tiposCuentaProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'nuevo-tipo',
        onPressed: () => abrirFormularioTipoCuenta(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo tipo'),
      ),
      body: tipos.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EstadoError(
          mensaje: mensajeDeError(e),
          alReintentar: () => ref.invalidate(tiposCuentaProvider),
        ),
        data: (lista) => ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            for (final tipo in lista)
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet, size: 18)),
                title: Text(tipo.nombre),
                subtitle: tipo.esPredefinido ? const Text('Del sistema') : null,
                trailing: tipo.esPredefinido
                    ? Icon(
                        Icons.lock_outline,
                        color: Theme.of(context).colorScheme.outline,
                        size: 18,
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Editar',
                            onPressed: () =>
                                abrirFormularioTipoCuenta(context, ref, tipo: tipo),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Eliminar',
                            onPressed: () async {
                              final confirmado = await confirmar(
                                context,
                                titulo: 'Eliminar tipo de cuenta',
                                mensaje: 'Se eliminara "${tipo.nombre}".',
                              );
                              if (!confirmado) return;
                              try {
                                await ref
                                    .read(tiposCuentaRepositoryProvider)
                                    .eliminar(tipo.id);
                                refrescarCatalogos(ref);
                              } catch (e) {
                                if (context.mounted) {
                                  mostrarAviso(context, mensajeDeError(e));
                                }
                              }
                            },
                          ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1,
            ),
      ),
    );
  }
}
