import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

/// Données KOUNADIA publiées chiffrées (gzip + AES-256-GCM).
/// La clé est injectée à la compilation (secret GitHub), jamais écrite dans le code.
class KFeed {
  static const _base = 'https://raw.githubusercontent.com/barroapk/kfeed';
  static const _k = String.fromEnvironment('KD_KEY');
  static Uint8List? _key;

  static Future<http.Response> get(String path) async {
    final r = await http.get(Uri.parse('$_base/$path')).timeout(Duration(seconds: 25));
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
    return utf8.decode(gzip.decode(z));
  }
}
