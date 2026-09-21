import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../core/config/app_config.dart';

/// Wraps the backend's Socket.io real-time layer (chat + live notifications).
/// One socket per app process, authenticated the same way as REST: a JWT
/// passed in the `auth` handshake payload.
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;

  // Handlers outlive any one socket: login bootstraps (and registers
  // listeners) before connect() runs, and every re-login builds a new socket.
  final Map<String, List<void Function(dynamic data)>> _handlers = {};

  void connect(String token) {
    _socket?.dispose();
    final socket = io.io(
      AppConfig.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableForceNew()
          .disableAutoConnect()
          .build(),
    );
    _handlers.forEach((event, handlers) {
      for (final handler in handlers) {
        socket.on(event, handler);
      }
    });
    _socket = socket..connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void joinCase(String caseId) => _socket?.emit('join_case', {'caseId': caseId});

  void emit(String event, dynamic data) => _socket?.emit(event, data);

  void sendMessage({required String caseId, String? text, String? fileUrl}) {
    _socket?.emit('send_message', {'caseId': caseId, 'text': text, 'fileUrl': fileUrl});
  }

  void on(String event, void Function(dynamic data) handler) {
    _handlers.putIfAbsent(event, () => []).add(handler);
    _socket?.on(event, handler);
  }

  void off(String event, [void Function(dynamic data)? handler]) {
    if (handler == null) {
      _handlers.remove(event);
    } else {
      _handlers[event]?.remove(handler);
    }
    _socket?.off(event, handler);
  }
}
