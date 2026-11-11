import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';
import 'autenticacion_excepcion.dart';
import 'autenticacion_repositorio.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreUsuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarController = TextEditingController();
  bool _enviando = false;
  bool _passwordVisible = false;
  bool _confirmarVisible = false;
  String? _errorServidor;

  @override
  void initState() {
    super.initState();
    _nombreUsuarioController.addListener(_limpiarErrorServidor);
    _passwordController.addListener(_limpiarErrorServidor);
    _confirmarController.addListener(_limpiarErrorServidor);
  }

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  void _limpiarErrorServidor() {
    if (_errorServidor != null) setState(() => _errorServidor = null);
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _errorServidor = null;
    });
    try {
      final usuario = await widget.repository.registrar(
        _nombreUsuarioController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      context.read<AuthCubit>().sesionIniciada(usuario);
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorServidor = error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUnfocus,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorServidor != null) ...[
                    _BannerErrorFormulario(mensaje: _errorServidor!),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nombreUsuarioController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (valor) {
                      final texto = valor?.trim() ?? '';
                      if (texto.isEmpty) return 'Ingresa un nombre de usuario';
                      if (texto.length < 3) return 'Mínimo 3 caracteres';
                      if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(texto)) {
                        return 'Solo letras, números, "_" y "."';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Contraseña (mínimo 8 caracteres)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                        tooltip: _passwordVisible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                    validator: (valor) =>
                        (valor == null || valor.length < 8) ? 'Mínimo 8 caracteres' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmarController,
                    obscureText: !_confirmarVisible,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _enviando ? null : _registrar(),
                    decoration: InputDecoration(
                      labelText: 'Confirma la contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_confirmarVisible ? Icons.visibility_off : Icons.visibility),
                        tooltip: _confirmarVisible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                        onPressed: () => setState(() => _confirmarVisible = !_confirmarVisible),
                      ),
                    ),
                    validator: (valor) =>
                        valor != _passwordController.text ? 'Las contraseñas no coinciden' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _enviando ? null : _registrar,
                    child: _enviando
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
      ),
    );
  }
}

/// Aviso de error del servidor (por ejemplo, nombre de usuario ya en uso)
/// asociado al formulario, en vez de un SnackBar transitorio.
class _BannerErrorFormulario extends StatelessWidget {
  const _BannerErrorFormulario({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(mensaje, style: TextStyle(color: colorScheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
