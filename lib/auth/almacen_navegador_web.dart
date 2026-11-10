// Versión web (ver el import condicional en `token_storage.dart`): acceso
// directo al `localStorage` del navegador, sin cifrar.
import 'dart:js_interop';

@JS('window.isSecureContext')
external bool get _contextoSeguro;

@JS('window.localStorage.getItem')
external String? _getItem(String clave);

@JS('window.localStorage.setItem')
external void _setItem(String clave, String valor);

@JS('window.localStorage.removeItem')
external void _removeItem(String clave);

/// true si la página se abrió por `http` desde una dirección que no es
/// `localhost` (por ejemplo, la IP de otra máquina de la red local). En ese
/// caso el navegador no expone la API de cifrado que necesita el
/// almacenamiento seguro.
bool get navegadorSinContextoSeguro => !_contextoSeguro;

String? leerDelNavegador(String clave) => _getItem(clave);

void guardarEnNavegador(String clave, String valor) => _setItem(clave, valor);

void borrarDelNavegador(String clave) => _removeItem(clave);
