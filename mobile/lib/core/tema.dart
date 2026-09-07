import 'package:flutter/material.dart';

/// Colores de la app. El verde transmite la idea de finanzas sanas.
const semillaColor = Color(0xFF2E7D5B);

const colorIngreso = Color(0xFF2E7D32);
const colorGasto = Color(0xFFC62828);

ThemeData construirTema(Brightness brillo) {
  final esquema = ColorScheme.fromSeed(seedColor: semillaColor, brightness: brillo);
  return ThemeData(
    colorScheme: esquema,
    useMaterial3: true,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      filled: true,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    ),
  );
}
