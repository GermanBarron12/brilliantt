import 'package:flutter_test/flutter_test.dart';

import 'package:brilliant/jugador.dart';

void main() {
  test('JugadorLocalUnico siempre devuelve el mismo id fijo', () {
    const jugador = JugadorLocalUnico();
    expect(jugador.jugadorActualId, 'jugador-1');
    expect(jugador.jugadorActualId, jugador.jugadorActualId);
  });
}
