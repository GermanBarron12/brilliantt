import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth_cubit.dart';
import 'auth_exception.dart';
import 'auth_repository.dart';

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

  @override
  void dispose() {
    _nombreUsuarioController.dispose();
    _passwordController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _enviando = true);
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nombreUsuarioController,
                  decoration: const InputDecoration(labelText: 'Nombre de usuario'),
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
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña (mínimo 8 caracteres)'),
                  validator: (valor) =>
                      (valor == null || valor.length < 8) ? 'Mínimo 8 caracteres' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmarController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirma la contraseña'),
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
    );
  }
}
