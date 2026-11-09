import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:brilliant_core/brilliant_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'modelos.dart';

const Uuid _uuid = Uuid();

/// Tipos de movimiento que se persisten en `movimientos_partida`. Son el
/// equivalente multijugador de los pasos de un turno del modo de un
/// jugador (ver `JuegoCubit`): un solo tipo de movimiento por mensaje que
/// manda el cliente (incluso "tocar_casilla", que en vivo puede resolverse
/// como elegir ancla o como colocar un número — ver [_resolverTocarCasilla]
/// — nunca se distingue en la base, se re-decide igual en el replay), más
/// un movimiento propio del servidor para cuando a alguien se le pasa el
/// privilegio de tirar por quedarse desconectado sin tirar.
class _TipoMovimiento {
  static const String tirarDadosCompartido = 'tirar_dados_compartido';
  static const String seleccionarDadoJugador = 'seleccionar_dado_jugador';
  static const String tocarCasillaJugador = 'tocar_casilla_jugador';
  static const String pasarRondaJugador = 'pasar_ronda_jugador';
  static const String pasarTiradaPorDesconexion = 'pasar_tirada_por_desconexion';
}

/// Reconstruye [estado] con [dados] fijos en el campo `dados` de un
/// tablero, dejando todo lo demás igual. Usado para reproducir, durante el
/// replay, exactamente la misma tirada que ya ocurrió en vivo (nunca una
/// tirada nueva al azar).
JuegoEstado _conDadosFijos(JuegoEstado estado, List<int> dados) {
  return JuegoEstado(
    tablero: estado.tablero,
    dados: dados,
    logs: estado.logs,
    eventosTurno: estado.eventosTurno,
    eventosPuntuacion: estado.eventosPuntuacion,
    zonas: estado.zonas,
    nombresDeZona: estado.nombresDeZona,
    nivelId: estado.nivelId,
  );
}

/// Pone los mismos [dados] (ya elegidos, no al azar) en el tablero de cada
/// jugador: lo que usa el replay para reproducir "tirar_dados_compartido".
PartidaMultijugadorEstado _conDadosCompartidosFijos(PartidaMultijugadorEstado estado, List<int> dados) {
  final nuevosTableros = {
    for (final entrada in estado.tableros.entries) entrada.key: _conDadosFijos(entrada.value, dados),
  };
  return estado.copyWith(tableros: nuevosTableros, dadosActuales: dados);
}

/// Decide, según el tablero actual de [usuarioId], si tocar [posicion] es
/// elegir un ancla o colocar un número ahí, y aplica la transición que
/// corresponda. Null si [posicion] no es ninguna de las dos cosas ahora
/// (ni ancla posible ni destino válido): en vivo es una jugada inválida; el
/// replay nunca debería recibir null, porque solo reproduce movimientos
/// que ya se validaron la primera vez que se aplicaron.
PartidaMultijugadorEstado? _resolverTocarCasilla(
  PartidaMultijugadorEstado estado,
  String usuarioId,
  PosicionCasilla posicion,
) {
  final tablero = estado.tableros[usuarioId]!;
  if (tablero.ancla != null && tablero.casillasValidas.contains(posicion)) {
    return aplicarColocarNumeroJugador(estado, usuarioId, posicion);
  }
  if (tablero.casillasAnclaPosibles.contains(posicion)) {
    return aplicarSeleccionarAnclaJugador(estado, usuarioId, posicion);
  }
  return null;
}

/// Una partida multijugador en curso, en memoria: un tablero por jugador
/// (usando exactamente las mismas reglas y transiciones que el modo de un
/// jugador, desde `brilliant_core`, más el puntaje por carrera y el fin de
/// partida de las reglas oficiales) y quién está conectado. El servidor es
/// la única fuente de verdad: valida cada mensaje antes de aplicarlo y
/// nunca confía en lo que un cliente dice que pasó.
class SalaDePartida {
  SalaDePartida._({
    required this.partidaId,
    required Database db,
    required PartidaMultijugadorEstado estado,
    required List<Participante> participantes,
    required Duration duracionEsperaDesconexion,
  })  : _db = db,
        _estado = estado,
        _participantes = participantes,
        _duracionEsperaDesconexion = duracionEsperaDesconexion;

  final String partidaId;
  final Database _db;
  final Random _random = Random.secure();
  final Map<String, WebSocketChannel> _conexiones = {};

  /// Cuanto se espera, desde que alguien con algo pendiente (tirar, o
  /// actuar esta ronda) se desconecta, antes de resolverlo
  /// automaticamente en su lugar si no volvio a tiempo. Configurable solo
  /// para que los tests no tengan que esperar un minuto real.
  final Duration _duracionEsperaDesconexion;

  /// Un timer de desconexion pendiente por jugador (nunca mas de uno por
  /// id: cada vez que se reprograma, se cancela el anterior). A diferencia
  /// del modo de un jugador, varios jugadores pueden tener algo pendiente
  /// al mismo tiempo (todos los que no actuaron esta ronda), asi que esto
  /// ya no es un unico Timer.
  final Map<String, Timer> _timersPorJugador = {};

  PartidaMultijugadorEstado _estado;
  List<Participante> _participantes;

  /// Reconstruye la sala desde la base de datos: carga la partida, sus
  /// participantes y los números iniciales que cada uno eligió, y
  /// reproduce (en orden) cada movimiento ya persistido, cerrando cada
  /// ronda que haya quedado completa en el camino — igual que en vivo. Así,
  /// si el servidor se reinicia, una partida en curso retoma exactamente
  /// donde estaba.
  factory SalaDePartida.cargar(
    Database db,
    String partidaId, {
    Duration duracionEsperaDesconexion = const Duration(seconds: 60),
  }) {
    final filaPartida = db.select('SELECT * FROM partidas WHERE id = ?', [partidaId]).first;
    final nivel = configuracionPorId(filaPartida['nivel_id'] as int)!;

    final filasParticipantes = db.select(
      'SELECT p.usuario_id, p.orden_turno, p.estado, p.es_creador, u.nombre_usuario '
      'FROM participantes_partida p JOIN usuarios u ON u.id = p.usuario_id '
      'WHERE p.partida_id = ? ORDER BY p.orden_turno ASC',
      [partidaId],
    );
    final participantes = [
      for (final fila in filasParticipantes)
        Participante(
          usuarioId: fila['usuario_id'] as String,
          nombreUsuario: fila['nombre_usuario'] as String,
          ordenTurno: fila['orden_turno'] as int,
          estado: fila['estado'] as String,
          esCreador: (fila['es_creador'] as int) == 1,
          numerosListos: true, // ya esta en_curso: por construccion, todos los confirmaron.
        ),
    ];
    final ordenJugadores = [for (final p in participantes) p.usuarioId];

    final filasNumeros = db.select(
      'SELECT usuario_id, numeros FROM numeros_iniciales_participante WHERE partida_id = ?',
      [partidaId],
    );
    final numerosPorJugador = {
      for (final fila in filasNumeros)
        fila['usuario_id'] as String: (jsonDecode(fila['numeros'] as String) as List).cast<int>(),
    };

    var estado = crearPartidaMultijugador(
      ordenJugadores: ordenJugadores,
      numerosInicialesPorJugador: numerosPorJugador,
      nivel: nivel,
    );

    final filasMovimientos = db.select(
      'SELECT tipo, payload, usuario_id FROM movimientos_partida WHERE partida_id = ? ORDER BY id ASC',
      [partidaId],
    );
    for (final fila in filasMovimientos) {
      estado = _aplicarDesdeRegistro(
        estado,
        fila['tipo'] as String,
        jsonDecode(fila['payload'] as String) as Map<String, dynamic>,
        fila['usuario_id'] as String?,
      );
      estado = _posiblementeCerrarRonda(estado);
    }

    // Si la partida ya quedó terminada según los movimientos reproducidos
    // pero la fila de `partidas` todavía no lo refleja (por ejemplo, el
    // servidor se reinició justo antes de persistirlo tras la última
    // jugada en vivo), se completa acá: el estado en memoria y el de la
    // base nunca deben quedar desincronizados entre sí.
    if (estado.terminada && filaPartida['estado'] != EstadoPartida.finalizada) {
      db.execute(
        "UPDATE partidas SET estado = ?, finalizada_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?",
        [EstadoPartida.finalizada, partidaId],
      );
    }

    return SalaDePartida._(
      partidaId: partidaId,
      db: db,
      estado: estado,
      participantes: participantes,
      duracionEsperaDesconexion: duracionEsperaDesconexion,
    );
  }

  /// Reproduce un movimiento ya guardado, igual que el handler en vivo pero
  /// sin validar nada (ya se validó la primera vez que se aplicó, antes de
  /// guardarlo) y sin tirar dados nuevos ni elegir al azar nada: para
  /// "tirar dados" se usa el resultado guardado, para "a quién le toca
  /// tirar tras una desconexión" se usa el jugador ya guardado, nunca se
  /// vuelve a calcular nada al azar, para que la reconstrucción sea siempre
  /// igual a la partida real.
  static PartidaMultijugadorEstado _aplicarDesdeRegistro(
    PartidaMultijugadorEstado estado,
    String tipo,
    Map<String, dynamic> payload,
    String? usuarioId,
  ) {
    switch (tipo) {
      case _TipoMovimiento.tirarDadosCompartido:
        return _conDadosCompartidosFijos(estado, (payload['dados'] as List).cast<int>());
      case _TipoMovimiento.seleccionarDadoJugador:
        return aplicarSeleccionarDadoJugador(estado, usuarioId!, payload['valor'] as int);
      case _TipoMovimiento.tocarCasillaJugador:
        final posicion = PosicionCasilla(payload['fila'] as int, payload['columna'] as int);
        return _resolverTocarCasilla(estado, usuarioId!, posicion)!;
      case _TipoMovimiento.pasarRondaJugador:
        return aplicarPasarRondaJugador(estado, usuarioId!);
      case _TipoMovimiento.pasarTiradaPorDesconexion:
        return estado.copyWith(jugadorQueTira: payload['jugadorQueTira'] as String);
      default:
        throw StateError('Tipo de movimiento desconocido en la base de datos: $tipo');
    }
  }

  /// Si la ronda ya está completa (todos los jugadores activos actuaron
  /// con los dados actuales), la cierra; si no, devuelve [estado] igual.
  /// Nunca se persiste como su propio movimiento (ver `_TipoMovimiento`):
  /// se re-deriva acá, tanto en vivo como en el replay, a partir de los
  /// movimientos de jugador ya guardados.
  static PartidaMultijugadorEstado _posiblementeCerrarRonda(PartidaMultijugadorEstado estado) {
    return rondaCompleta(estado) ? aplicarCierreDeRonda(estado) : estado;
  }

  /// Registra la conexión de [usuarioId] y le manda el estado actual. Si
  /// ya tenía una conexión abierta (por ejemplo, otra pestaña), se
  /// reemplaza por esta. Si tenía pendiente que se le resolviera algo por
  /// desconexión, se cancela: volvió a tiempo.
  void conectar(String usuarioId, WebSocketChannel canal) {
    _conexiones[usuarioId] = canal;
    _cancelarTimerDe(usuarioId);
    if (_cambiarEstadoParticipante(usuarioId, EstadoParticipante.conectado)) {
      _difundirEstado();
    } else {
      canal.sink.add(jsonEncode({'tipo': 'estado', 'partida': _estadoPublico()}));
    }
  }

  void _cancelarTimerDe(String usuarioId) {
    _timersPorJugador.remove(usuarioId)?.cancel();
  }

  /// Cancela todos los timers de desconexión pendientes. Pensado para los
  /// tests: sin esto, un timer pendiente puede disparar después de que el
  /// test ya cerró su base de datos, haciendo fallar a un test
  /// completamente distinto.
  void _cancelarTodosLosTimers() {
    for (final timer in _timersPorJugador.values) {
      timer.cancel();
    }
    _timersPorJugador.clear();
  }

  /// Marca a [usuarioId] como desconectado y reprograma los timers de
  /// desconexión pendientes (ver [_reprogramarTimersParaDesconectados]):
  /// si tenía algo pendiente ahora mismo (tirar, o actuar esta ronda), va
  /// a resolvérsele automáticamente si no vuelve antes de
  /// [_duracionEsperaDesconexion].
  void desconectar(String usuarioId, WebSocketChannel canal) {
    if (_conexiones[usuarioId] != canal) return;
    _conexiones.remove(usuarioId);
    if (_cambiarEstadoParticipante(usuarioId, EstadoParticipante.desconectado)) {
      _difundirEstado();
    }
    _reprogramarTimersParaDesconectados();
  }

  /// true si [usuarioId] tiene algo pendiente por hacer ahora mismo: tirar
  /// (si le toca a él y nadie tiró todavía esta ronda) o actuar esta ronda
  /// (si ya se tiró y todavía no actuó).
  bool _tienePendiente(String usuarioId) {
    if (!_estado.jugadoresActivos.contains(usuarioId)) return false;
    if (_estado.dadosActuales == null) {
      return usuarioId == _estado.jugadorQueTira;
    }
    return !_estado.jugadoresQueYaActuaron.contains(usuarioId);
  }

  /// Recorre a todos los participantes desconectados y les arma un timer
  /// si tienen algo pendiente ahora mismo (cancelando cualquiera que
  /// tuvieran de antes). Se llama tras cualquier desconexión y tras
  /// cualquier cambio de estado de la partida (tirar, actuar, cerrar una
  /// ronda): por ejemplo, al abrir una ronda nueva, alguien que ya estaba
  /// desconectado desde antes no recibe un evento `desconectar()` nuevo,
  /// pero ahora puede tener algo pendiente que antes no tenía (o deja de
  /// tenerlo), así que hay que recalcularlo todo acá.
  void _reprogramarTimersParaDesconectados() {
    if (_estado.terminada) {
      _cancelarTodosLosTimers();
      return;
    }
    for (final participante in _participantes) {
      if (participante.estado != EstadoParticipante.desconectado) continue;
      final usuarioId = participante.usuarioId;
      _cancelarTimerDe(usuarioId);
      if (_tienePendiente(usuarioId)) {
        _timersPorJugador[usuarioId] = Timer(_duracionEsperaDesconexion, () => _resolverPorDesconexion(usuarioId));
      }
    }
  }

  /// Se ejecuta cuando se cumple la espera de [_duracionEsperaDesconexion]
  /// desde que [usuarioId] quedó con algo pendiente estando desconectado.
  /// Si para entonces ya no tiene nada pendiente (jugó, se resolvió de
  /// otra forma) o volvió a conectarse, no hace nada.
  void _resolverPorDesconexion(String usuarioId) {
    _timersPorJugador.remove(usuarioId);
    if (_conexiones.containsKey(usuarioId) || !_tienePendiente(usuarioId)) return;

    if (_estado.dadosActuales == null) {
      // Le tocaba tirar y no lo hizo: se le pasa el privilegio al
      // siguiente activo, sin abrir ronda (nadie tiró todavía).
      final siguiente = _siguienteActivoDespuesDe(usuarioId);
      _aplicarYPersistir(
        _estado.copyWith(jugadorQueTira: siguiente),
        _TipoMovimiento.pasarTiradaPorDesconexion,
        {'jugadorQueTira': siguiente},
        usuarioId,
      );
    } else {
      _aplicarYPersistir(aplicarPasarRondaJugador(_estado, usuarioId), _TipoMovimiento.pasarRondaJugador, const {}, usuarioId);
    }
  }

  String _siguienteActivoDespuesDe(String usuarioId) {
    final orden = _estado.ordenJugadores;
    final indiceActual = orden.indexOf(usuarioId);
    for (var i = 1; i <= orden.length; i++) {
      final candidato = orden[(indiceActual + i) % orden.length];
      if (_estado.jugadoresActivos.contains(candidato)) return candidato;
    }
    throw StateError('No hay jugadores activos: no se puede continuar la partida.');
  }

  /// Actualiza el estado de conexión de [usuarioId] en memoria y en la base
  /// de datos. No hace nada si ya estaba en ese estado, y devuelve si hubo
  /// un cambio real (para no difundir un estado idéntico al anterior).
  bool _cambiarEstadoParticipante(String usuarioId, String nuevoEstado) {
    final indice = _participantes.indexWhere((p) => p.usuarioId == usuarioId);
    if (indice == -1 || _participantes[indice].estado == nuevoEstado) return false;

    _db.execute(
      'UPDATE participantes_partida SET estado = ? WHERE partida_id = ? AND usuario_id = ?',
      [nuevoEstado, partidaId, usuarioId],
    );
    final anterior = _participantes[indice];
    _participantes[indice] = Participante(
      usuarioId: anterior.usuarioId,
      nombreUsuario: anterior.nombreUsuario,
      ordenTurno: anterior.ordenTurno,
      estado: nuevoEstado,
      esCreador: anterior.esCreador,
      numerosListos: anterior.numerosListos,
    );
    return true;
  }

  /// Procesa un mensaje entrante de [usuarioId]. Cualquier jugada que no
  /// corresponda ahora según las reglas de `brilliant_core`, o fuera de
  /// quién puede hacerla, se rechaza con un mensaje de error solo para
  /// quien la mandó — nunca se aplica ni se le comunica a los demás.
  void recibirMensaje(String usuarioId, String mensajeCrudo) {
    final Map<String, dynamic> mensaje;
    try {
      mensaje = jsonDecode(mensajeCrudo) as Map<String, dynamic>;
    } on FormatException {
      _enviarError(usuarioId, 'MENSAJE_INVALIDO', 'El mensaje no es JSON valido.');
      return;
    }

    final tipo = mensaje['tipo'];
    if (tipo is! String) {
      _enviarError(usuarioId, 'MENSAJE_INVALIDO', 'Falta el campo "tipo".');
      return;
    }

    if (_estado.terminada) {
      _enviarError(usuarioId, 'PARTIDA_TERMINADA', 'La partida ya termino.');
      return;
    }

    switch (tipo) {
      case 'tirar_dados':
        _tirarDadosCompartido(usuarioId);
      case 'seleccionar_dado':
        _seleccionarDadoJugador(usuarioId, mensaje);
      case 'tocar_casilla':
        _tocarCasillaJugador(usuarioId, mensaje);
      case 'pasar_ronda':
        _pasarRondaJugador(usuarioId);
      default:
        _enviarError(usuarioId, 'MENSAJE_INVALIDO', 'Tipo de mensaje desconocido: $tipo.');
    }
  }

  void _tirarDadosCompartido(String usuarioId) {
    if (usuarioId != _estado.jugadorQueTira) {
      _enviarError(usuarioId, 'NO_TE_TOCA_TIRAR', 'No te toca tirar los dados esta ronda.');
      return;
    }
    if (_estado.dadosActuales != null) {
      _enviarError(usuarioId, 'NO_TE_TOCA_TIRAR', 'Ya se tiraron los dados esta ronda.');
      return;
    }

    final nuevoEstado = aplicarTirarDadosCompartido(_estado, _random);
    _aplicarYPersistir(
      nuevoEstado,
      _TipoMovimiento.tirarDadosCompartido,
      {'dados': nuevoEstado.dadosActuales},
      usuarioId,
    );
  }

  /// true si [usuarioId] puede colocar un número o pasar con los dados de
  /// esta ronda: está activo, ya se tiraron los dados, y todavía no actuó.
  bool _puedeActuarEstaRonda(String usuarioId) {
    return _estado.jugadoresActivos.contains(usuarioId) &&
        _estado.dadosActuales != null &&
        !_estado.jugadoresQueYaActuaron.contains(usuarioId);
  }

  void _seleccionarDadoJugador(String usuarioId, Map<String, dynamic> mensaje) {
    if (!_puedeActuarEstaRonda(usuarioId)) {
      _enviarError(usuarioId, 'JUGADA_INVALIDA', 'No podes actuar ahora.');
      return;
    }

    final valor = mensaje['valor'];
    final dados = _estado.dadosActuales!;
    if (valor is! int || (valor != dados[0] && valor != dados[1])) {
      _enviarError(usuarioId, 'JUGADA_INVALIDA', 'Ese valor no es uno de los dados actuales.');
      return;
    }

    final nuevoEstado = aplicarSeleccionarDadoJugador(_estado, usuarioId, valor);
    _aplicarYPersistir(nuevoEstado, _TipoMovimiento.seleccionarDadoJugador, {'valor': valor}, usuarioId);
  }

  void _tocarCasillaJugador(String usuarioId, Map<String, dynamic> mensaje) {
    if (!_puedeActuarEstaRonda(usuarioId)) {
      _enviarError(usuarioId, 'JUGADA_INVALIDA', 'No podes actuar ahora.');
      return;
    }

    final fila = mensaje['fila'];
    final columna = mensaje['columna'];
    if (fila is! int || columna is! int) {
      _enviarError(usuarioId, 'MENSAJE_INVALIDO', 'Faltan "fila"/"columna".');
      return;
    }
    final posicion = PosicionCasilla(fila, columna);

    final nuevoEstado = _resolverTocarCasilla(_estado, usuarioId, posicion);
    if (nuevoEstado == null) {
      _enviarError(usuarioId, 'JUGADA_INVALIDA', 'Esa casilla no es un ancla ni un destino valido ahora.');
      return;
    }

    _aplicarYPersistir(nuevoEstado, _TipoMovimiento.tocarCasillaJugador, {'fila': fila, 'columna': columna}, usuarioId);
  }

  void _pasarRondaJugador(String usuarioId) {
    if (!_puedeActuarEstaRonda(usuarioId)) {
      _enviarError(usuarioId, 'JUGADA_INVALIDA', 'No podes actuar ahora.');
      return;
    }

    final nuevoEstado = aplicarPasarRondaJugador(_estado, usuarioId);
    _aplicarYPersistir(nuevoEstado, _TipoMovimiento.pasarRondaJugador, const {}, usuarioId);
  }

  /// Aplica el movimiento en memoria, cierra la ronda si quedó completa
  /// (ver [_posiblementeCerrarRonda]) y persiste todo junto: el movimiento
  /// en sí, a quién le toca tirar si cambió, y el fin de la partida si
  /// corresponde — todo en una sola transacción, para que el tablero, el
  /// turno y el estado de la partida nunca queden desincronizados entre sí
  /// ni con lo que ve el cliente tras un reinicio del servidor.
  void _aplicarYPersistir(
    PartidaMultijugadorEstado nuevoEstado,
    String tipoMovimiento,
    Map<String, dynamic> payload,
    String usuarioId,
  ) {
    final estadoFinal = _posiblementeCerrarRonda(nuevoEstado);
    final cambioJugadorQueTira = estadoFinal.jugadorQueTira != _estado.jugadorQueTira;
    final terminoAhora = estadoFinal.terminada && !_estado.terminada;

    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO movimientos_partida (id, partida_id, turno, tipo, payload, usuario_id) VALUES (?, ?, ?, ?, ?, ?)',
        [_uuid.v4(), partidaId, estadoFinal.numeroRonda, tipoMovimiento, jsonEncode(payload), usuarioId],
      );
      if (cambioJugadorQueTira) {
        _db.execute('UPDATE partidas SET turno_usuario_id = ? WHERE id = ?', [estadoFinal.jugadorQueTira, partidaId]);
      }
      if (terminoAhora) {
        _db.execute(
          "UPDATE partidas SET estado = ?, finalizada_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now') WHERE id = ?",
          [EstadoPartida.finalizada, partidaId],
        );
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }

    _estado = estadoFinal;
    _difundirEstado();
    _reprogramarTimersParaDesconectados();
  }

  void _difundirEstado() {
    final mensaje = jsonEncode({'tipo': 'estado', 'partida': _estadoPublico()});
    for (final canal in _conexiones.values) {
      canal.sink.add(mensaje);
    }
  }

  void _enviarError(String usuarioId, String codigo, String mensaje) {
    final canal = _conexiones[usuarioId];
    canal?.sink.add(jsonEncode({
      'tipo': 'error',
      'error': {'code': codigo, 'message': mensaje},
    }));
  }

  Map<String, dynamic> _estadoPublico() {
    return {
      'numeroRonda': _estado.numeroRonda,
      'jugadorQueTira': _estado.jugadorQueTira,
      'dados': _estado.dadosActuales,
      'nivelId': _estado.nivelId,
      'terminada': _estado.terminada,
      'ganadores': _estado.ganadores,
      'jugadoresQueYaActuaron': _estado.jugadoresQueYaActuaron.toList(),
      'participantes': _participantes.map((p) => p.toJson()).toList(),
      'tableros': {
        for (final jugadorId in _estado.ordenJugadores)
          jugadorId: {
            'tablero': _estado.tableros[jugadorId]!.tablero,
            'ancla': _estado.tableros[jugadorId]!.ancla == null
                ? null
                : {
                    'fila': _estado.tableros[jugadorId]!.ancla!.fila,
                    'columna': _estado.tableros[jugadorId]!.ancla!.columna,
                  },
            'numeroAnclaElegido': _estado.tableros[jugadorId]!.numeroAnclaElegido,
            'puntaje': _estado.puntajeDe(jugadorId),
          },
      },
      'eventosPuntuacion': [
        for (final evento in _estado.historialPuntuacion)
          {
            'ronda': evento.ronda,
            'jugadorId': evento.jugadorId,
            'colorZona': evento.colorZona.name,
            'zonaId': evento.zonaId,
            'nombreZona': evento.nombreZona,
            'escalon': evento.escalon,
            'puntosObtenidos': evento.puntosObtenidos,
          },
      ],
    };
  }
}

/// Mantiene en memoria, por id de partida, la [SalaDePartida] de cada
/// partida con al menos una conexion activa desde que el proceso arranco
/// (la carga desde la base de datos pasa una sola vez, la primera vez que
/// alguien se conecta a esa partida).
class SalasDePartida {
  SalasDePartida(this._db, {Duration duracionEsperaDesconexion = const Duration(seconds: 60)})
      : _duracionEsperaDesconexion = duracionEsperaDesconexion;

  final Database _db;
  final Duration _duracionEsperaDesconexion;
  final Map<String, SalaDePartida> _salas = {};

  SalaDePartida obtener(String partidaId) {
    return _salas.putIfAbsent(
      partidaId,
      () => SalaDePartida.cargar(_db, partidaId, duracionEsperaDesconexion: _duracionEsperaDesconexion),
    );
  }

  /// Cancela cualquier resolucion por desconexion que haya quedado
  /// pendiente en las salas cargadas. Pensado para los tests: sin esto, un
  /// timer pendiente puede disparar despues de que el test ya cerro su
  /// base de datos, haciendo fallar a un test completamente distinto.
  void cancelarTimersPendientes() {
    for (final sala in _salas.values) {
      sala._cancelarTodosLosTimers();
    }
  }
}
