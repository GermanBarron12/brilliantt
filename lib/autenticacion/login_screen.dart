import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';
import 'autenticacion_excepcion.dart';
import 'autenticacion_repositorio.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreUsuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _enviando = false;
  bool _passwordVisible = false;
  String? _errorServidor;

  @override
  void initState() {
    super.initState();
    _nombreUsuarioController.addListener(_limpiarErrorServidor);
    _passwordController.addListener(_limpiarErrorServidor);
  }

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // El error del servidor (credenciales invalidas, etc.) queda asociado al
  // formulario hasta el proximo intento: se limpia en cuanto el usuario
  // vuelve a tocar un campo, no recien al reenviar.
  void _limpiarErrorServidor() {
    if (_errorServidor != null) setState(() => _errorServidor = null);
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _errorServidor = null;
    });
    try {
      final usuario = await widget.repository.login(_nombreUsuarioController.text, _passwordController.text);
      if (!mounted) return;
      context.read<AuthCubit>().sesionIniciada(usuario);
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorServidor = error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
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
                  Icon(Icons.diamond, color: colorScheme.primary, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Brilliant',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 32),
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
                    validator: (valor) =>
                        (valor == null || valor.trim().isEmpty) ? 'Ingresa tu nombre de usuario' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _enviando ? null : _iniciarSesion(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility),
                        tooltip: _passwordVisible ? 'Ocultar contraseña' : 'Mostrar contraseña',
                        onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                      ),
                    ),
                    validator: (valor) =>
                        (valor == null || valor.isEmpty) ? 'Ingresa tu contraseña' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _enviando ? null : _iniciarSesion,
                    child: _enviando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _enviando
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterScreen(repository: widget.repository),
                              ),
                            ),
                    child: const Text('¿No tienes cuenta? Créala'),
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

/// Aviso de error del servidor asociado al formulario (por ejemplo,
/// credenciales invalidas): queda visible junto a los campos, en vez de
/// desaparecer solo como un SnackBar, para que el usuario pueda leerlo con
/// calma mientras corrige los datos.
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
