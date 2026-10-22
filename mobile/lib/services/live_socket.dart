import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'platform/sock.dart';
import 'dart:math';
import 'package:http/http.dart' as http;

/// Adresse du robot KOUNADIA (injectée à la compilation par GitHub Actions).
const kLiveBase = String.fromEnvironment('LIVE_URL');

/// Dans le navigateur (iPhone), PrimaTips refuse les appels directs : on passe par le robot.
String ptUrl(String u) => kIsWeb && kLiveBase.isNotEmpty
    ? u.replaceFirst(RegExp(r'^https://(www\.)?primatips\.com'), '$kLiveBase/pt')
    : u;

/// Événement de match (but, coup d'envoi, mi-temps, fin) détecté par le robot.
class MatchEvent {
  final int id;
  final String type; // goal, ko, ht, ft
  final int? hs, as_;
  final String st;
  final String side; // h / a (buts)
  final DateTime at;
  MatchEvent(this.id, this.type, this.hs, this.as_, this.st, this.side, this.at);

  factory MatchEvent.fromJson(Map<String, dynamic> j) => MatchEvent(
        (j['id'] as num).toInt(),
        (j['t'] ?? '').toString(),
        (j['hs'] as num?)?.toInt(),
        (j['as'] as num?)?.toInt(),
        (j['st'] ?? '').toString(),
        (j['side'] ?? '').toString(),
        DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
      );
}

/// Direct en temps réel : le robot pousse chaque changement de score dès qu'il le voit
/// (environ toutes les 3 s), sans que le téléphone ait à interroger le site.
class LiveSocket {
  static final updates = StreamController<Map<int, (int?, int?, String)>>.broadcast();
  static final events = StreamController<List<MatchEvent>>.broadcast();
  static bool get available => kLiveBase.isNotEmpty;

  /// Dernier état connu de chaque match en direct (réappliqué après chaque rechargement).
  static final Map<int, (int?, int?, String)> last = {};
  static bool connected = false;

  static Sock? _ws;
  static Timer? _ping, _retry;
  static bool _want = false;
  static int _fails = 0;

  static void start() {
    if (!available || _want) return;
    _want = true;
    _connect();
  }

  static void stop() {
    _want = false;
    _retry?.cancel();
    _ping?.cancel();
    _ws?.close();
    _ws = null;
    connected = false;
  }

  static Future<void> _connect() async {
    if (!_want || _ws != null) return;
    try {
      final ws = await Sock.connect('${kLiveBase.replaceFirst('https://', 'wss://')}/live');
      if (!_want) {
        ws.close();
        return;
      }
      _ws = ws;
      connected = true;
      _fails = 0;
      _ping = Timer.periodic(const Duration(seconds: 25), (_) => _ws?.send('ping'));
      ws.listen(_onData, onDone: _lost);
    } catch (_) {
      _lost();
    }
  }

  static void _lost() {
    _ping?.cancel();
    _ws = null;
    connected = false;
    if (!_want) return;
    _fails++;
    // Petit délai au hasard : si le robot redémarre, tous les téléphones ne reviennent pas à la même seconde.
    final wait = Duration(milliseconds: (_fails * 3000).clamp(3000, 30000) + Random().nextInt(2000));
    _retry?.cancel();
    _retry = Timer(wait, _connect);
  }

  static void _onData(dynamic data) {
    if (data is! String || data == 'pong') return;
    try {
      final j = jsonDecode(data) as Map<String, dynamic>;
      final live = (j['live'] as Map?) ?? const {};
      final out = <int, (int?, int?, String)>{};
      live.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id == null || v is! List || v.length < 3) return;
        out[id] = ((v[0] as num?)?.toInt(), (v[1] as num?)?.toInt(), '${v[2]}'.trim());
      });
      if (j['k'] == 'snap') last.clear();
      last.addAll(out);
      if (out.isNotEmpty) updates.add(out);
      final ev = ((j['ev'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => MatchEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (ev.isNotEmpty) events.add(ev);
    } catch (_) {}
  }

  /// Historique des événements (36 dernières heures) pour ces matchs, du plus récent au plus ancien.
  static Future<List<MatchEvent>> log(Iterable<int> ids) async {
    if (!available || ids.isEmpty) return [];
    final r = await http
        .get(Uri.parse('$kLiveBase/log?ids=${ids.take(300).join(',')}'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return [];
    final l = (jsonDecode(utf8.decode(r.bodyBytes)) as List)
        .whereType<Map>()
        .map((e) => MatchEvent.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    return l;
  }
}
