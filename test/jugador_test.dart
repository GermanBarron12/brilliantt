import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/jugador.dart';

void main() {
  group('ProveedorJugador y JugadorLocalUnico: identificación local del jugador', () {
    test('JugadorLocalUnico siempre devuelve el mismo id fijo', () {
      const jugador = JugadorLocalUnico();
      expect(jugador.jugadorActualId, 'jugador-1');
      expect(jugador.jugadorActualId, jugador.jugadorActualId);
    });
  });
}
