import 'package:app_finanzas/features/catalogos/catalogos_screen.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Caso de uso "Cerrar sesion" del diagrama de Autenticacion.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuario = ref.watch(sesionProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          Center(
            child: CircleAvatar(
              radius: 40,
              child: Text(
                usuario?.nombre.characters.first.toUpperCase() ?? '?',
                style: const TextStyle(fontSize: 32),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              usuario?.nombre ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Center(child: Text(usuario?.email ?? '')),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Categorias y tipos de cuenta'),
            subtitle: const Text('Crea y edita los tuyos'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CatalogosScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesion'),
            onTap: () => ref.read(sesionProvider.notifier).cerrarSesion(),
          ),
        ],
      ),
    );
  }
}
