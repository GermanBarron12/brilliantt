import 'package:brilliant_server/app.dart';
import 'package:brilliant_server/config.dart';
import 'package:brilliant_server/db/connection.dart';
import 'package:shelf/shelf.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Database db;

  setUp(() => db = abrirBaseDeDatos(':memory:'));
  tearDown(() => db.dispose());

  Future<Response> pedir(String? corsOrigin, {String metodo = 'GET', String? origen}) async {
    final config = Config.desdeEntorno({if (corsOrigin != null) 'CORS_ORIGIN': corsOrigin});
    final app = crearApp(db, config);
    return app(
      Request(metodo, Uri.parse('http://servidor/no-existe'), headers: {if (origen != null) 'origin': origen}),
    );
  }

  group('Config: CORS_ORIGIN', () {
    test('sin definir, no hay ningun origen permitido', () {
      expect(Config.desdeEntorno({}).corsOrigins, isEmpty);
    });

    test('acepta varios origenes separados por coma, ignorando espacios y vacios', () {
      final config = Config.desdeEntorno({'CORS_ORIGIN': 'http://localhost:8765, http://10.0.0.5:8765,,'});
      expect(config.corsOrigins, ['http://localhost:8765', 'http://10.0.0.5:8765']);
    });
  });

  group('CORS', () {
    const dosOrigenes = 'http://localhost:8765,http://10.0.0.5:8765';

    test('autoriza a cada origen permitido devolviendole su propio origen', () async {
      for (final origen in ['http://localhost:8765', 'http://10.0.0.5:8765']) {
        final respuesta = await pedir(dosOrigenes, origen: origen);
        expect(respuesta.headers['access-control-allow-origin'], origen);
        expect(respuesta.headers['vary'], 'Origin');
      }
    });

    test('las respuestas de error de una ruta tambien llevan la autorizacion', () async {
      final config = Config.desdeEntorno({'CORS_ORIGIN': dosOrigenes});
      final respuesta = await crearApp(db, config)(
        // Sin sesion: la ruta responde 401 lanzando un error.
        Request('GET', Uri.parse('http://servidor/partidas/ABC123'), headers: {'origin': 'http://10.0.0.5:8765'}),
      );

      expect(respuesta.statusCode, 401);
      expect(respuesta.headers['access-control-allow-origin'], 'http://10.0.0.5:8765');
    });

    test('no autoriza a un origen que no esta en la lista', () async {
      final respuesta = await pedir(dosOrigenes, origen: 'http://otro-sitio.example');
      expect(respuesta.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test('una solicitud sin origen (un cliente nativo) pasa sin cabeceras de CORS', () async {
      final respuesta = await pedir(dosOrigenes);
      expect(respuesta.statusCode, 404);
      expect(respuesta.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test('la consulta previa (OPTIONS) de un origen permitido responde 204 con los metodos', () async {
      final respuesta = await pedir(dosOrigenes, metodo: 'OPTIONS', origen: 'http://10.0.0.5:8765');
      expect(respuesta.statusCode, 204);
      expect(respuesta.headers['access-control-allow-origin'], 'http://10.0.0.5:8765');
      expect(respuesta.headers['access-control-allow-methods'], contains('POST'));
    });

    test('la consulta previa de un origen no permitido no recibe autorizacion', () async {
      final respuesta = await pedir(dosOrigenes, metodo: 'OPTIONS', origen: 'http://otro-sitio.example');
      expect(respuesta.headers.containsKey('access-control-allow-origin'), isFalse);
    });

    test('sin CORS_ORIGIN no se autoriza a nadie', () async {
      final respuesta = await pedir(null, origen: 'http://localhost:8765');
      expect(respuesta.headers.containsKey('access-control-allow-origin'), isFalse);
    });
  });
}
