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
  static DateTime? _dataAt;

  /// Le robot envoie vraiment du direct (changement reçu il y a moins de 90 s).
  /// Sinon l'app lit elle-même le direct du site : jamais de minutes figées.
  static bool get fresh {
    final t = _dataAt;
    return connected && t != null && DateTime.now().difference(t) < const Duration(seconds: 90);
  }

  static final Map<int, DateTime> _stAt = {};
  static final Map<int, String> _stVal = {}, _stLast = {};

  /// Minute affichée d'un match en cours : celle du robot, avancée d'elle-même entre deux mises à jour
  /// (le site source ne publie pas toujours chaque minute). Après 45' ou 90', on passe au temps
  /// additionnel (45+2', 90+4') tant que la source n'annonce pas la mi-temps ou la fin.
  static String? minuteOf(int id, String st) {
    final m = RegExp(r"^(\d+)\s*'?\s*(?:\+\s*(\d+))?").firstMatch(st.trim());
    if (m == null) return null;
    final base = int.parse(m[1]!);
    final plus = int.tryParse(m[2] ?? '') ?? 0;
    // Minute qui change, quelle que soit la source (robot ou lecture directe du site) : on repart de maintenant.
    if (_stVal[id] != st) {
      _stVal[id] = st;
      if (!_stAt.containsKey(id) || _stLast[id] != st) _stAt[id] = DateTime.now();
      _stLast[id] = st;
    }
    final at = _stAt[id];
    final e = at == null ? 0 : DateTime.now().difference(at).inMinutes;
    final cap = base <= 45 ? 45 : base <= 90 ? 90 : base <= 105 ? 105 : 120;
    final total = base + plus + e;
    if (total <= cap) return "$total'";
    return "$cap+${(total - cap).clamp(1, 15)}'";
  }

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
      _ping = Timer.periodic(const Duration(seconds: 25), (_) {
        // Connexion ouverte mais plus aucun direct depuis 3 min : on se reconnecte.
        final t = _dataAt;
        if (t != null && last.isNotEmpty && DateTime.now().difference(t) > const Duration(minutes: 3)) {
          _dataAt = null;
          _ws?.close();
          return;
        }
        _ws?.send('ping');
      });
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
    final wait = Duration(milliseconds: (_fails * 2000).clamp(1500, 10000) + Random().nextInt(1500));
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
      _dataAt = DateTime.now(); // la photo complète à la connexion compte aussi : direct à jour tout de suite
      final now = DateTime.now();
      out.forEach((id, v) {
        final old = last[id];
        if (old == null || old.$3 != v.$3) _stAt[id] = now; // la minute vient de changer
      });
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
