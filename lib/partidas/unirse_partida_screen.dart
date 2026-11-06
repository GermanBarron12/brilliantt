import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lobby_screen.dart';
import 'partida_api.dart';
import 'partida_error_banner.dart';
import 'partida_exception.dart';

/// Pone en mayúsculas cada letra a medida que se escribe, para que el
/// código de invitación (siempre en mayúsculas) se vea igual que como lo
/// manda quien invita, sin que el usuario tenga que acordarse de usar
/// mayúsculas.
class _FormateadorMayusculas extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

/// Pide el código de invitación y, si existe, une al usuario a esa
/// partida y pasa al lobby.
class UnirsePartidaScreen extends StatefulWidget {
  const UnirsePartidaScreen({super.key, required this.api, required this.token, required this.usuarioId});

  final PartidaApi api;
  final String token;
  final String usuarioId;

  @override
  State<UnirsePartidaScreen> createState() => _UnirsePartidaScreenState();
}

class _UnirsePartidaScreenState extends State<UnirsePartidaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoController = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _codigoController.addListener(_limpiarError);
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  void _limpiarError() {
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _unirse() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      final partida = await widget.api.unirse(_codigoController.text.trim(), token: widget.token);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LobbyScreen(
            api: widget.api,
            token: widget.token,
            usuarioId: widget.usuarioId,
            partidaInicial: partida,
          ),
        ),
      );
    } on PartidaException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unirse a una partida')),
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
                  if (_error != null) ...[BannerErrorPartida(mensaje: _error!), const SizedBox(height: 16)],
                  TextFormField(
                    controller: _codigoController,
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.done,
                    maxLength: 6,
                    inputFormatters: [_FormateadorMayusculas()],
                    decoration: const InputDecoration(
                      labelText: 'Código de invitación',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      counterText: '',
                    ),
                    onFieldSubmitted: (_) => _enviando ? null : _unirse(),
                    validator: (valor) =>
                        (valor == null || valor.trim().isEmpty) ? 'Ingresá el código que te compartieron' : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _enviando ? null : _unirse,
                    child: _enviando
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Unirse'),
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
