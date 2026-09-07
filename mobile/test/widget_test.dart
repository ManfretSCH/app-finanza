// Pruebas de widgets de la app.
// Ejecutar con: flutter test

import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/data/models/usuario.dart';
import 'package:app_finanzas/data/repositories/auth_repository.dart';
import 'package:app_finanzas/features/auth/login_screen.dart';
import 'package:app_finanzas/main.dart';
import 'package:app_finanzas/providers/providers.dart';
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

/// Arranca la app con el repositorio de mentira y espera a que se estabilice.
Future<void> montarApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(AuthRepositoryFalso())],
      child: const AppFinanzas(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sin sesion iniciada se muestra la pantalla de login', (tester) async {
    await montarApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Mis Finanzas'), findsOneWidget);
  });

  testWidgets('el login valida el correo y la contrasena antes de enviar', (tester) async {
    await montarApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesion'));
    await tester.pump();

    expect(find.text('Ingresa un correo valido'), findsOneWidget);
    expect(find.text('Ingresa tu contrasena'), findsOneWidget);
  });

  testWidgets('desde el login se puede abrir el registro', (tester) async {
    await montarApp(tester);

    await tester.tap(find.text('No tengo cuenta, quiero registrarme'));
    await tester.pumpAndSettle();

    expect(find.text('Minimo 8 caracteres'), findsOneWidget);
  });

  testWidgets('el registro exige una contrasena de al menos 8 caracteres', (tester) async {
    await montarApp(tester);

    await tester.tap(find.text('No tengo cuenta, quiero registrarme'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nombre'), 'Ana');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electronico'),
      'ana@example.com',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Contrasena'), 'corta');

    await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tester.pump();

    expect(find.text('Debe tener al menos 8 caracteres'), findsOneWidget);
  });
}
