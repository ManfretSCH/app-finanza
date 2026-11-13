import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/core/tema.dart';
import 'package:app_finanzas/core/widgets.dart';
import 'package:app_finanzas/features/auth/login_screen.dart';
import 'package:app_finanzas/features/home/home_screen.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Necesario para formatear fechas y montos en espanol.
  await initializeDateFormatting('es');
  runApp(const ProviderScope(child: AppFinanzas()));
}

class AppFinanzas extends StatelessWidget {
  const AppFinanzas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mis Finanzas',
      debugShowCheckedModeBanner: false,
      theme: construirTema(Brightness.light),
      darkTheme: construirTema(Brightness.dark),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Puerta(),
    );
  }
}

/// Decide que mostrar segun si hay sesion iniciada.
class _Puerta extends ConsumerWidget {
  const _Puerta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesion = ref.watch(sesionProvider);

    return sesion.when(
      // Al reintentar despues de un error se vuelve a mostrar la espera. Sin esto
      // el error quedaria quieto en pantalla mientras se reintenta.
      skipLoadingOnRefresh: !sesion.hasError,
      // Mientras se comprueba el token guardado. Si el servidor estaba dormido
      // esto puede tardar un par de minutos, por eso el aviso.
      loading: () => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [CircularProgressIndicator(), AvisoServidorDormido()],
            ),
          ),
        ),
      ),
      error: (e, _) => _SesionSinComprobar(e),
      data: (usuario) => usuario == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}

/// Hay una sesion guardada pero no se pudo comprobar con el servidor.
///
/// El token se conserva, asi que si el problema era la conexion o que el
/// servidor seguia arrancando, alcanza con reintentar. Por si el error no se
/// arregla solo, tambien se puede descartar la sesion y entrar de nuevo.
class _SesionSinComprobar extends ConsumerWidget {
  const _SesionSinComprobar(this.error);

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EstadoError(
              mensaje: mensajeDeError(error),
              alReintentar: () => ref.invalidate(sesionProvider),
            ),
            TextButton(
              onPressed: () => ref.read(sesionProvider.notifier).cerrarSesion(),
              child: const Text('Iniciar sesión de nuevo'),
            ),
          ],
        ),
      ),
    );
  }
}
