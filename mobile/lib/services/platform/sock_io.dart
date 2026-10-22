import 'dart:io';

/// Connexion au direct du robot (Android).
class Sock {
  final WebSocket _ws;
  Sock._(this._ws);

  static Future<Sock> connect(String url) async =>
      Sock._(await WebSocket.connect(url).timeout(const Duration(seconds: 10)));

  void send(String s) => _ws.add(s);
  void close() => _ws.close();
  void listen(void Function(dynamic) onData, {required void Function() onDone}) =>
      _ws.listen(onData, onDone: onDone, onError: (_) => onDone(), cancelOnError: true);
}
