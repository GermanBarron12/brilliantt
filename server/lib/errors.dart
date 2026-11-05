/// Error base de la API: el handler central de `app.dart` lo traduce a una
/// respuesta HTTP (status + codigo + mensaje) sin exponer nunca detalles
/// internos (stack traces, mensajes de SQLite, etc.). Los errores de
/// dominio de cada modulo (auth, partidas) extienden esta clase, asi el
/// handler central les sirve a todos sin duplicar la logica de traduccion.
abstract class ApiError implements Exception {
  const ApiError(this.status, this.code, this.message);

  final int status;
  final String code;
  final String message;

  @override
  String toString() => '$runtimeType($code): $message';
}
