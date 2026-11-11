import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../inicio_screen.dart';
import '../partidas/partida_api.dart';
import '../partidas/partida_menu_screen.dart';
import 'api_configuracion.dart';
import 'autenticacion_api.dart';
import 'auth_cubit.dart';
import 'autenticacion_excepcion.dart';
import 'autenticacion_repositorio.dart';
import 'autenticacion_estado.dart';
import 'login_screen.dart';
import 'usuario.dart';

/// Raíz de la app: decide si mostrar la pantalla de login o el juego según
/// haya o no una sesión válida guardada. Crea y provee el `AuthRepository`
/// y el `AuthCubit` para que las pantallas de abajo los usen.
///
/// Usa su propio `Navigator` anidado, por debajo del `BlocProvider`: los
/// provider de `package:provider` quedan "scoped" a la ruta donde se
/// definen, asi que una pantalla empujada con `Navigator.push` (como
/// `RegisterScreen` desde `LoginScreen`) no ve un `BlocProvider` colocado
/// mas arriba, en el `home` del `MaterialApp` externo (seria una ruta
/// hermana, no descendiente). Con este `Navigator` propio, cualquier
/// pantalla empujada aqui adentro sigue siendo descendiente del
/// `BlocProvider` y puede leer el `AuthCubit` sin problema.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.repository});

  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(repository)..verificarSesionInicial(),
      child: Navigator(
        onGenerateRoute: (_) => MaterialPageRoute(
          builder: (_) => _AuthGateBody(repository: repository),
        ),
      ),
    );
  }
}

class _AuthGateBody extends StatelessWidget {
  const _AuthGateBody({required this.repository});

  final AuthRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        switch (state) {
          case AuthCargando():
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthNoAutenticado():
            return LoginScreen(repository: repository);
          case AuthAutenticado(usuario: final usuario):
            return InicioScreen(
              nombreUsuario: usuario.nombreUsuario,
              onCerrarSesion: () => context.read<AuthCubit>().cerrarSesion(),
              onEliminarCuenta: (password) async {
                try {
                  await context.read<AuthCubit>().eliminarCuenta(password);
                  return null;
                } on AuthException catch (error) {
                  return error.message;
                }
              },
              onJugarMultijugador: () => _abrirMultijugador(context, repository, usuario),
            );
        }
      },
    );
  }
}

/// Lee el token de la sesion activa y abre el menu de multijugador. Si por
/// algun motivo no hay token guardado (no deberia pasar estando
/// autenticado), no hace nada: no tiene sentido entrar a partidas sin
/// poder autenticarse contra ese backend.
Future<void> _abrirMultijugador(BuildContext context, AuthRepository repository, Usuario usuario) async {
  final token = await repository.leerToken();
  if (token == null || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PartidaMenuScreen(
        api: PartidaApi(baseUrl: apiBaseUrl),
        token: token,
        usuarioId: usuario.id,
      ),
    ),
  );
}

/// Construye el `AuthGate` con las dependencias reales (API + storage
/// seguro). Separado de `AuthGate` para que las pruebas puedan inyectar un
/// `AuthRepository` propio sin tocar la red.
class AuthGateReal extends StatelessWidget {
  const AuthGateReal({super.key, required this.baseUrl});

  final String baseUrl;

  @override
  Widget build(BuildContext context) {
    return AuthGate(repository: AuthRepository(api: AuthApi(baseUrl: baseUrl)));
  }
}
