import 'dart:async';
import 'dart:convert';
import 'dart:io';

class Client {
  final WebSocket socket;
  String name;
  String room;

  Client({required this.socket, this.name = 'Anon', this.room = 'general'});
}

void main() async {
  // Render asigna el puerto mediante la variable de entorno PORT
  final port = int.tryParse(Platform.environment['PORT'] ?? '3003') ?? 3003;

  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  print('🌐 Servidor WebSocket escuchando en el puerto $port');

  final clients = <Client>[];

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      final client = Client(socket: socket);
      clients.add(client);
      print('✅ Cliente conectado: ${socket.hashCode}');

      // Mensaje de bienvenida
      socket.add(jsonEncode({
        'event': 'msg',
        'data': 'Bienvenido al Chat, establece tu nombre con "set_name" y sala con "join_room"'
      }));

      socket.listen((rawMessage) {
        try {
          final msg = jsonDecode(rawMessage);
          final event = msg['event'];
          final data = msg['data'];

          switch (event) {
            case 'set_name':
              client.name = data.toString().trim().isEmpty ? 'Anon' : data;
              socket.add(jsonEncode({
                'event': 'system',
                'data': 'Tu nombre ahora es ${client.name}'
              }));
              print('👤 Cliente ${socket.hashCode} se llama ${client.name}');
              break;

            case 'join_room':
              client.room = data.toString().trim().isEmpty ? 'general' : data;
              socket.add(jsonEncode({
                'event': 'system',
                'data': 'Te uniste a la sala ${client.room}'
              }));
              print('🚪 ${client.name} se unió a la sala ${client.room}');
              break;

            case 'stream':
              final message = data.toString().trim();
              if (message.isEmpty) return;

              // Broadcast solo a clientes en la misma sala
              for (var c in clients) {
                if (c != client &&
                    c.socket.readyState == WebSocket.open &&
                    c.room == client.room) {
                  c.socket.add(jsonEncode({
                    'event': 'stream',
                    'data': {'user': client.name, 'msg': message}
                  }));
                }
              }

              print('📡 [${client.room}] ${client.name}: $message');
              break;

            default:
              socket.add(jsonEncode({
                'event': 'system',
                'data': 'Evento desconocido: $event'
              }));
          }
        } catch (e) {
          print('⚠️ Mensaje inválido: $rawMessage');
          socket.add(jsonEncode({'event': 'system', 'data': 'Mensaje inválido'}));
        }
      }, onDone: () {
        clients.remove(client);
        print('❌ Cliente desconectado: ${socket.hashCode}');
      }, onError: (err) {
        clients.remove(client);
        print('⚠️ Error en conexión: $err');
      });
    } else {
      // Rechazar solicitudes no WebSocket
      request.response
        ..statusCode = HttpStatus.forbidden
        ..write('WebSocket connections only')
        ..close();
    }
  }
}
