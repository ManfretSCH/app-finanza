import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/categoria.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/data/models/informe.dart';
import 'package:app_finanzas/data/models/meta_ahorro.dart';
import 'package:app_finanzas/data/models/movimiento_fijo.dart';
import 'package:app_finanzas/data/models/presupuesto.dart';
import 'package:app_finanzas/data/models/tipo_cuenta.dart';
import 'package:app_finanzas/data/models/transaccion.dart';
import 'package:app_finanzas/data/models/usuario.dart';
import 'package:app_finanzas/data/repositories/auth_repository.dart';
import 'package:app_finanzas/data/repositories/categorias_repository.dart';
import 'package:app_finanzas/data/repositories/cuentas_repository.dart';
import 'package:app_finanzas/data/repositories/informes_repository.dart';
import 'package:app_finanzas/data/repositories/metas_repository.dart';
import 'package:app_finanzas/data/repositories/movimientos_fijos_repository.dart';
import 'package:app_finanzas/data/repositories/presupuestos_repository.dart';
import 'package:app_finanzas/data/repositories/tipos_cuenta_repository.dart';
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

final tiposCuentaRepositoryProvider =
    Provider((ref) => TiposCuentaRepository(ref.watch(apiClientProvider)));

final informesRepositoryProvider =
    Provider((ref) => InformesRepository(ref.watch(apiClientProvider)));

final presupuestosRepositoryProvider =
    Provider((ref) => PresupuestosRepository(ref.watch(apiClientProvider)));

final metasRepositoryProvider = Provider((ref) => MetasRepository(ref.watch(apiClientProvider)));

final movimientosFijosRepositoryProvider =
    Provider((ref) => MovimientosFijosRepository(ref.watch(apiClientProvider)));

// --- Sesion ---

/// Usuario con la sesion iniciada, o null si no hay ninguno.
///
/// Al arrancar la app intenta recuperar la sesion desde el token guardado,
/// para que el usuario no tenga que escribir la contrasena cada vez.
class SesionNotifier extends AsyncNotifier<Usuario?> {
  @override
  Future<Usuario?> build() async {
    final usuario = await ref.watch(authRepositoryProvider).usuarioActual();
    if (usuario != null) await _ponerAlDiaLosFijos();
    return usuario;
  }

  /// Genera los movimientos fijos que falten desde la ultima vez.
  ///
  /// Se hace antes de devolver el usuario, para que cuando las pantallas pidan
  /// los datos ya esten los movimientos del mes. Si falla no se corta el
  /// ingreso: es preferible entrar con los fijos desactualizados a no entrar.
  Future<void> _ponerAlDiaLosFijos() async {
    try {
      await ref.read(movimientosFijosRepositoryProvider).ponerseAlDia();
    } catch (_) {
      // Sin conexion o error del servidor: se reintenta el proximo ingreso.
    }
  }

  Future<void> iniciarSesion(String email, String password) async {
    final usuario = await ref
        .read(authRepositoryProvider)
        .iniciarSesion(email: email, password: password);
    await _ponerAlDiaLosFijos();
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
    // Al quedar en null, usuarioIdProvider cambia y todos los providers de
    // datos se recalculan solos.
    state = const AsyncData(null);
  }
}

/// Sin reintento automatico. Riverpod repetiria el pedido hasta 10 veces con la
/// ruedita girando, y si el servidor no contesta eso pueden ser varios minutos.
/// Es mejor mostrar el error enseguida y que el usuario decida cuando reintentar.
final sesionProvider = AsyncNotifierProvider<SesionNotifier, Usuario?>(
  SesionNotifier.new,
  retry: (_, _) => null,
);

/// Id del usuario con la sesion iniciada, o null si no hay ninguno.
///
/// Todos los providers que traen datos del servidor lo observan. Asi, cuando
/// cambia el usuario, cada uno vuelve a pedir lo suyo en lugar de quedarse con
/// lo que habia cargado el anterior. Invalidarlos a mano al cerrar sesion era
/// fragil: bastaba olvidarse de uno para que el usuario nuevo viera, por un
/// momento, los numeros del anterior.
final usuarioIdProvider = Provider<int?>((ref) => ref.watch(sesionProvider).value?.id);

// --- Datos ---
// Se usan FutureProvider y ref.invalidate despues de cada cambio: es la forma
// mas simple de mantener la pantalla al dia sin duplicar el estado del servidor.

final cuentasProvider = FutureProvider<List<Cuenta>>((ref) {
  ref.watch(usuarioIdProvider);
  return ref.watch(cuentasRepositoryProvider).listar();
});

final categoriasProvider = FutureProvider<List<Categoria>>((ref) {
  ref.watch(usuarioIdProvider);
  return ref.watch(categoriasRepositoryProvider).listar();
});

/// Filtro activo del listado de movimientos (null = todos).
class FiltroTipoNotifier extends Notifier<TipoMovimiento?> {
  @override
  TipoMovimiento? build() => null;

  void cambiar(TipoMovimiento? tipo) => state = tipo;
}

final filtroTipoProvider =
    NotifierProvider<FiltroTipoNotifier, TipoMovimiento?>(FiltroTipoNotifier.new);

final transaccionesProvider = FutureProvider<List<Transaccion>>((ref) {
  ref.watch(usuarioIdProvider);
  return ref.watch(transaccionesRepositoryProvider).listar(
        tipo: ref.watch(filtroTipoProvider),
      );
});

final tiposCuentaProvider = FutureProvider<List<TipoCuenta>>((ref) {
  ref.watch(usuarioIdProvider);
  return ref.watch(tiposCuentaRepositoryProvider).listar();
});

/// Presupuestos del mes elegido en el selector, con lo gastado y sus alertas.
///
/// Usa el mismo mes que los informes: las dos pantallas miran el mismo mes.
final presupuestosProvider = FutureProvider<List<Presupuesto>>((ref) {
  ref.watch(usuarioIdProvider);
  final mes = ref.watch(mesSeleccionadoProvider);
  return ref.watch(presupuestosRepositoryProvider).listar(mes: mes.month, anio: mes.year);
});

/// Presupuestos del mes en curso que ya dispararon una alerta (80 % o 100 %).
///
/// Es independiente del mes elegido en el selector: el aviso de la barra de
/// navegacion tiene que hablar siempre de este mes.
final alertasPresupuestoProvider = FutureProvider<List<Presupuesto>>((ref) async {
  ref.watch(usuarioIdProvider);
  final hoy = DateTime.now();
  final lista =
      await ref.watch(presupuestosRepositoryProvider).listar(mes: hoy.month, anio: hoy.year);
  return lista.where((p) => p.alerta != null).toList();
});

final metasProvider = FutureProvider<List<MetaAhorro>>((ref) {
  ref.watch(usuarioIdProvider);
  return ref.watch(metasRepositoryProvider).listar();
});

final movimientosFijosProvider = FutureProvider<List<MovimientoFijo>>((ref) {
  ref.watch(usuarioIdProvider);
  return ref.watch(movimientosFijosRepositoryProvider).listar();
});

// --- Informes ---

/// Mes que se esta mirando en Informes y en Planificacion.
class MesSeleccionadoNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final hoy = DateTime.now();
    return DateTime(hoy.year, hoy.month);
  }

  void mover(int meses) {
    final nuevo = DateTime(state.year, state.month + meses);
    // No tiene sentido navegar al futuro: todavia no hay nada que informar.
    final hoy = DateTime.now();
    if (nuevo.isAfter(DateTime(hoy.year, hoy.month))) return;
    state = nuevo;
  }
}

final mesSeleccionadoProvider =
    NotifierProvider<MesSeleccionadoNotifier, DateTime>(MesSeleccionadoNotifier.new);

final resumenProvider = FutureProvider<ResumenMensual>((ref) {
  ref.watch(usuarioIdProvider);
  final mes = ref.watch(mesSeleccionadoProvider);
  return ref.watch(informesRepositoryProvider).resumen(mes: mes.month, anio: mes.year);
});

final gastosPorCategoriaProvider = FutureProvider<List<LineaCategoria>>((ref) {
  ref.watch(usuarioIdProvider);
  final mes = ref.watch(mesSeleccionadoProvider);
  return ref.watch(informesRepositoryProvider).porCategoria(
        tipo: TipoMovimiento.gasto,
        mes: mes.month,
        anio: mes.year,
      );
});

final ingresosPorCategoriaProvider = FutureProvider<List<LineaCategoria>>((ref) {
  ref.watch(usuarioIdProvider);
  final mes = ref.watch(mesSeleccionadoProvider);
  return ref.watch(informesRepositoryProvider).porCategoria(
        tipo: TipoMovimiento.ingreso,
        mes: mes.month,
        anio: mes.year,
      );
});

final porDiaProvider = FutureProvider<List<LineaDia>>((ref) {
  ref.watch(usuarioIdProvider);
  final mes = ref.watch(mesSeleccionadoProvider);
  return ref.watch(informesRepositoryProvider).porDia(mes: mes.month, anio: mes.year);
});

final tendenciaAnualProvider = FutureProvider<List<LineaMes>>((ref) {
  ref.watch(usuarioIdProvider);
  final mes = ref.watch(mesSeleccionadoProvider);
  return ref.watch(informesRepositoryProvider).porMes(anio: mes.year);
});

/// Recarga todo lo que depende del servidor tras registrar o borrar un movimiento.
///
/// Los informes se derivan de las transacciones, asi que tienen que recalcularse
/// junto con ellas: si no, el saldo cambia pero el informe queda viejo.
///
/// Lo gastado de cada presupuesto tambien sale de los movimientos.
void refrescarDatos(WidgetRef ref) {
  ref.invalidate(cuentasProvider);
  ref.invalidate(transaccionesProvider);
  ref.invalidate(resumenProvider);
  ref.invalidate(gastosPorCategoriaProvider);
  ref.invalidate(ingresosPorCategoriaProvider);
  ref.invalidate(porDiaProvider);
  ref.invalidate(tendenciaAnualProvider);
  refrescarPresupuestos(ref);
}

/// Recarga los presupuestos y sus alertas tras crear, editar o borrar uno.
void refrescarPresupuestos(WidgetRef ref) {
  ref.invalidate(presupuestosProvider);
  ref.invalidate(alertasPresupuestoProvider);
}

/// Recarga los movimientos fijos y todo lo que ellos generan.
///
/// Crear o editar un fijo crea movimientos de verdad, asi que cambian tambien
/// los saldos, la lista y los informes.
void refrescarFijos(WidgetRef ref) {
  ref.invalidate(movimientosFijosProvider);
  refrescarDatos(ref);
}

/// Recarga los catalogos y todo lo que los muestra.
void refrescarCatalogos(WidgetRef ref) {
  ref.invalidate(categoriasProvider);
  ref.invalidate(tiposCuentaProvider);
  ref.invalidate(cuentasProvider);
}
