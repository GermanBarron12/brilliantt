import 'dart:math';

import 'package:test/test.dart';

import 'package:brilliant/juego_cubit.dart';
import 'package:brilliant/tablero_layout.dart';

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
  });
}
