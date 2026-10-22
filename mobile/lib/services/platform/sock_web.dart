import 'package:web_socket_channel/web_socket_channel.dart';

/// Connexion au direct du robot (navigateur : iPhone, ordinateur).
class Sock {
  final WebSocketChannel _ch;
  Sock._(this._ch);

  static Future<Sock> connect(String url) async {
    final ch = WebSocketChannel.connect(Uri.parse(url));
    await ch.ready.timeout(const Duration(seconds: 10));
    return Sock._(ch);
  }

  void send(String s) => _ch.sink.add(s);
  void close() => _ch.sink.close();
  void listen(void Function(dynamic) onData, {required void Function() onDone}) =>
      _ch.stream.listen(onData, onDone: onDone, onError: (_) => onDone(), cancelOnError: true);
}
