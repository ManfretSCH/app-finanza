// Pruebas de widgets de la app.
// Ejecutar con: flutter test

import 'dart:async';

import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/data/models/usuario.dart';
import 'package:app_finanzas/data/repositories/auth_repository.dart';
import 'package:app_finanzas/features/auth/login_screen.dart';
import 'package:app_finanzas/main.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Repositorio de mentira: en las pruebas no hay backend ni almacenamiento
/// seguro del dispositivo, asi que se responde directamente "no hay sesion".
class AuthRepositoryFalso extends AuthRepository {
  AuthRepositoryFalso() : super(ApiClient(const FlutterSecureStorage()));

  @override
  Future<Usuario?> usuarioActual() async => null;
}

/// Repositorio que no contesta hasta que la prueba lo decide, como el servidor
/// cuando esta arrancando despues de dormirse.
class AuthRepositoryDormido extends AuthRepositoryFalso {
  AuthRepositoryDormido({required this.tardaAlAbrir});

  /// Si es true tambien tarda en recuperar la sesion guardada al abrir la app.
  final bool tardaAlAbrir;
  final sesionGuardada = Completer<Usuario?>();
  final login = Completer<Usuario>();

  @override
  Future<Usuario?> usuarioActual() =>
      tardaAlAbrir ? sesionGuardada.future : super.usuarioActual();

  @override
  Future<Usuario> iniciarSesion({required String email, required String password}) =>
      login.future;
}

/// Arranca la app con un repositorio de mentira, sin esperar a que se estabilice.
Future<void> arrancarApp(WidgetTester tester, {AuthRepository? auth}) => tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth ?? AuthRepositoryFalso())],
        child: const AppFinanzas(),
      ),
    );

/// Arranca la app con el repositorio de mentira y espera a que se estabilice.
Future<void> montarApp(WidgetTester tester, {AuthRepository? auth}) async {
  await arrancarApp(tester, auth: auth);
  await tester.pumpAndSettle();
}

final avisoServidorDormido = find.textContaining('se está despertando');

void main() {
  testWidgets('sin sesión iniciada se muestra la pantalla de login', (tester) async {
    await montarApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Mis Finanzas'), findsOneWidget);
  });

  testWidgets('el login valida el correo y la contraseña antes de enviar', (tester) async {
    await montarApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.text('Ingresa un correo válido'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña'), findsOneWidget);
  });

  testWidgets('desde el login se puede abrir el registro', (tester) async {
    await montarApp(tester);

    await tester.tap(find.text('No tengo cuenta, quiero registrarme'));
    await tester.pumpAndSettle();

    expect(find.text('Mínimo 8 caracteres'), findsOneWidget);
  });

  testWidgets('el registro exige una contraseña de al menos 8 caracteres', (tester) async {
    await montarApp(tester);

    await tester.tap(find.text('No tengo cuenta, quiero registrarme'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@example.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'corta');

    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Debe tener al menos 8 caracteres'), findsOneWidget);
  });

  testWidgets('el registro exige repetir la contraseña', (tester) async {
    await montarApp(tester);
    await tester.tap(find.text('No tengo cuenta, quiero registrarme'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@example.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'claveLarga1');
    // La confirmacion queda vacia a proposito.

    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Repite la contraseña'), findsOneWidget);
  });

  testWidgets('avisa cuando las dos contraseñas no coinciden', (tester) async {
    await montarApp(tester);
    await tester.tap(find.text('No tengo cuenta, quiero registrarme'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@example.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'claveLarga1');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repetir contraseña'),
      'claveLarga2',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('con las dos contraseñas iguales no hay ningún reclamo', (tester) async {
    await montarApp(tester);
    await tester.tap(find.text('No tengo cuenta, quiero registrarme'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@example.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'claveLarga1');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Repetir contraseña'),
      'claveLarga1',
    );
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden'), findsNothing);
    expect(find.text('Repite la contraseña'), findsNothing);
  });

  testWidgets('si recuperar la sesión tarda, se avisa que el servidor se está despertando',
      (tester) async {
    final auth = AuthRepositoryDormido(tardaAlAbrir: true);
    await arrancarApp(tester, auth: auth);

    // Unos segundos de espera son normales y no merecen aviso.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(avisoServidorDormido, findsNothing);

    await tester.pump(AvisoServidorDormido.demora);
    expect(avisoServidorDormido, findsOneWidget);

    // Cuando el servidor por fin contesta se sigue de largo y el aviso se va.
    auth.sesionGuardada.complete(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(avisoServidorDormido, findsNothing);
  });

  testWidgets('si el login tarda, se avisa que el servidor se está despertando', (tester) async {
    final auth = AuthRepositoryDormido(tardaAlAbrir: false);
    await montarApp(tester, auth: auth);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'ana@example.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Contraseña'), 'claveLarga1');
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));

    await tester.pump(const Duration(seconds: 1));
    expect(avisoServidorDormido, findsNothing);

    await tester.pump(AvisoServidorDormido.demora);
    expect(avisoServidorDormido, findsOneWidget);

    // Si ni asi llega la respuesta, el aviso se cambia por un error que invita
    // a reintentar.
    auth.login.completeError(
      DioException(requestOptions: RequestOptions(), type: DioExceptionType.receiveTimeout),
    );
    await tester.pump();
    expect(avisoServidorDormido, findsNothing);
    expect(find.textContaining('tardó demasiado en responder'), findsOneWidget);
  });
}
