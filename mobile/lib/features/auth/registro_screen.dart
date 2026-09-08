import 'package:app_finanzas/core/api_client.dart';
import 'package:app_finanzas/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Caso de uso "Registrarse" del diagrama de Autenticacion.
class RegistroScreen extends ConsumerStatefulWidget {
  const RegistroScreen({super.key});

  @override
  ConsumerState<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends ConsumerState<RegistroScreen> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmacion = TextEditingController();
  bool _cargando = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _password.dispose();
    _confirmacion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      await ref.read(sesionProvider.notifier).registrar(
            _nombre.text.trim(),
            _email.text.trim(),
            _password.text,
          );
      // Al registrarse queda con la sesion iniciada; se cierra esta pantalla
      // y el arbol principal muestra el inicio.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = mensajeDeError(e));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formulario,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Ingresa tu nombre' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Ingresa un correo válido' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    helperText: 'Mínimo 8 caracteres',
                  ),
                  obscureText: true,
                  // Al reescribirla se revalida la confirmación, para que el
                  // aviso desaparezca solo cuando las dos coinciden.
                  onChanged: (_) {
                    if (_confirmacion.text.isNotEmpty) {
                      _formulario.currentState?.validate();
                    }
                  },
                  validator: (v) =>
                      (v == null || v.length < 8) ? 'Debe tener al menos 8 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmacion,
                  decoration: const InputDecoration(labelText: 'Repetir contraseña'),
                  obscureText: true,
                  // Como no se ve lo que se escribe, un error de tipeo dejaría
                  // al usuario sin poder entrar despues. Por eso se pide dos veces.
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Repite la contraseña';
                    if (v != _password.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _cargando ? null : _enviar,
                  child: _cargando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Crear cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
