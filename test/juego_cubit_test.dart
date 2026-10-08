import 'dart:math';

import 'package:test/test.dart';

import 'package:brilliant/juego_cubit.dart';
import 'package:brilliant/puntuacion.dart';
import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/zonas_tablero.dart';

/// Devuelve, en orden, los valores de dados que se le pidan.
class _DadosFijos implements Random {
  final List<int> dados;
  int _siguiente = 0;

  _DadosFijos(this.dados);

  @override
  int nextInt(int max) => dados[_siguiente++] - 1;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;
}

/// Tablero vacío con dos números sueltos, pensado para controlar a mano
/// cuáles casillas quedan libres:
/// - (0,0) = 3, con sus dos vecinas ocupadas (no tiene destino posible).
/// - (6,6) = 5, con sus vecinas vacías (sí tiene destino posible).
List<List<int?>> _tableroPersonalizado() {
  final tablero = List.generate(7, (_) => List<int?>.filled(7, null));
  tablero[0][0] = 3;
  tablero[1][0] = 9; // ocupa una vecina de (0,0)
  tablero[0][1] = 9; // ocupa la otra vecina de (0,0)
  tablero[6][6] = 5;
  return tablero;
}

void main() {
  // Estrellas del nivel 1 con los números 1 a 6 en orden.
  // Estrella 0 está en (0,2) azul; el resto no nos importa para estas pruebas.
  final tableroInicial = tableroDesdeNumerosIniciales([1, 2, 3, 4, 5, 6]);

  group('tableroDesdeNumerosIniciales', () {
    test('pone cada número inicial en su estrella', () {
      expect(tableroInicial[0][2], 1);
      expect(tableroInicial[1][5], 2);
      expect(tableroInicial[6][4], 6);
      expect(tableroInicial[0][0], isNull);
    });
  });

  group('JuegoCubit', () {
    test('tirar dados guarda los dos valores', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([4, 2]));
      cubit.tirarDados();

      expect(cubit.state.dados, [4, 2]);
      cubit.close();
    });

    test('el ancla debe tener uno de los dos números; se escribe el otro', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
      cubit.tirarDados();
      cubit.tocarCasilla(const PosicionCasilla(0, 2)); // tiene el 1

      expect(cubit.state.ancla, const PosicionCasilla(0, 2));
      expect(cubit.state.numeroAColocar, 6);
      cubit.close();
    });

    test('si el ancla no tiene ninguno de los dados no hay casillas válidas', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
      cubit.tirarDados();
      cubit.tocarCasilla(const PosicionCasilla(0, 2)); // tiene el 1

      expect(cubit.state.numeroAColocar, isNull);
      expect(cubit.state.casillasValidas, isEmpty);
      cubit.close();
    });

    test('las casillas válidas son vecinas vacías que cumplen la regla de su zona', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
      cubit.tirarDados();
      cubit.tocarCasilla(const PosicionCasilla(0, 2));

      final validas = cubit.state.casillasValidas;
      // (0,1) es verde (acepta cualquier número) y (0,3) es morado (acepta
      // dos distintos). (1,2) es azul y tiene un 1, así que no acepta el 6.
      expect(validas, contains(const PosicionCasilla(0, 1)));
      expect(validas, contains(const PosicionCasilla(0, 3)));
      expect(validas, isNot(contains(const PosicionCasilla(1, 2))));
      cubit.close();
    });

    test('tocar una casilla válida escribe el número y gasta los dados', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
      cubit.tirarDados();
      cubit.tocarCasilla(const PosicionCasilla(0, 2));
      cubit.tocarCasilla(const PosicionCasilla(0, 1));

      expect(cubit.state.valorEn(const PosicionCasilla(0, 1)), 6);
      expect(cubit.state.dados, isNull);
      expect(cubit.state.ancla, isNull);
      cubit.close();
    });

    test('dados [3,5]: con ancla en el 3 el número a colocar es el 5', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
      cubit.tirarDados();
      cubit.tocarCasilla(const PosicionCasilla(3, 1)); // estrella con el 3

      expect(cubit.state.numeroAColocar, 5);
      cubit.close();
    });

    test('dados [3,5]: con ancla en el 5 el número a colocar es el 3', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
      cubit.tirarDados();
      cubit.tocarCasilla(const PosicionCasilla(5, 2)); // estrella con el 5

      expect(cubit.state.numeroAColocar, 3);
      cubit.close();
    });

    test('una casilla ya ocupada deja de aparecer como válida', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6, 1, 6]));
      cubit.tirarDados();
      cubit.tocarCasilla(const PosicionCasilla(0, 2)); // ancla con el 1
      cubit.tocarCasilla(const PosicionCasilla(0, 1)); // coloca el 6 acá

      cubit.tirarDados();
      cubit.tocarCasilla(const PosicionCasilla(0, 2)); // mismo ancla otra vez

      expect(cubit.state.casillasValidas, isNot(contains(const PosicionCasilla(0, 1))));
      expect(cubit.state.casillasValidas, contains(const PosicionCasilla(0, 3)));
      cubit.close();
    });
  });

  group('JuegoEstado.puntaje', () {
    test('una zona incompleta no otorga puntos', () {
      expect(JuegoEstado(tablero: tableroInicial).puntaje, 0);
    });

    test('una zona completa otorga el valor de su color', () {
      final tablero = List.generate(7, (_) => List<int?>.filled(7, null));
      final zonaVerde = zonasNivel1.firstWhere((z) => z.color == ColorZona.verde);
      for (final casilla in zonaVerde.casillas) {
        tablero[casilla.fila][casilla.columna] = 1;
      }

      final estado = JuegoEstado(tablero: tablero);
      expect(estado.puntaje, puntosPorZonaCompleta[ColorZona.verde]);
    });

    test('el puntaje total suma todas las zonas completas', () {
      final tablero = List.generate(7, (_) => List<int?>.filled(7, null));
      final zonaVerde = zonasNivel1.firstWhere((z) => z.color == ColorZona.verde);
      final zonaAzul = zonasNivel1.firstWhere((z) => z.color == ColorZona.azul);
      for (final casilla in zonaVerde.casillas) {
        tablero[casilla.fila][casilla.columna] = 1;
      }
      for (final casilla in zonaAzul.casillas) {
        tablero[casilla.fila][casilla.columna] = 2;
      }

      final esperado =
          puntosPorZonaCompleta[ColorZona.verde]! + puntosPorZonaCompleta[ColorZona.azul]!;
      expect(JuegoEstado(tablero: tablero).puntaje, esperado);
    });

    test('recalcular el puntaje no duplica puntos', () {
      final tablero = List.generate(7, (_) => List<int?>.filled(7, null));
      final zonaVerde = zonasNivel1.firstWhere((z) => z.color == ColorZona.verde);
      for (final casilla in zonaVerde.casillas) {
        tablero[casilla.fila][casilla.columna] = 1;
      }

      final estado = JuegoEstado(tablero: tablero);
      expect(estado.puntaje, estado.puntaje);
    });
  });

  group('JuegoEstado.puedeVolverATirar', () {
    test('numero presente pero sin ningun destino vacio: se puede volver a tirar', () {
      // (0,0) tiene el 3 pero sus dos vecinas están ocupadas.
      final estado = JuegoEstado(tablero: _tableroPersonalizado(), dados: const [3, 1]);
      expect(estado.puedeVolverATirar, isTrue);
    });

    test('dados [3,5] con jugada directa posible: los dados quedan bloqueados', () {
      // En el tablero inicial, la estrella (3,1) tiene el 3 y su vecina
      // (2,1) está vacía y acepta el 5 (zona roja: valores distintos).
      final estado = JuegoEstado(tablero: tableroInicial, dados: const [3, 5]);
      expect(estado.puedeVolverATirar, isFalse);
    });

    test('solo la jugada inversa es posible: los dados tambien quedan bloqueados', () {
      // (0,0)=3 está bloqueada por sus vecinas, pero (6,6)=5 sí tiene una
      // vecina vacía que acepta el 3. Alcanza con que una dirección sirva.
      final estado = JuegoEstado(tablero: _tableroPersonalizado(), dados: const [3, 5]);
      expect(estado.puedeVolverATirar, isFalse);
    });

    test('numero existe en el tablero pero sin destino valido: no se confunde con jugada posible', () {
      final tablero = [for (final fila in tableroInicial) [...fila]];
      // Encierra la estrella (0,2)=1 ocupando sus tres vecinas...
      tablero[1][2] = 9;
      tablero[0][1] = 9;
      tablero[0][3] = 9;
      // ...y también la estrella (6,4)=6, para que ningún 1 ni 6 del
      // tablero tenga una vecina vacía.
      tablero[5][4] = 9;
      tablero[6][3] = 9;
      tablero[6][5] = 9;

      final estado = JuegoEstado(tablero: tablero, dados: const [1, 6]);
      expect(estado.puedeVolverATirar, isTrue);
    });

    test('tirada sin jugada permite re-tirar; la siguiente con jugada bloquea', () {
      final cubit = JuegoCubit(_tableroPersonalizado(), random: _DadosFijos([1, 2, 3, 5]));

      cubit.tirarDados(); // dados [1,2]: ningún número está en el tablero
      expect(cubit.state.puedeVolverATirar, isTrue);

      cubit.tirarDados(); // dados [3,5]: hay jugada (la inversa)
      expect(cubit.state.puedeVolverATirar, isFalse);
      cubit.close();
    });

    test('tirarDados no hace nada si ya hay una jugada posible', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5, 1, 2]));
      cubit.tirarDados(); // dados [3,5], hay jugada: queda bloqueado

      cubit.tirarDados(); // no debería cambiar nada

      expect(cubit.state.dados, [3, 5]);
      cubit.close();
    });
  });

  group('JuegoEstado zona amarilla (fusionada)', () {
    // Las 5 casillas amarillas del nivel 1, físicamente aisladas entre sí,
    // pero una sola zona lógica desde que se corrigió zonasNivel1.
    const casillasAmarillas = [
      PosicionCasilla(0, 0),
      PosicionCasilla(0, 6),
      PosicionCasilla(3, 3),
      PosicionCasilla(6, 0),
      PosicionCasilla(6, 6),
    ];

    List<List<int?>> tableroVacio() => List.generate(7, (_) => List<int?>.filled(7, null));

    test('no otorga puntos hasta que las 5 casillas amarillas estén llenas', () {
      final tablero = tableroVacio();
      const valores = [1, 2, 3, 4, 5];

      for (var i = 0; i < casillasAmarillas.length; i++) {
        final p = casillasAmarillas[i];
        tablero[p.fila][p.columna] = valores[i];

        final esLaUltima = i == casillasAmarillas.length - 1;
        final puntaje = JuegoEstado(tablero: tablero).puntaje;
        expect(puntaje, esLaUltima ? puntosPorZonaCompleta[ColorZona.amarillo] : 0);
      }
    });

    test('al completarse otorga exactamente 6 puntos, una sola vez', () {
      final tablero = tableroVacio();
      const valores = [1, 2, 3, 4, 5];
      for (var i = 0; i < casillasAmarillas.length; i++) {
        final p = casillasAmarillas[i];
        tablero[p.fila][p.columna] = valores[i];
      }

      final estado = JuegoEstado(tablero: tablero);
      expect(estado.puntaje, 6);
      expect(estado.puntaje, estado.puntaje); // leer de nuevo no duplica
    });

    test('completar amarillo y otra zona distinta suma ambos puntajes', () {
      final tablero = tableroVacio();
      const valores = [1, 2, 3, 4, 5];
      for (var i = 0; i < casillasAmarillas.length; i++) {
        final p = casillasAmarillas[i];
        tablero[p.fila][p.columna] = valores[i];
      }
      final zonaVerde = zonasNivel1.firstWhere((z) => z.color == ColorZona.verde);
      for (final c in zonaVerde.casillas) {
        tablero[c.fila][c.columna] = 1;
      }

      final esperado =
          puntosPorZonaCompleta[ColorZona.amarillo]! + puntosPorZonaCompleta[ColorZona.verde]!;
      expect(JuegoEstado(tablero: tablero).puntaje, esperado);
    });

    test('rechaza repetir un numero entre dos casillas amarillas lejanas', () {
      final tablero = tableroVacio();
      tablero[6][6] = 5; // casilla amarilla lejana, ya con el 5
      tablero[0][1] = 2; // ancla verde, vecina de la amarilla (0,0)

      final estado = JuegoEstado(
        tablero: tablero,
        dados: const [2, 5],
        ancla: const PosicionCasilla(0, 1),
      );

      expect(estado.numeroAColocar, 5);
      expect(estado.casillasValidas, isNot(contains(const PosicionCasilla(0, 0))));
    });

    test('acepta un numero que todavia no existe en la zona amarilla', () {
      final tablero = tableroVacio();
      tablero[6][6] = 3; // casilla amarilla lejana, con un valor distinto
      tablero[0][1] = 2; // ancla verde, vecina de la amarilla (0,0)

      final estado = JuegoEstado(
        tablero: tablero,
        dados: const [2, 5],
        ancla: const PosicionCasilla(0, 1),
      );

      expect(estado.numeroAColocar, 5);
      expect(estado.casillasValidas, contains(const PosicionCasilla(0, 0)));
    });
  });
}
