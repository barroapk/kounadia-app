import 'dart:convert';
import 'platform/gz.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';
import 'live_socket.dart' show kLiveBase;

/// Données KOUNADIA publiées chiffrées (gzip + AES-256-GCM).
/// La clé est injectée à la compilation (secret GitHub), jamais écrite dans le code.
class KFeed {
  static const _base = 'https://raw.githubusercontent.com/barroapk/kfeed';
  static const _k = String.fromEnvironment('KD_KEY');
  static Uint8List? _key;

  /// Connexion gardée ouverte entre deux chargements : plus rapide.
  static final _client = http.Client();

  static Future<http.Response> get(String path) async {
    var r = await _client.get(Uri.parse('$_base/$path')).timeout(Duration(seconds: 25));
    if (r.statusCode != 200 && kLiveBase.isNotEmpty) {
      // GitHub refuse (trop d'utilisateurs sur le même réseau) : relais KOUNADIA.
      try {
        final f = await _client.get(Uri.parse('$kLiveBase/feed/$path')).timeout(Duration(seconds: 15));
        if (f.statusCode == 200) r = f;
      } catch (_) {}
    }
    if (r.statusCode != 200) return r;
    final plain = open(utf8.decode(r.bodyBytes));
    return http.Response.bytes(utf8.encode(plain), 200, headers: r.headers);
  }

  static String open(String text) {
    final t = text.trim();
    if (!t.startsWith('KD1.')) return t;
    final key = _key ??= base64.decode(_k);
    final b = base64.decode(t.substring(4));
    final c = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, b.sublist(0, 12), Uint8List(0)));
    final z = c.process(Uint8List.fromList(b.sublist(12)));
    return utf8.decode(gunzip(z));
  }
}
