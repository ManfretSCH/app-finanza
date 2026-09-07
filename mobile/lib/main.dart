import 'package:app_finanzas/core/tema.dart';
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
      // Mientras se comprueba el token guardado.
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => const LoginScreen(),
      data: (usuario) => usuario == null ? const LoginScreen() : const HomeScreen(),
    );
  }
}
