import 'package:flutter/material.dart';

/// Mapa de nombre de icono a IconData.
///
/// Hace falta que sea explicito: Flutter elimina en la compilacion los iconos
/// que no aparecen literalmente en el codigo, asi que construir un IconData a
/// partir de un texto en tiempo de ejecucion muestra cuadrados vacios.
/// Los nombres son los que guarda el backend en categories.icono y
/// account_types.icono.
const _iconos = <String, IconData>{
  // Categorias de gasto
  'restaurant': Icons.restaurant,
  'directions_bus': Icons.directions_bus,
  'home': Icons.home,
  'bolt': Icons.bolt,
  'local_hospital': Icons.local_hospital,
  'school': Icons.school,
  'movie': Icons.movie,
  'checkroom': Icons.checkroom,
  'category': Icons.category,
  // Categorias de ingreso
  'payments': Icons.payments,
  'work': Icons.work,
  'trending_up': Icons.trending_up,
  'savings': Icons.savings,
  // Tipos de cuenta
  'account_balance': Icons.account_balance,
  'credit_card': Icons.credit_card,
  'account_balance_wallet': Icons.account_balance_wallet,
  'smartphone': Icons.smartphone,
};

/// Devuelve el icono con ese nombre, o uno generico si no esta en el mapa
/// (por ejemplo si el backend agrega uno nuevo antes que la app).
IconData iconoPorNombre(String? nombre, {IconData porDefecto = Icons.category}) =>
    _iconos[nombre] ?? porDefecto;
