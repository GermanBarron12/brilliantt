import 'package:brilliant_core/brilliant_core.dart';
import 'package:flutter/material.dart';

import '../tablero_layout.dart' show coloresDeZona;
import 'estado_partida_en_vivo.dart';

/// Cómo quedó uno de los tres valores de una zona para el jugador cuya
/// hoja se está mirando.
enum EstadoEscalon {
  /// Todavía se puede obtener.
  disponible,

  /// Lo obtuvo el jugador de esta hoja (se muestra rodeado).
  propio,

  /// Ya se lo llevó otro jugador y no queda para nadie más (se muestra
  /// tachado). Nunca aplica al valor más bajo, que no se agota.
  deOtro,
}

/// Los tres valores de [zona] (primero, segundo y resto en completarla) y
/// cómo quedó cada uno para [jugadorId], según el historial de la partida.
List<EstadoEscalon> estadosDeEscalones({
  required ZonaTablero zona,
  required List<EventoPuntuacionRemoto> eventos,
  required String jugadorId,
}) {
  final zonaId = idDeZona(zona);
  final deLaZona = eventos.where((e) => e.zonaId == zonaId);
  return [
    for (var escalon = 0; escalon < 3; escalon++)
      if (deLaZona.any((e) => e.escalon == escalon && e.jugadorId == jugadorId))
        EstadoEscalon.propio
      else if (escalon < 2 && deLaZona.any((e) => e.escalon == escalon))
        EstadoEscalon.deOtro
      else
        EstadoEscalon.disponible,
  ];
}

/// El símbolo de la regla de una zona, como en la hoja del juego de mesa.
String simboloDeRegla(Tipo tipo) {
  if (tipo is TipoAzul || tipo is TipoBlanco) return '=';
  if (tipo is TipoRojo || tipo is TipoAmarillo) return '≠';
  if (tipo is TipoVerde) return '?';
  if (tipo is TipoMorado) return 'XO';
  if (tipo is TipoNaranjaSuperior) return '4-6';
  if (tipo is TipoNaranjaInferior) return '1-3';
  throw UnsupportedError('Tipo sin símbolo definido: ${tipo.runtimeType}');
}

/// La hoja de puntos de un jugador: una ficha por zona del tablero con los
/// tres valores que reparte esa zona (el más alto para quien la completa
/// primero). Rodeado, el valor que obtuvo [jugadorId]; tachado, el que ya
/// se llevó otro.
///
/// [zonas] ya viene en el orden en que se quieren mostrar. Con [vertical]
/// se apilan en una columna (para los costados del tablero); si no, van en
/// una sola fila con desplazamiento horizontal (para pantallas angostas).
class TablaPuntosZonas extends StatelessWidget {
  const TablaPuntosZonas({
    super.key,
    required this.zonas,
    required this.nivel,
    required this.eventos,
    required this.jugadorId,
    required this.vertical,
  });

  final List<ZonaTablero> zonas;
  final ConfiguracionNivel nivel;
  final List<EventoPuntuacionRemoto> eventos;
  final String jugadorId;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final fichas = [
      for (final zona in zonas)
        Padding(
          padding: const EdgeInsets.all(3),
          child: _FichaZona(
            zona: zona,
            nombre: nivel.nombresDeZona[idDeZona(zona)]!,
            puntos: puntuacionMultijugadorRequerida(nivel.id, zona.color),
            estados: estadosDeEscalones(zona: zona, eventos: eventos, jugadorId: jugadorId),
          ),
        ),
    ];
    return SingleChildScrollView(
      scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
      child: vertical
          ? Column(mainAxisSize: MainAxisSize.min, children: fichas)
          : Row(mainAxisSize: MainAxisSize.min, children: fichas),
    );
  }
}

/// Reparte las zonas de [nivel] entre el costado izquierdo y el derecho del
/// tablero según de qué lado caen sus casillas, cada lado ordenado de
/// arriba hacia abajo: así cada ficha queda cerca de su zona, como en la
/// hoja del juego de mesa.
({List<ZonaTablero> izquierda, List<ZonaTablero> derecha}) zonasPorCostado(ConfiguracionNivel nivel) {
  double promedio(ZonaTablero zona, int Function(PosicionCasilla) de) {
    return zona.casillas.map(de).reduce((a, b) => a + b) / zona.casillas.length;
  }

  final ordenadas = [...nivel.zonas]..sort((a, b) => promedio(a, (c) => c.fila).compareTo(promedio(b, (c) => c.fila)));
  final centro = (nivel.columnas - 1) / 2;
  final izquierda = <ZonaTablero>[];
  final derecha = <ZonaTablero>[];
  for (final zona in ordenadas) {
    final columna = promedio(zona, (c) => c.columna);
    final vaALaIzquierda = columna == centro ? izquierda.length < derecha.length : columna < centro;
    (vaALaIzquierda ? izquierda : derecha).add(zona);
  }
  return (izquierda: izquierda, derecha: derecha);
}

class _FichaZona extends StatelessWidget {
  const _FichaZona({required this.zona, required this.nombre, required this.puntos, required this.estados});

  final ZonaTablero zona;
  final String nombre;
  final List<int> puntos;
  final List<EstadoEscalon> estados;

  String _descripcionDe(int indice) {
    switch (estados[indice]) {
      case EstadoEscalon.propio:
        return '${puntos[indice]} (obtenido)';
      case EstadoEscalon.deOtro:
        return '${puntos[indice]} (ya lo obtuvo otro jugador)';
      case EstadoEscalon.disponible:
        return '${puntos[indice]}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = coloresDeZona[zona.color]!;
    final colorSimbolo =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black87;

    return Tooltip(
      message: '$nombre · ${zona.tipo.descripcion}',
      child: Semantics(
        label: '$nombre. Puntos: ${[for (var i = 0; i < 3; i++) _descripcionDe(i)].join(', ')}',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  simboloDeRegla(zona.tipo),
                  style: TextStyle(color: colorSimbolo, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(width: 4),
              for (var i = 0; i < 3; i++) _Escalon(puntos: puntos[i], estado: estados[i]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Escalon extends StatelessWidget {
  const _Escalon({required this.puntos, required this.estado});

  final int puntos;
  final EstadoEscalon estado;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final propio = estado == EstadoEscalon.propio;
    final deOtro = estado == EstadoEscalon.deOtro;

    return Container(
      width: 24,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: propio ? colorScheme.primaryContainer : null,
        border: propio ? Border.all(color: colorScheme.primary, width: 2) : null,
      ),
      child: Text(
        '$puntos',
        style: TextStyle(
          fontSize: 14,
          fontWeight: propio ? FontWeight.bold : FontWeight.w500,
          color: propio
              ? colorScheme.onPrimaryContainer
              : deOtro
                  ? colorScheme.onSurfaceVariant
                  : colorScheme.onSurface,
          decoration: deOtro ? TextDecoration.lineThrough : null,
          decorationThickness: 2,
        ),
      ),
    );
  }
}
