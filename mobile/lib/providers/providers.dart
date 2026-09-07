import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/data/models/transaccion.dart';
import 'package:app_finanzas/data/models/usuario.dart';
import 'package:app_finanzas/data/repositories/auth_repository.dart';
import 'package:app_finanzas/data/repositories/categorias_repository.dart';
import 'package:app_finanzas/data/repositories/cuentas_repository.dart';
import 'package:app_finanzas/data/repositories/transacciones_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// --- Infraestructura ---

final almacenamientoProvider = Provider((ref) => const FlutterSecureStorage());

final apiClientProvider = Provider((ref) => ApiClient(ref.watch(almacenamientoProvider)));

// --- Repositorios ---

final authRepositoryProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider)));

final cuentasRepositoryProvider =
    Provider((ref) => CuentasRepository(ref.watch(apiClientProvider)));

final categoriasRepositoryProvider =
    Provider((ref) => CategoriasRepository(ref.watch(apiClientProvider)));

final transaccionesRepositoryProvider =
    Provider((ref) => TransaccionesRepository(ref.watch(apiClientProvider)));

// --- Sesion ---

/// Usuario con la sesion iniciada, o null si no hay ninguno.
///
/// Al arrancar la app intenta recuperar la sesion desde el token guardado,
/// para que el usuario no tenga que escribir la contrasena cada vez.
class SesionNotifier extends AsyncNotifier<Usuario?> {
  @override
  Future<Usuario?> build() => ref.watch(authRepositoryProvider).usuarioActual();

  Future<void> iniciarSesion(String email, String password) async {
    final usuario = await ref
        .read(authRepositoryProvider)
        .iniciarSesion(email: email, password: password);
    state = AsyncData(usuario);
  }

  Future<void> registrar(String nombre, String email, String password) async {
    final usuario = await ref
        .read(authRepositoryProvider)
        .registrar(nombre: nombre, email: email, password: password);
    state = AsyncData(usuario);
  }

  Future<void> cerrarSesion() async {
    await ref.read(authRepositoryProvider).cerrarSesion();
    state = const AsyncData(null);
    // Los datos del usuario anterior no deben quedar en memoria.
    ref.invalidate(cuentasProvider);
    ref.invalidate(transaccionesProvider);
  }
}

final sesionProvider =
    AsyncNotifierProvider<SesionNotifier, Usuario?>(SesionNotifier.new);

// --- Datos ---
// Se usan FutureProvider y ref.invalidate despues de cada cambio: es la forma
// mas simple de mantener la pantalla al dia sin duplicar el estado del servidor.

final cuentasProvider = FutureProvider<List<Cuenta>>(
  (ref) => ref.watch(cuentasRepositoryProvider).listar(),
);

final categoriasProvider = FutureProvider<List<Categoria>>(
  (ref) => ref.watch(categoriasRepositoryProvider).listar(),
);

/// Filtro activo del listado de movimientos (null = todos).
class FiltroTipoNotifier extends Notifier<TipoMovimiento?> {
  @override
  TipoMovimiento? build() => null;

  void cambiar(TipoMovimiento? tipo) => state = tipo;
}

final filtroTipoProvider =
    NotifierProvider<FiltroTipoNotifier, TipoMovimiento?>(FiltroTipoNotifier.new);

final transaccionesProvider = FutureProvider<List<Transaccion>>(
  (ref) => ref.watch(transaccionesRepositoryProvider).listar(
        tipo: ref.watch(filtroTipoProvider),
      ),
);

/// Recarga todo lo que depende del servidor tras registrar o borrar un movimiento.
void refrescarDatos(WidgetRef ref) {
  ref.invalidate(cuentasProvider);
  ref.invalidate(transaccionesProvider);
}
