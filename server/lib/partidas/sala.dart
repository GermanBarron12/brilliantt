import 'dart:convert';
import 'dart:math';

import 'package:brilliant_core/brilliant_core.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'modelos.dart';

const Uuid _uuid = Uuid();

/// Tipos de movimiento que se persisten en `movimientos_partida`. Son los
/// mismos cuatro pasos de un turno que ya existían en el modo de un
/// jugador (ver `JuegoCubit`), más la selección de ancla (que ahí era un
/// paso intermedio sin su propio nombre).
class _TipoMovimiento {
  static const String tirarDados = 'tirar_dados';
  static const String seleccionarDado = 'seleccionar_dado';
  static const String seleccionarAncla = 'seleccionar_ancla';
  static const String colocarNumero = 'colocar_numero';
  static const String saltarTurno = 'saltar_turno';
}

/// Una partida en curso en memoria: el estado autoritativo del tablero
/// (usando exactamente las mismas reglas y transiciones que el modo de un
/// jugador, desde `brilliant_core`) más a quién le toca jugar y quién
/// está conectado. El servidor es la única fuente de verdad: valida cada
/// mensaje antes de aplicarlo y nunca confía en lo que un cliente dice que
/// pasó.
class SalaDePartida {
  SalaDePartida._({
    required this.partidaId,
    required Database db,
    required JuegoEstado estado,
    required List<Participante> participantes,
    required String turnoUsuarioId,
  })  : _db = db,
        _estado = estado,
        _participantes = participantes,
        _turnoUsuarioId = turnoUsuarioId;

  final String partidaId;
  final Database _db;
  final Random _random = Random.secure();
  final Map<String, WebSocketChannel> _conexiones = {};

  JuegoEstado _estado;
  List<Participante> _participantes;
  String _turnoUsuarioId;

  /// Reconstruye la sala desde la base de datos: carga la partida y sus
  /// participantes, y reproduce (en orden) cada movimiento ya persistido
  /// sobre un tablero vacío. Así, si el servidor se reinicia, una partida
  /// en curso retoma exactamente donde estaba.
  factory SalaDePartida.cargar(Database db, String partidaId) {
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
        ),
    ];

    var estado = JuegoEstado(
      tablero: tableroDesdeNumerosIniciales(List<int?>.filled(nivel.casillasEstrella.length, null), nivel: nivel),
      zonas: nivel.zonas,
      nombresDeZona: nivel.nombresDeZona,
      nivelId: nivel.id,
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
    }

    return SalaDePartida._(
      partidaId: partidaId,
      db: db,
      estado: estado,
      participantes: participantes,
      turnoUsuarioId: filaPartida['turno_usuario_id'] as String,
    );
  }

  /// Reproduce un movimiento ya guardado, igual que [_aplicarMensaje] pero
  /// sin validar nada (ya se validó la primera vez que se aplicó, antes de
  /// guardarlo) y sin tirar dados nuevos: para "tirar dados" se usa el
  /// resultado guardado, no uno al azar, para que la reconstrucción sea
  /// siempre igual a la partida real.
  static JuegoEstado _aplicarDesdeRegistro(
    JuegoEstado estado,
    String tipo,
    Map<String, dynamic> payload,
    String? usuarioId,
  ) {
    switch (tipo) {
      case _TipoMovimiento.tirarDados:
        final dados = (payload['dados'] as List).cast<int>();
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
      case _TipoMovimiento.seleccionarDado:
        return aplicarSeleccionarDado(estado, payload['valor'] as int);
      case _TipoMovimiento.seleccionarAncla:
        return aplicarSeleccionarAncla(estado, PosicionCasilla(payload['fila'] as int, payload['columna'] as int));
      case _TipoMovimiento.colocarNumero:
        return aplicarColocarNumero(
          estado,
          PosicionCasilla(payload['fila'] as int, payload['columna'] as int),
          jugadorId: usuarioId!,
        );
      case _TipoMovimiento.saltarTurno:
        return aplicarSaltarTurno(estado);
      default:
        throw StateError('Tipo de movimiento desconocido en la base de datos: $tipo');
    }
  }

  /// Registra la conexión de [usuarioId] y le manda el estado actual. Si
  /// ya tenía una conexión abierta (por ejemplo, otra pestaña), se
  /// reemplaza por esta.
  void conectar(String usuarioId, WebSocketChannel canal) {
    _conexiones[usuarioId] = canal;
    canal.sink.add(jsonEncode({'tipo': 'estado', 'partida': _estadoPublico()}));
  }

  void desconectar(String usuarioId, WebSocketChannel canal) {
    if (_conexiones[usuarioId] == canal) {
      _conexiones.remove(usuarioId);
    }
  }

  /// Procesa un mensaje entrante de [usuarioId]. Cualquier jugada fuera de
  /// su turno, o que no sea válida según las reglas de `brilliant_core`,
  /// se rechaza con un mensaje de error solo para quien la mandó — nunca
  /// se aplica ni se le comunica a los demás.
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

    if (usuarioId != _turnoUsuarioId) {
      _enviarError(usuarioId, 'NO_ES_TU_TURNO', 'No es tu turno todavia.');
      return;
    }

    switch (tipo) {
      case _TipoMovimiento.tirarDados:
        _tirarDados(usuarioId);
      case _TipoMovimiento.seleccionarDado:
        _seleccionarDado(usuarioId, mensaje);
      case 'tocar_casilla':
        _tocarCasilla(usuarioId, mensaje);
      case _TipoMovimiento.saltarTurno:
        _saltarTurno(usuarioId);
      default:
        _enviarError(usuarioId, 'MENSAJE_INVALIDO', 'Tipo de mensaje desconocido: $tipo.');
    }
  }

  void _tirarDados(String usuarioId) {
    if (!_estado.puedeVolverATirar) {
      _enviarError(usuarioId, 'JUGADA_INVALIDA', 'Ya hay una jugada posible pendiente: resolvela o salta el turno.');
      return;
    }

    final nuevoEstado = aplicarTirarDados(_estado, _random);
    _aplicarYPersistir(nuevoEstado, _TipoMovimiento.tirarDados, {'dados': nuevoEstado.dados}, usuarioId);
  }

  void _seleccionarDado(String usuarioId, Map<String, dynamic> mensaje) {
    final valor = mensaje['valor'];
    final dados = _estado.dados;
    if (valor is! int || dados == null || (valor != dados[0] && valor != dados[1])) {
      _enviarError(usuarioId, 'JUGADA_INVALIDA', 'Ese valor no es uno de los dados actuales.');
      return;
    }

    final nuevoEstado = aplicarSeleccionarDado(_estado, valor);
    _aplicarYPersistir(nuevoEstado, _TipoMovimiento.seleccionarDado, {'valor': valor}, usuarioId);
  }

  void _tocarCasilla(String usuarioId, Map<String, dynamic> mensaje) {
    final fila = mensaje['fila'];
    final columna = mensaje['columna'];
    if (fila is! int || columna is! int) {
      _enviarError(usuarioId, 'MENSAJE_INVALIDO', 'Faltan "fila"/"columna".');
      return;
    }
    final posicion = PosicionCasilla(fila, columna);

    if (_estado.ancla != null && _estado.casillasValidas.contains(posicion)) {
      final nuevoEstado = aplicarColocarNumero(_estado, posicion, jugadorId: usuarioId);
      _aplicarYPersistir(
        nuevoEstado,
        _TipoMovimiento.colocarNumero,
        {'fila': fila, 'columna': columna},
        usuarioId,
        avanzarTurno: true,
      );
      return;
    }

    if (_estado.casillasAnclaPosibles.contains(posicion)) {
      final nuevoEstado = aplicarSeleccionarAncla(_estado, posicion);
      _aplicarYPersistir(nuevoEstado, _TipoMovimiento.seleccionarAncla, {'fila': fila, 'columna': columna}, usuarioId);
      return;
    }

    _enviarError(usuarioId, 'JUGADA_INVALIDA', 'Esa casilla no es un ancla ni un destino valido ahora.');
  }

  void _saltarTurno(String usuarioId) {
    final nuevoEstado = aplicarSaltarTurno(_estado);
    _aplicarYPersistir(nuevoEstado, _TipoMovimiento.saltarTurno, const {}, usuarioId, avanzarTurno: true);
  }

  /// Aplica el nuevo estado en memoria, lo persiste junto con el
  /// movimiento que lo produjo y, si corresponde, pasa el turno al
  /// siguiente participante — todo en una sola transaccion, para que el
  /// tablero y el turno nunca queden desincronizados entre sí ni con lo
  /// que ve el cliente tras un reinicio del servidor.
  void _aplicarYPersistir(
    JuegoEstado nuevoEstado,
    String tipoMovimiento,
    Map<String, dynamic> payload,
    String usuarioId, {
    bool avanzarTurno = false,
  }) {
    final siguienteTurno = avanzarTurno ? _siguienteTurno() : _turnoUsuarioId;

    _db.execute('BEGIN');
    try {
      _db.execute(
        'INSERT INTO movimientos_partida (id, partida_id, turno, tipo, payload, usuario_id) VALUES (?, ?, ?, ?, ?, ?)',
        [_uuid.v4(), partidaId, nuevoEstado.turnoActual, tipoMovimiento, jsonEncode(payload), usuarioId],
      );
      if (avanzarTurno) {
        _db.execute('UPDATE partidas SET turno_usuario_id = ? WHERE id = ?', [siguienteTurno, partidaId]);
      }
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }

    _estado = nuevoEstado;
    _turnoUsuarioId = siguienteTurno;
    _difundirEstado();
  }

  String _siguienteTurno() {
    final indiceActual = _participantes.indexWhere((p) => p.usuarioId == _turnoUsuarioId);
    final siguiente = _participantes[(indiceActual + 1) % _participantes.length];
    return siguiente.usuarioId;
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
      'tablero': _estado.tablero,
      'dados': _estado.dados,
      'numeroAnclaElegido': _estado.numeroAnclaElegido,
      'ancla': _estado.ancla == null ? null : {'fila': _estado.ancla!.fila, 'columna': _estado.ancla!.columna},
      'puntaje': _estado.puntaje,
      'nivelId': _estado.nivelId,
      'turnoUsuarioId': _turnoUsuarioId,
      'participantes': _participantes.map((p) => p.toJson()).toList(),
      'eventosPuntuacion': [
        for (final evento in _estado.eventosPuntuacion)
          {
            'turno': evento.turno,
            'jugadorId': evento.jugadorId,
            'colorZona': evento.colorZona.name,
            'zonaId': evento.zonaId,
            'nombreZona': evento.nombreZona,
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
  SalasDePartida(this._db);

  final Database _db;
  final Map<String, SalaDePartida> _salas = {};

  SalaDePartida obtener(String partidaId) {
    return _salas.putIfAbsent(partidaId, () => SalaDePartida.cargar(_db, partidaId));
  }
}
