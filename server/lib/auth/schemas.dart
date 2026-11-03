import 'errors.dart';

/// Regex de nombre de usuario: letras, numeros, guion bajo y punto, 3 a 32
/// caracteres (sin exigir formato de email), igual que el esquema Zod
/// original.
final RegExp _nombreUsuarioRegex = RegExp(r'^[a-z0-9_.]+$');

/// Normaliza (trim + lowercase) y valida el nombre de usuario. Lanza
/// [EntradaInvalidaError] si no cumple el formato.
String _validarNombreUsuario(dynamic valor) {
  if (valor is! String) {
    throw EntradaInvalidaError('El nombre de usuario es obligatorio');
  }
  final nombreUsuario = valor.trim().toLowerCase();
  if (nombreUsuario.length < 3) {
    throw EntradaInvalidaError('El nombre de usuario debe tener al menos 3 caracteres');
  }
  if (nombreUsuario.length > 32) {
    throw EntradaInvalidaError('El nombre de usuario no puede tener mas de 32 caracteres');
  }
  if (!_nombreUsuarioRegex.hasMatch(nombreUsuario)) {
    throw EntradaInvalidaError('El nombre de usuario solo puede tener letras, numeros, "_" y "."');
  }
  return nombreUsuario;
}

/// Longitud minima de 8 caracteres: el piso recomendado por NIST SP 800-63B
/// para contrasenas de usuario cuando se aplica un hashing lento como
/// Argon2id (no hace falta exigir mayusculas/numeros/simbolos: eso empuja a
/// patrones predecibles sin aumentar la entropia real).
String _validarPassword(dynamic valor) {
  if (valor is! String) {
    throw EntradaInvalidaError('La contrasena es obligatoria');
  }
  if (valor.length < 8) {
    throw EntradaInvalidaError('La contrasena debe tener al menos 8 caracteres');
  }
  if (valor.length > 256) {
    throw EntradaInvalidaError('La contrasena no puede tener mas de 256 caracteres');
  }
  return valor;
}

class RegistroInput {
  const RegistroInput(this.nombreUsuario, this.password);
  final String nombreUsuario;
  final String password;
}

RegistroInput validarRegistro(Map<String, dynamic> body) {
  return RegistroInput(_validarNombreUsuario(body['nombreUsuario']), _validarPassword(body['password']));
}

class LoginInput {
  const LoginInput(this.nombreUsuario, this.password);
  final String nombreUsuario;
  final String password;
}

LoginInput validarLogin(Map<String, dynamic> body) {
  return LoginInput(_validarNombreUsuario(body['nombreUsuario']), _validarPassword(body['password']));
}

class EliminarCuentaInput {
  const EliminarCuentaInput(this.password);
  final String password;
}

EliminarCuentaInput validarEliminarCuenta(Map<String, dynamic> body) {
  return EliminarCuentaInput(_validarPassword(body['password']));
}
