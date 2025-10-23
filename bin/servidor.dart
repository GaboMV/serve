import 'dart:async';
import 'dart:convert';
import 'dart:io';

void main() async {
  // Render asigna el puerto mediante la variable de entorno PORT
  final port = int.tryParse(Platform.environment['PORT'] ?? '3003') ?? 3003;

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('🌐 Servidor WebSocket escuchando en el puerto $port');

  final clients = <WebSocket>[];

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      clients.add(socket);
      print('✅ Cliente conectado: ${socket.hashCode}');

      // Enviar mensaje de bienvenida después de 3 segundos
      Timer(Duration(seconds: 3), () {
        if (socket.readyState == WebSocket.open) {
          socket.add(jsonEncode({'event': 'msg', 'data': 'Bienvenido al Chat'}));
        }
      });

      socket.listen((rawMessage) {
        try {
          final msg = jsonDecode(rawMessage);
          final event = msg['event'];
          final data = msg['data'];

          if (event == 'stream') {
            print('📡 Mensaje recibido: $data de ${socket.hashCode}');
            // Broadcast a todos los demás clientes
            for (var c in clients) {
              if (c != socket && c.readyState == WebSocket.open) {
                c.add(jsonEncode({'event': 'stream', 'data': data}));
              }
            }
          }
        } catch (e) {
          print('⚠️ Mensaje no válido: $rawMessage');
        }
      }, onDone: () {
        clients.remove(socket);
        print('❌ Cliente desconectado: ${socket.hashCode}');
      }, onError: (err) {
        clients.remove(socket);
        print('⚠️ Error en conexión: $err');
      });
    } else {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('WebSocket connections only')
        ..close();
    }
  }
}
