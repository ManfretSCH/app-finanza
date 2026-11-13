import 'dart:async';

import 'package:flutter/material.dart';

/// Mensaje para cuando una lista no tiene nada que mostrar.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    required this.icono,
    required this.titulo,
    required this.detalle,
    super.key,
  });

  final IconData icono;
  final String titulo;
  final String detalle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje de error con boton para reintentar.
class EstadoError extends StatelessWidget {
  const EstadoError({required this.mensaje, required this.alReintentar, super.key});

  final String mensaje;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(mensaje, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: alReintentar, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// Dialogo de confirmacion para las acciones que no se pueden deshacer.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String textoConfirmar = 'Eliminar',
}) async {
  final respuesta = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(textoConfirmar),
        ),
      ],
    ),
  );
  return respuesta ?? false;
}

/// Mensaje breve al pie de la pantalla.
///
/// Se usa sobre todo para los rechazos del backend, como intentar borrar una
/// categoria que tiene movimientos.
void mostrarAviso(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(mensaje)));
}

/// Aviso para cuando un pedido al servidor tarda mas de lo normal.
///
/// El backend corre en la capa gratuita de Render, que lo apaga tras un rato sin
/// uso, y el primer pedido despues de eso espera a que vuelva a arrancar. Sin este
/// aviso el usuario solo ve una ruedita girando y piensa que la app se colgo.
///
/// Se pone en pantalla mientras dura el pedido y aparece recien pasado [demora],
/// para no molestar cuando el servidor esta despierto y responde enseguida.
class AvisoServidorDormido extends StatefulWidget {
  const AvisoServidorDormido({super.key});

  /// Un servidor despierto responde en menos de un segundo; pasado este tiempo
  /// lo mas probable es que este arrancando.
  static const demora = Duration(seconds: 5);

  @override
  State<AvisoServidorDormido> createState() => _AvisoServidorDormidoState();
}

class _AvisoServidorDormidoState extends State<AvisoServidorDormido> {
  late final Timer _temporizador;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer(AvisoServidorDormido.demora, () => setState(() => _visible = true));
  }

  @override
  void dispose() {
    _temporizador.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        'El servidor se está despertando, puede tardar hasta 2 minutos.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}
