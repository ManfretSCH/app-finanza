// Verifica que los datos de un usuario no sobrevivan al cambio de sesion.
//
// Esta prueba nace de un error real: al cerrar sesion se invalidaban las cuentas
// y los movimientos, pero no los informes, asi que el usuario siguiente veia por
// un momento los numeros del anterior.

import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/cuenta.dart';
import 'package:app_finanzas/data/models/usuario.dart';
import 'package:app_finanzas/data/repositories/auth_repository.dart';
import 'package:app_finanzas/data/repositories/cuentas_repository.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Devuelve el usuario que se le indique, sin hablar con ningun servidor.
class AuthRepositoryFalso extends AuthRepository {
  AuthRepositoryFalso() : super(ApiClient(const FlutterSecureStorage()));

  Usuario? usuario;

  @override
  Future<Usuario?> usuarioActual() async => usuario;

  @override
  Future<Usuario> iniciarSesion({required String email, required String password}) async {
    usuario = Usuario(id: email.hashCode, email: email, nombre: email);
    return usuario!;
  }

  @override
  Future<void> cerrarSesion() async => usuario = null;
}

/// Cuenta cada vez que le piden la lista y devuelve una distinta por usuario.
class CuentasRepositoryFalso extends CuentasRepository {
  CuentasRepositoryFalso() : super(ApiClient(const FlutterSecureStorage()));

  int llamadas = 0;
  String duenio = 'ana';

  @override
  Future<List<Cuenta>> listar() async {
    llamadas++;
    return [
      Cuenta(
        id: 1,
        nombre: 'Cuenta de $duenio',
        tipoId: 1,
        saldoInicial: 0,
        saldoActual: 0,
        moneda: 'PYG',
        activa: true,
      ),
    ];
  }
}

void main() {
  test('al cambiar de usuario los datos se vuelven a pedir', () async {
    final auth = AuthRepositoryFalso();
    final cuentas = CuentasRepositoryFalso();

    final contenedor = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        cuentasRepositoryProvider.overrideWithValue(cuentas),
      ],
    );
    addTearDown(contenedor.dispose);

    // Alguien inicia sesion y mira sus cuentas.
    contenedor.listen(cuentasProvider, (_, _) {});
    await contenedor.read(sesionProvider.notifier).iniciarSesion('ana@x.com', 'clave1234');
    final deAna = await contenedor.read(cuentasProvider.future);
    expect(deAna.first.nombre, 'Cuenta de ana');
    final llamadasConAna = cuentas.llamadas;

    // Cierra sesion y entra otra persona.
    await contenedor.read(sesionProvider.notifier).cerrarSesion();
    cuentas.duenio = 'beto';
    await contenedor.read(sesionProvider.notifier).iniciarSesion('beto@x.com', 'clave1234');

    // Lo importante: se vuelve a preguntar al servidor en lugar de reusar
    // lo que ya estaba cargado.
    final deBeto = await contenedor.read(cuentasProvider.future);
    expect(deBeto.first.nombre, 'Cuenta de beto');
    expect(cuentas.llamadas, greaterThan(llamadasConAna));
  });

  test('sin sesión iniciada el id del usuario es null', () async {
    final auth = AuthRepositoryFalso();
    final contenedor = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(contenedor.dispose);

    await contenedor.read(sesionProvider.future);
    expect(contenedor.read(usuarioIdProvider), isNull);

    await contenedor.read(sesionProvider.notifier).iniciarSesion('ana@x.com', 'clave1234');
    expect(contenedor.read(usuarioIdProvider), isNotNull);

    await contenedor.read(sesionProvider.notifier).cerrarSesion();
    expect(contenedor.read(usuarioIdProvider), isNull);
  });
}
