import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'live_socket.dart' show kLiveBase;

/// Numéro WhatsApp de KOUNADIA SERVICE : réglé dans KOUNADIA Admin, lu au démarrage (robot KOUNADIA).
class Contact {
  static String wa = '22652571201';

  /// Ex. « +226 52 57 12 01 ».
  static String get pretty {
    final d = wa;
    if (d.startsWith('226') && d.length == 11) {
      return '+226 ${d.substring(3, 5)} ${d.substring(5, 7)} ${d.substring(7, 9)} ${d.substring(9, 11)}';
    }
    return '+$d';
  }

  static Future<void> load() async {
    if (kLiveBase.isEmpty) return;
    try {
      final r = await http.get(Uri.parse('$kLiveBase/contact')).timeout(Duration(seconds: 8));
      if (r.statusCode != 200) return;
      final v = ((jsonDecode(r.body) as Map)['wa'] ?? '').toString();
      if (RegExp(r'^\d{8,15}$').hasMatch(v)) wa = v;
    } catch (_) {}
  }
}
