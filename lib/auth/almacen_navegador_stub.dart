// Versión para las plataformas que no son web (ver el import condicional en
// `token_storage.dart`): ahí el almacenamiento seguro siempre está
// disponible, así que nada de esto llega a usarse.

/// Siempre false fuera de un navegador.
bool get navegadorSinContextoSeguro => false;

String? leerDelNavegador(String clave) => throw UnsupportedError('Solo disponible en web.');

void guardarEnNavegador(String clave, String valor) => throw UnsupportedError('Solo disponible en web.');

void borrarDelNavegador(String clave) => throw UnsupportedError('Solo disponible en web.');
