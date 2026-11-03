import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';
import 'auth_exception.dart';
import 'auth_repository.dart';
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

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final usuario = await widget.repository.login(_nombreUsuarioController.text, _passwordController.text);
      if (!mounted) return;
      context.read<AuthCubit>().sesionIniciada(usuario);
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.diamond, color: Colors.deepPurple, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Brilliant',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nombreUsuarioController,
                  decoration: const InputDecoration(labelText: 'Nombre de usuario'),
                  validator: (valor) =>
                      (valor == null || valor.trim().isEmpty) ? 'Ingresa tu nombre de usuario' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
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
    );
  }
}
