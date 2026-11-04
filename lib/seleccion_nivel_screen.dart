import 'package:flutter/material.dart';

import 'configuracion_nivel.dart';
import 'niveles_oficiales.dart';
import 'numeros_iniciales_screen.dart';
import 'tablero_widget.dart';

/// Pantalla para elegir uno de los 4 niveles oficiales de Brilliant. Cada
/// miniatura se dibuja con el mismo [TableroWidget] que usa la partida
/// real, a partir de su [ConfiguracionNivel]: ninguna matriz ni lista de
/// estrellas está transcrita a mano acá, solo se lee de
/// [configuracionesOficiales].
///
/// Es la pantalla a la que se llega directo al iniciar sesion (no hay
/// pantalla intermedia de "Jugar"). [onCerrarSesion] y [onEliminarCuenta]
/// son opcionales: si se proveen, se agregan los botones correspondientes
/// en la barra superior. Al dejarlos afuera (como hacen las pruebas de esta
/// pantalla y las que arman un nivel directamente) la pantalla no depende
/// de nada de `lib/auth/`.
class SeleccionNivelScreen extends StatelessWidget {
  const SeleccionNivelScreen({super.key, this.onCerrarSesion, this.onEliminarCuenta});

  final VoidCallback? onCerrarSesion;

  /// Pide la password actual y elimina la cuenta. Devuelve un mensaje de
  /// error para mostrar si falla, o `null` si la cuenta se elimino bien.
  final Future<String?> Function(String password)? onEliminarCuenta;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brilliant · Elegir nivel'),
        actions: [
          if (onEliminarCuenta != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar cuenta',
              onPressed: () => _mostrarDialogoEliminarCuenta(context, onEliminarCuenta!),
            ),
          if (onCerrarSesion != null)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Cerrar sesión',
              onPressed: onCerrarSesion,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnas = _columnasPara(constraints.maxWidth);
            return GridView.count(
              crossAxisCount: columnas,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: columnas == 1 ? 2.2 : 0.95,
              children: [
                for (final nivel in configuracionesOficiales) _TarjetaNivel(nivel: nivel),
              ],
            );
          },
        ),
      ),
    );
  }

  // Mas columnas a medida que hay mas ancho disponible: antes el grid
  // topeaba en 2 columnas sin importar cuanto ancho sobrara, dejando mucho
  // espacio vacio en pantallas de escritorio.
  int _columnasPara(double ancho) {
    if (ancho < 420) return 1;
    if (ancho < 800) return 2;
    if (ancho < 1100) return 3;
    return 4;
  }
}

class _TarjetaNivel extends StatelessWidget {
  final ConfiguracionNivel nivel;

  const _TarjetaNivel({required this.nivel});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NumerosInicialesScreen(configuracionNivel: nivel),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(
                'Nivel ${nivel.id}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: IgnorePointer(
                    // Miniatura de solo lectura: sin números, sin resaltados,
                    // y sin que sus casillas capturen el toque (lo maneja el
                    // InkWell de toda la tarjeta).
                    child: TableroWidget(
                      layout: nivel.layout,
                      valores: List.generate(
                        nivel.filas,
                        (_) => List<int?>.filled(nivel.columnas, null),
                      ),
                      estrellas: nivel.casillasEstrella.toSet(),
                      resaltadas: const {},
                      repetidas: const {},
                      seleccionada: null,
                      onTap: (_) {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _mostrarDialogoEliminarCuenta(
  BuildContext context,
  Future<String?> Function(String password) onEliminarCuenta,
) {
  showDialog<void>(
    context: context,
    builder: (_) => _DialogoEliminarCuenta(onEliminarCuenta: onEliminarCuenta),
  );
}

/// Pide la password actual antes de confirmar el borrado: sirve tanto de
/// reautenticacion (lo exige el backend) como de confirmacion explicita de
/// una accion irreversible.
class _DialogoEliminarCuenta extends StatefulWidget {
  const _DialogoEliminarCuenta({required this.onEliminarCuenta});

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
    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Esta accion es permanente y no se puede deshacer. Confirma tu contraseña para continuar.'),
          const SizedBox(height: 16),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: 'Contraseña', errorText: _error),
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
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: _enviando ? null : _confirmar,
          child: _enviando
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Eliminar'),
        ),
      ],
    );
  }
}
