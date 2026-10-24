import 'dart:math';

import 'package:test/test.dart';

import 'package:brilliant/configuracion_nivel.dart';
import 'package:brilliant/juego_cubit.dart';
import 'package:brilliant/jugador.dart';
import 'package:brilliant/puntuacion.dart';
import 'package:brilliant/tablero_layout.dart';
import 'package:brilliant/tipo.dart';
import 'package:brilliant/zona_identidad.dart';
import 'package:brilliant/zonas_tablero.dart';

/// Configuración sintética de prueba, exclusiva de este archivo: un
/// tablero 2x2 de una sola zona azul ("todos iguales"), con una sola
/// estrella. No representa ningún mapa oficial, solo sirve para probar
/// que JuegoCubit/JuegoEstado usan la configuración recibida y no los
/// globales fijos de nivel 1.
final _nivelSintetico = ConfiguracionNivel(
  id: 99,
  nombre: 'Nivel de prueba (azul)',
  layout: const [
    [ColorZona.azul, ColorZona.azul],
    [ColorZona.azul, ColorZona.azul],
  ],
  casillasEstrella: const [PosicionCasilla(0, 0)],
);

/// ProveedorJugador de prueba, para confirmar que JuegoCubit no depende de
/// ningun id fijo: usa el que le inyecten.
class _JugadorDePrueba implements ProveedorJugador {
  final String id;
  const _JugadorDePrueba(this.id);

  @override
  String get jugadorActualId => id;
}

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
    group('JuegoCubit: tirada y validación del ancla', () {
      test('tirar dados guarda los dos valores', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([4, 2]));
        cubit.tirarDados();

        expect(cubit.state.dados, [4, 2]);
        cubit.close();
      });

      test('el ancla debe tener uno de los dos números; se escribe el otro', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2)); // tiene el 1

        expect(cubit.state.ancla, const PosicionCasilla(0, 2));
        expect(cubit.state.numeroAColocar, 6);
        cubit.close();
      });

      test('sin elegir un dado, tocar una casilla con número no la vuelve ancla', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        cubit.tirarDados();
        cubit.tocarCasilla(const PosicionCasilla(0, 2)); // tiene el 1, pero no se eligió dado

        expect(cubit.state.ancla, isNull);
        expect(cubit.state.numeroAColocar, isNull);
        expect(cubit.state.casillasValidas, isEmpty);
        cubit.close();
      });
    });

    group('JuegoCubit: destinos válidos y colocación', () {
      test('las casillas válidas son vecinas vacías que cumplen la regla de su zona', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
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
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2));
        cubit.tocarCasilla(const PosicionCasilla(0, 1));

        expect(cubit.state.valorEn(const PosicionCasilla(0, 1)), 6);
        expect(cubit.state.dados, isNull);
        expect(cubit.state.ancla, isNull);
        cubit.close();
      });

      test('una casilla ya ocupada deja de aparecer como válida', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6, 1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2)); // ancla con el 1
        cubit.tocarCasilla(const PosicionCasilla(0, 1)); // coloca el 6 acá

        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2)); // mismo ancla otra vez

        expect(cubit.state.casillasValidas, isNot(contains(const PosicionCasilla(0, 1))));
        expect(cubit.state.casillasValidas, contains(const PosicionCasilla(0, 3)));
        cubit.close();
      });
    });

    group('JuegoCubit: selección directa e inversa del dado ancla', () {
      test('dados [3,5]: eligiendo el dado 3, el número a colocar es el 5', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        cubit.tirarDados();
        cubit.seleccionarDado(3);
        cubit.tocarCasilla(const PosicionCasilla(3, 1)); // estrella con el 3

        expect(cubit.state.numeroAColocar, 5);
        cubit.close();
      });

      test('dados [3,5]: eligiendo el dado 5, el número a colocar es el 3', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        cubit.tirarDados();
        cubit.seleccionarDado(5);
        cubit.tocarCasilla(const PosicionCasilla(5, 2)); // estrella con el 5

        expect(cubit.state.numeroAColocar, 3);
        cubit.close();
      });
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
    group('sin jugada posible: se puede volver a tirar', () {
      test('numero presente pero sin ningun destino vacio: se puede volver a tirar', () {
        // (0,0) tiene el 3 pero sus dos vecinas están ocupadas.
        final estado = JuegoEstado(tablero: _tableroPersonalizado(), dados: const [3, 1]);
        expect(estado.puedeVolverATirar, isTrue);
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
    });

    group('con jugada posible: los dados quedan bloqueados', () {
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

  group('JuegoEstado.casillasConJugadaPosible', () {
    group('casos vacíos (sin dados o sin jugada)', () {
      test('sin dados todavia, el conjunto esta vacio', () {
        expect(JuegoEstado(tablero: tableroInicial).casillasConJugadaPosible, isEmpty);
      });

      test('una tirada sin jugadas produce un conjunto vacio', () {
        final estado = JuegoEstado(tablero: _tableroPersonalizado(), dados: const [1, 2]);
        expect(estado.casillasConJugadaPosible, isEmpty);
      });
    });

    group('unión de destinos y vecindad ortogonal', () {
      test('une los destinos de ambas orientaciones de los dados', () {
        // Con dados [3,5] en el tablero inicial: (3,1)=3 permite colocar 5 en
        // (2,1) o (3,2); (5,2)=5 permite colocar 3 en varias vecinas también.
        final estado = JuegoEstado(tablero: tableroInicial, dados: const [3, 5]);

        final validasDesde31 = JuegoEstado(
          tablero: tableroInicial,
          dados: const [3, 5],
          ancla: const PosicionCasilla(3, 1),
        ).casillasValidas;
        final validasDesde52 = JuegoEstado(
          tablero: tableroInicial,
          dados: const [3, 5],
          ancla: const PosicionCasilla(5, 2),
        ).casillasValidas;

        for (final destino in validasDesde31) {
          expect(estado.casillasConJugadaPosible, contains(destino));
        }
        for (final destino in validasDesde52) {
          expect(estado.casillasConJugadaPosible, contains(destino));
        }
      });

      test('no incluye casillas ocupadas ni destinos en diagonal', () {
        final estado = JuegoEstado(tablero: tableroInicial, dados: const [3, 5]);

        for (final destino in estado.casillasConJugadaPosible) {
          expect(estado.valorEn(destino), isNull);
        }

        // Ninguna estrella (ya ocupada) puede aparecer como destino.
        for (final estrella in casillasEstrella) {
          expect(estado.casillasConJugadaPosible, isNot(contains(estrella)));
        }
      });

      test('solo incluye vecinos ortogonales, nunca en diagonal', () {
        final estado = JuegoEstado(tablero: tableroInicial, dados: const [3, 5]);

        for (final destino in estado.casillasConJugadaPosible) {
          final esOrtogonalDeAlgunAncla = casillasEstrella.any((ancla) {
            final difFila = (destino.fila - ancla.fila).abs();
            final difColumna = (destino.columna - ancla.columna).abs();
            return (difFila == 1 && difColumna == 0) || (difFila == 0 && difColumna == 1);
          });
          expect(esOrtogonalDeAlgunAncla, isTrue);
        }
      });
    });
  });

  group('MovimientoLog', () {
    group('cuándo se genera (o no) un log', () {
      test('una colocacion valida genera exactamente un log', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2)); // ancla con el 1
        cubit.tocarCasilla(const PosicionCasilla(0, 1)); // coloca el 6

        expect(cubit.state.logs.length, 1);
        cubit.close();
      });

      test('seleccionar un dado o un ancla sin colocar no genera log', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2)); // solo selecciona el ancla

        expect(cubit.state.logs, isEmpty);
        cubit.close();
      });

      test('tirar los dados no genera log', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();

        expect(cubit.state.logs, isEmpty);
        cubit.close();
      });
    });

    group('contenido y orden del historial', () {
      test('el log contiene los datos del movimiento y el puntaje antes/despues', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2)); // ancla con el 1
        cubit.tocarCasilla(const PosicionCasilla(0, 1)); // coloca el 6 (zona verde)

        final log = cubit.state.logs.single;
        expect(log.turno, 1);
        expect(log.dados, [1, 6]);
        expect(log.ancla, const PosicionCasilla(0, 2));
        expect(log.valorAncla, 1);
        expect(log.destino, const PosicionCasilla(0, 1));
        expect(log.numeroColocado, 6);
        expect(log.zona, ColorZona.verde);
        expect(log.puntajeAntes, 0);
        expect(log.puntajeDespues, 0); // la zona verde de (0,1) no quedó completa
        cubit.close();
      });

      test('dos colocaciones generan dos logs en orden, sin perder el anterior', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6, 2, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2));
        cubit.tocarCasilla(const PosicionCasilla(0, 1)); // primera colocación

        cubit.tirarDados();
        cubit.seleccionarDado(2);
        cubit.tocarCasilla(const PosicionCasilla(1, 5)); // estrella con el 2
        cubit.tocarCasilla(const PosicionCasilla(1, 4)); // coloca el 6

        expect(cubit.state.logs.length, 2);
        expect(cubit.state.logs[0].turno, 1);
        expect(cubit.state.logs[1].turno, 2);
        cubit.close();
      });
    });
  });

  group('JuegoCubit.seleccionarDado y casillasAnclaPosibles', () {
    group('selección del dado ancla', () {
      test('seleccionar un dado no selecciona ninguna casilla automaticamente', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);

        expect(cubit.state.numeroAnclaElegido, 1);
        expect(cubit.state.ancla, isNull);
        cubit.close();
      });

      test('no se puede elegir un valor que no sea uno de los dos dados', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(4); // ni 1 ni 6

        expect(cubit.state.numeroAnclaElegido, isNull);
        cubit.close();
      });

      test('elegir un dado distinto abandona el ancla ya seleccionada', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        cubit.tirarDados();
        cubit.seleccionarDado(3);
        cubit.tocarCasilla(const PosicionCasilla(3, 1)); // ancla con el 3
        expect(cubit.state.ancla, isNotNull);

        cubit.seleccionarDado(5); // cambia de opinión
        expect(cubit.state.ancla, isNull);
        expect(cubit.state.numeroAnclaElegido, 5);
        cubit.close();
      });
    });

    group('cálculo de casillasAnclaPosibles', () {
      test('casillasAnclaPosibles solo incluye casillas con el numero elegido y destino valido', () {
        final estado = JuegoEstado(
          tablero: tableroInicial,
          dados: const [1, 6],
          numeroAnclaElegido: 1,
        );

        // (0,2) es la única estrella con el 1 y tiene destinos válidos para el 6.
        expect(estado.casillasAnclaPosibles, {const PosicionCasilla(0, 2)});
      });

      test('una casilla con el numero elegido pero sin destino valido no es ancla posible', () {
        final tablero = [for (final fila in tableroInicial) [...fila]];
        // Encierra la estrella (0,2)=1 con sus tres vecinas ocupadas.
        tablero[1][2] = 9;
        tablero[0][1] = 9;
        tablero[0][3] = 9;

        final estado = JuegoEstado(tablero: tablero, dados: const [1, 6], numeroAnclaElegido: 1);
        expect(estado.casillasAnclaPosibles, isNot(contains(const PosicionCasilla(0, 2))));
      });

      test('tocar una casilla que no es una ancla posible no hace nada', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(5, 2)); // tiene el 5, no el 1

        expect(cubit.state.ancla, isNull);
        cubit.close();
      });
    });
  });

  group('flujo completo: tirar, elegir dado, elegir ancla, colocar', () {
    test('flujo directo: dado 1 como ancla, se coloca el 6', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
      cubit.tirarDados();
      cubit.seleccionarDado(1);
      cubit.tocarCasilla(const PosicionCasilla(0, 2));
      cubit.tocarCasilla(const PosicionCasilla(0, 1));

      expect(cubit.state.valorEn(const PosicionCasilla(0, 1)), 6);
      expect(cubit.state.logs.single.numeroColocado, 6);
      expect(cubit.state.dados, isNull); // listo para el siguiente turno
      cubit.close();
    });

    test('flujo inverso: dado 6 como ancla, se coloca el 1', () {
      final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
      cubit.tirarDados();
      cubit.seleccionarDado(6);
      cubit.tocarCasilla(const PosicionCasilla(6, 4)); // estrella con el 6
      final destino = cubit.state.casillasValidas.first;
      cubit.tocarCasilla(destino);

      expect(cubit.state.valorEn(destino), 1);
      expect(cubit.state.logs.single.numeroColocado, 1);
      cubit.close();
    });
  });

  group('JuegoCubit.saltarTurno', () {
    group('comportamiento general de saltar turno', () {
      test('se puede saltar el turno aunque exista una jugada valida', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        cubit.tirarDados();
        expect(cubit.state.puedeVolverATirar, isFalse); // hay jugada

        cubit.saltarTurno();

        expect(cubit.state.eventosTurno.length, 1);
        cubit.close();
      });

      test('saltar turno limpia dados, dado elegido, ancla y resaltados', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2));

        cubit.saltarTurno();

        expect(cubit.state.dados, isNull);
        expect(cubit.state.numeroAnclaElegido, isNull);
        expect(cubit.state.ancla, isNull);
        expect(cubit.state.casillasAnclaPosibles, isEmpty);
        cubit.close();
      });

      test('despues de saltar se puede tirar de nuevo, sin quedar bloqueado', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5, 1, 2]));
        cubit.tirarDados(); // [3,5], hay jugada
        cubit.saltarTurno();

        expect(cubit.state.puedeVolverATirar, isTrue);
        cubit.tirarDados(); // [1,2]

        expect(cubit.state.dados, [1, 2]);
        cubit.close();
      });
    });

    group('saltar turno no afecta puntaje ni genera logs', () {
      test('saltar turno no modifica el puntaje ni coloca ningun numero', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        final tableroAntes = cubit.state.tablero;
        final puntajeAntes = cubit.state.puntaje;

        cubit.tirarDados();
        cubit.saltarTurno();

        expect(cubit.state.puntaje, puntajeAntes);
        expect(cubit.state.tablero, tableroAntes);
        cubit.close();
      });

      test('saltar turno no genera un MovimientoLog de colocacion', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        cubit.tirarDados();
        cubit.saltarTurno();

        expect(cubit.state.logs, isEmpty);
        cubit.close();
      });
    });

    group('EventoTurno: contenido y numeración de turno', () {
      test('el evento de turno registra el numero de turno y los dados', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        cubit.tirarDados();
        cubit.saltarTurno();

        final evento = cubit.state.eventosTurno.single;
        expect(evento.turno, 1);
        expect(evento.dados, [3, 5]);
        cubit.close();
      });

      test('turnoActual cuenta colocaciones y saltos en una sola numeracion', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5, 1, 6]));
        cubit.tirarDados();
        cubit.saltarTurno(); // turno 1: salto

        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2));
        cubit.tocarCasilla(const PosicionCasilla(0, 1)); // turno 2: colocación

        expect(cubit.state.eventosTurno.single.turno, 1);
        expect(cubit.state.logs.single.turno, 2);
        expect(cubit.state.turnoActual, 3);
        cubit.close();
      });
    });
  });

  group('eventos de puntuacion', () {
    List<List<int?>> tableroVacio() => List.generate(7, (_) => List<int?>.filled(7, null));

    group('EventoPuntuacion: puntos otorgados por color', () {
      test('completar la zona azul inferior derecha otorga y notifica 7 puntos', () {
        final tablero = tableroVacio();
        tablero[4][6] = 2;
        tablero[5][6] = 2;
        tablero[6][5] = 2; // ancla: vecina vacia de (5,5)
        // (5,5) queda vacia: es el ultimo cupo de la zona azul.

        final cubit = JuegoCubit(tablero, random: _DadosFijos([2, 2]));
        cubit.tirarDados();
        cubit.seleccionarDado(2);
        cubit.tocarCasilla(const PosicionCasilla(6, 5));
        cubit.tocarCasilla(const PosicionCasilla(5, 5));

        final zonaAzul = zonasNivel1.firstWhere((z) => z.color == ColorZona.azul &&
            z.casillas.contains(const PosicionCasilla(5, 5)));
        final evento = cubit.state.eventosPuntuacion.single;
        expect(evento.puntosObtenidos, 7);
        expect(evento.colorZona, ColorZona.azul);
        expect(evento.turno, 1);
        expect(evento.zonaId, idDeZona(zonaAzul));
        expect(evento.nombreZona, 'Zona Azul inferior derecha');
        cubit.close();
      });

      test('completar una zona verde otorga y notifica 4 puntos', () {
        final tablero = tableroVacio();
        tablero[1][6] = 1;
        tablero[2][5] = 1;
        tablero[2][6] = 7; // ancla
        tablero[3][4] = 1;
        tablero[3][5] = 1;
        // (3,6) queda vacia: es el ultimo cupo de esta zona verde.

        final cubit = JuegoCubit(tablero, random: _DadosFijos([7, 3]));
        cubit.tirarDados();
        cubit.seleccionarDado(7);
        cubit.tocarCasilla(const PosicionCasilla(2, 6));
        cubit.tocarCasilla(const PosicionCasilla(3, 6));

        final evento = cubit.state.eventosPuntuacion.single;
        expect(evento.puntosObtenidos, 4);
        expect(evento.colorZona, ColorZona.verde);
        cubit.close();
      });

      test('completar una zona roja otorga y notifica 6 puntos', () {
        final tablero = tableroVacio();
        tablero[2][1] = 1;
        tablero[2][2] = 2;
        tablero[3][1] = 3;
        tablero[4][1] = 4;
        tablero[5][0] = 9; // ancla
        // (5,1) queda vacia: es el ultimo cupo de esta zona roja.

        final cubit = JuegoCubit(tablero, random: _DadosFijos([9, 5]));
        cubit.tirarDados();
        cubit.seleccionarDado(9);
        cubit.tocarCasilla(const PosicionCasilla(5, 0));
        cubit.tocarCasilla(const PosicionCasilla(5, 1));

        final evento = cubit.state.eventosPuntuacion.single;
        expect(evento.puntosObtenidos, 6);
        expect(evento.colorZona, ColorZona.rojo);
        cubit.close();
      });

      test('completar una zona morada otorga y notifica 6 puntos', () {
        final tablero = tableroVacio();
        tablero[0][3] = 1;
        tablero[0][4] = 1;
        tablero[0][5] = 1;
        tablero[1][4] = 1; // ancla
        tablero[1][5] = 1;
        // (2,4) queda vacia: es el ultimo cupo de esta zona morada.

        final cubit = JuegoCubit(tablero, random: _DadosFijos([1, 1]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(1, 4));
        cubit.tocarCasilla(const PosicionCasilla(2, 4));

        final evento = cubit.state.eventosPuntuacion.single;
        expect(evento.puntosObtenidos, 6);
        expect(evento.colorZona, ColorZona.morado);
        cubit.close();
      });

      test('completar la zona amarilla global genera el evento recien en la quinta casilla', () {
        final tablero = tableroVacio();
        tablero[0][0] = 1;
        tablero[0][6] = 2;
        tablero[3][3] = 3;
        tablero[6][0] = 4;
        tablero[6][5] = 9; // ancla, vecina vacia de (6,6)
        // (6,6) queda vacia: es la quinta y ultima casilla amarilla.

        final cubit = JuegoCubit(tablero, random: _DadosFijos([9, 5]));
        cubit.tirarDados();
        cubit.seleccionarDado(9);
        cubit.tocarCasilla(const PosicionCasilla(6, 5));

        expect(cubit.state.eventosPuntuacion, isEmpty); // todavia no se coloco

        cubit.tocarCasilla(const PosicionCasilla(6, 6));

        final evento = cubit.state.eventosPuntuacion.single;
        expect(evento.puntosObtenidos, 6);
        expect(evento.colorZona, ColorZona.amarillo);
        expect(evento.nombreZona, 'Zona Amarillo');
        cubit.close();
      });
    });

    group('EventoPuntuacion: casos sin evento', () {
      test('completar una colocacion que no cierra su zona no genera evento', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        cubit.tirarDados();
        cubit.seleccionarDado(1);
        cubit.tocarCasilla(const PosicionCasilla(0, 2)); // ancla con el 1
        cubit.tocarCasilla(const PosicionCasilla(0, 1)); // coloca el 6, zona verde sigue incompleta

        expect(cubit.state.eventosPuntuacion, isEmpty);
        cubit.close();
      });

      test('saltar el turno no genera ningun evento de puntuacion', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([3, 5]));
        cubit.tirarDados();
        cubit.saltarTurno();

        expect(cubit.state.eventosPuntuacion, isEmpty);
        cubit.close();
      });
    });

    group('EventoPuntuacion: identidad del jugador asignada', () {
      test('el id de jugador del evento viene del ProveedorJugador inyectado', () {
        final tablero = tableroVacio();
        tablero[4][6] = 2;
        tablero[5][6] = 2;
        tablero[6][5] = 2;

        final cubit = JuegoCubit(
          tablero,
          random: _DadosFijos([2, 2]),
          jugador: const _JugadorDePrueba('jugador-test'),
        );
        cubit.tirarDados();
        cubit.seleccionarDado(2);
        cubit.tocarCasilla(const PosicionCasilla(6, 5));
        cubit.tocarCasilla(const PosicionCasilla(5, 5));

        expect(cubit.state.eventosPuntuacion.single.jugadorId, 'jugador-test');
        cubit.close();
      });
    });
  });

  group('JuegoCubit/JuegoEstado: parametrización por ConfiguracionNivel', () {
    group('JuegoCubit.configuracionNivel: fuente única para sincronizar con JuegoScreen', () {
      test('sin indicar nivel, configuracionNivel es configuracionNivel1', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        expect(cubit.configuracionNivel, same(configuracionNivel1));
        cubit.close();
      });

      test('con nivel indicado, configuracionNivel es exactamente ese objeto', () {
        final tablero = tableroDesdeNumerosIniciales([2], nivel: _nivelSintetico);
        final cubit = JuegoCubit(tablero, nivel: _nivelSintetico, random: _DadosFijos([2, 2]));
        expect(cubit.configuracionNivel, same(_nivelSintetico));
        cubit.close();
      });
    });

    group('regresión: sin indicar nivel, o con configuracionNivel1, nivel 1 funciona igual', () {
      test('sin indicar nivel, el estado usa zonasNivel1 y nombresZonaNivel1 (de siempre)', () {
        final cubit = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        expect(cubit.state.zonas, zonasNivel1);
        expect(cubit.state.nombresDeZona, nombresZonaNivel1);
        cubit.close();
      });

      test('con nivel: configuracionNivel1, el resultado es igual que sin indicar nada', () {
        final cubitPorDefecto = JuegoCubit(tableroInicial, random: _DadosFijos([1, 6]));
        final cubitExplicito = JuegoCubit(
          tableroInicial,
          random: _DadosFijos([1, 6]),
          nivel: configuracionNivel1,
        );

        cubitPorDefecto.tirarDados();
        cubitExplicito.tirarDados();
        cubitPorDefecto.seleccionarDado(1);
        cubitExplicito.seleccionarDado(1);
        cubitPorDefecto.tocarCasilla(const PosicionCasilla(0, 2));
        cubitExplicito.tocarCasilla(const PosicionCasilla(0, 2));

        expect(cubitExplicito.state.ancla, cubitPorDefecto.state.ancla);
        expect(cubitExplicito.state.numeroAColocar, cubitPorDefecto.state.numeroAColocar);
        expect(cubitExplicito.state.casillasValidas, cubitPorDefecto.state.casillasValidas);
        cubitPorDefecto.close();
        cubitExplicito.close();
      });
    });

    group('usa la configuración sintética recibida, no los globales de nivel 1', () {
      test('tableroDesdeNumerosIniciales arma el tablero segun el nivel recibido', () {
        final tablero = tableroDesdeNumerosIniciales([2], nivel: _nivelSintetico);

        expect(tablero.length, 2); // 2x2, no 7x7
        expect(tablero[0].length, 2);
        expect(tablero[0][0], 2); // unica estrella del nivel sintetico
      });

      test('JuegoCubit construido con nivel usa las zonas de esa configuracion', () {
        final tablero = tableroDesdeNumerosIniciales([2], nivel: _nivelSintetico);
        final cubit = JuegoCubit(tablero, nivel: _nivelSintetico, random: _DadosFijos([2, 2]));

        expect(cubit.state.zonas, _nivelSintetico.zonas);
        expect(cubit.state.zonas, isNot(zonasNivel1));
        expect(cubit.state.tablero.length, 2);
        cubit.close();
      });

      test('la regla de la zona sintetica (azul: todos iguales) se aplica al colocar', () {
        final tablero = tableroDesdeNumerosIniciales([2], nivel: _nivelSintetico);
        final cubit = JuegoCubit(tablero, nivel: _nivelSintetico, random: _DadosFijos([2, 2]));

        cubit.tirarDados();
        cubit.seleccionarDado(2);
        cubit.tocarCasilla(const PosicionCasilla(0, 0)); // ancla, ya tiene el 2
        cubit.tocarCasilla(const PosicionCasilla(0, 1)); // coloca el otro 2

        expect(cubit.state.valorEn(const PosicionCasilla(0, 1)), 2);
        cubit.close();
      });

      test('al completar la zona sintetica, el EventoPuntuacion usa nombresDeZona del nivel recibido', () {
        final tablero = tableroDesdeNumerosIniciales([2], nivel: _nivelSintetico);
        tablero[0][1] = 2;
        tablero[1][0] = 2;
        // (1,1) queda vacia: ultimo cupo de la zona sintetica.

        final cubit = JuegoCubit(tablero, nivel: _nivelSintetico, random: _DadosFijos([2, 2]));
        cubit.tirarDados();
        cubit.seleccionarDado(2);
        cubit.tocarCasilla(const PosicionCasilla(0, 1)); // ancla; (1,1) es su vecina vacia
        cubit.tocarCasilla(const PosicionCasilla(1, 1));

        final zonaSintetica = _nivelSintetico.zonas.single;
        final evento = cubit.state.eventosPuntuacion.single;
        expect(evento.nombreZona, _nivelSintetico.nombresDeZona[idDeZona(zonaSintetica)]);
        expect(evento.nombreZona, 'Zona Azul');
        cubit.close();
      });
    });

    group('zonas con Tipo explícito (blanco/naranja) integradas con JuegoEstado, sin romper nivel 1', () {
      // JuegoEstado es lo que JuegoCubit usa internamente para validar
      // colocaciones (_zonaAcepta, casillasValidas): probar acá que respeta
      // un Tipo explícito es fiel a cómo lo usaría JuegoCubit. Se prueba a
      // este nivel (y no armando una ConfiguracionNivel completa) porque
      // ConfiguracionNivel.zonas todavía no tiene forma de asignar un Tipo
      // explícito por zona al calcularlas automáticamente (flood fill) —
      // ver el informe final, queda señalado como pendiente para la Etapa 4.
      test('una zona naranja superior (Tipo explícito) acepta 4-6 y rechaza el resto', () {
        final tablero = [
          [5, null],
        ];
        const zona = ZonaTablero(
          ColorZona.naranja,
          [PosicionCasilla(0, 0), PosicionCasilla(0, 1)],
          TipoNaranjaSuperior(),
        );

        final estadoAcepta = JuegoEstado(
          tablero: tablero,
          dados: const [5, 6],
          ancla: const PosicionCasilla(0, 0),
          zonas: [zona],
        );
        expect(estadoAcepta.numeroAColocar, 6);
        expect(estadoAcepta.casillasValidas, contains(const PosicionCasilla(0, 1)));

        final estadoRechaza = JuegoEstado(
          tablero: tablero,
          dados: const [5, 2],
          ancla: const PosicionCasilla(0, 0),
          zonas: [zona],
        );
        expect(estadoRechaza.numeroAColocar, 2);
        expect(estadoRechaza.casillasValidas, isNot(contains(const PosicionCasilla(0, 1))));
      });

      test('una zona naranja inferior (Tipo explícito) acepta 1-3 y rechaza el resto', () {
        final tablero = [
          [1, null],
        ];
        const zona = ZonaTablero(
          ColorZona.naranja,
          [PosicionCasilla(0, 0), PosicionCasilla(0, 1)],
          TipoNaranjaInferior(),
        );

        final estadoAcepta = JuegoEstado(
          tablero: tablero,
          dados: const [1, 3],
          ancla: const PosicionCasilla(0, 0),
          zonas: [zona],
        );
        expect(estadoAcepta.casillasValidas, contains(const PosicionCasilla(0, 1)));

        final estadoRechaza = JuegoEstado(
          tablero: tablero,
          dados: const [1, 6],
          ancla: const PosicionCasilla(0, 0),
          zonas: [zona],
        );
        expect(estadoRechaza.casillasValidas, isNot(contains(const PosicionCasilla(0, 1))));
      });

      test('nivel 1 sigue sin usar ningun Tipo explícito: cada zona resuelve por su color', () {
        for (final zona in zonasNivel1) {
          expect(zona.tipo, tipoDeColor(zona.color));
        }
      });
    });
  });
}
