import 'package:flutter/material.dart';

import 'seleccion_nivel_screen.dart';

/// Pantalla de inicio, a la que se llega al iniciar sesión: se elige entre
/// jugar en solitario (lleva a elegir nivel) o con amigos (lleva a crear
/// una partida o unirse a una). El menú de arriba a la derecha muestra la
/// cuenta activa y permite cerrar la sesión o eliminar la cuenta.
///
/// No depende de nada de `lib/auth/` ni de `lib/partidas/`: todo lo que
/// necesita de la sesión le llega por parámetro.
class InicioScreen extends StatelessWidget {
  const InicioScreen({
    super.key,
    required this.nombreUsuario,
    required this.onJugarMultijugador,
    required this.onCerrarSesion,
    required this.onEliminarCuenta,
  });

  final String nombreUsuario;

  /// Abre el flujo de jugar con amigos (crear partida o unirse con código).
  final VoidCallback onJugarMultijugador;

  final VoidCallback onCerrarSesion;

  /// Elimina la cuenta con la contraseña dada. Devuelve un mensaje de error
  /// para mostrar si falla, o `null` si la cuenta se eliminó bien.
  final Future<String?> Function(String password) onEliminarCuenta;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brilliant'),
        actions: [
          PopupMenuButton<_OpcionDeCuenta>(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Opciones de la cuenta',
            onSelected: (opcion) {
              switch (opcion) {
                case _OpcionDeCuenta.cerrarSesion:
                  onCerrarSesion();
                case _OpcionDeCuenta.eliminarCuenta:
                  showDialog<void>(
                    context: context,
                    builder: (_) => _DialogoEliminarCuenta(
                      nombreUsuario: nombreUsuario,
                      onEliminarCuenta: onEliminarCuenta,
                    ),
                  );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.account_circle, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        nombreUsuario,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _OpcionDeCuenta.cerrarSesion,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout),
                  title: Text('Cerrar sesión'),
                ),
              ),
              PopupMenuItem(
                value: _OpcionDeCuenta.eliminarCuenta,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: colorScheme.error),
                  title: Text('Eliminar cuenta', style: TextStyle(color: colorScheme.error)),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.diamond, color: colorScheme.primary, size: 64),
                const SizedBox(height: 16),
                Text('¿Cómo quieres jugar?', textAlign: TextAlign.center, style: textTheme.headlineSmall),
                const SizedBox(height: 32),
                _BotonDeModo(
                  icono: Icons.person,
                  titulo: 'Solitario',
                  descripcion: 'Elige un nivel y juega a tu ritmo.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SeleccionNivelScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _BotonDeModo(
                  icono: Icons.people,
                  titulo: 'Multijugador',
                  descripcion: 'Crea una partida o únete a la de tus amigos.',
                  onTap: onJugarMultijugador,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _OpcionDeCuenta { cerrarSesion, eliminarCuenta }

class _BotonDeModo extends StatelessWidget {
  const _BotonDeModo({required this.icono, required this.titulo, required this.descripcion, required this.onTap});

  final IconData icono;
  final String titulo;
  final String descripcion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icono, size: 32, color: colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(descripcion, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pide la contraseña actual antes de confirmar el borrado: sirve tanto de
/// reautenticación (lo exige el backend) como de confirmación explícita de
/// una acción irreversible.
class _DialogoEliminarCuenta extends StatefulWidget {
  const _DialogoEliminarCuenta({required this.nombreUsuario, required this.onEliminarCuenta});

  final String nombreUsuario;
  final Future<String?> Function(String password) onEliminarCuenta;

  @override
  State<_DialogoEliminarCuenta> createState() => _DialogoEliminarCuentaState();
}

class _DialogoEliminarCuentaState extends State<_DialogoEliminarCuenta> {
  final _passwordController = TextEditingController();
  String? _error;
  bool _enviando = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Ingresa tu contraseña');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final error = await widget.onEliminarCuenta(password);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _enviando = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Se eliminará la cuenta "${widget.nombreUsuario}" de forma permanente; no se puede deshacer. '
            'Confirma tu contraseña para continuar.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Contraseña', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _enviando ? null : _confirmar(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: colorScheme.error, foregroundColor: colorScheme.onError),
          onPressed: _enviando ? null : _confirmar,
          child: _enviando
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onError),
                )
              : const Text('Eliminar'),
        ),
      ],
    );
  }
}
