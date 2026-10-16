import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'forecast_card.dart' show K;

final _bt = 'https://raw.githubusercontent.com/barroapk/kounadia-data/archive/backtest.json';
final _st = 'https://raw.githubusercontent.com/barroapk/kounadia-data/vip/vip_stats.json';

String _n(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

/// Carte « Fiabilité mesurée » : résultats du backtest + résultats réels.
class VipReliability extends StatefulWidget {
  VipReliability({super.key});

  @override
  State<VipReliability> createState() => _VipReliabilityState();
}

class _VipReliabilityState extends State<VipReliability> {
  late Future<(Map<String, dynamic>?, Map<String, dynamic>?)> _f = _load();
  bool _open = false;

  static Future<Map<String, dynamic>?> _get(String url, String key) async {
    final p = await SharedPreferences.getInstance();
    try {
      final v = DateTime.now().millisecondsSinceEpoch ~/ 3600000;
      final r = await http.get(Uri.parse('$url?v=$v')).timeout(Duration(seconds: 15));
      if (r.statusCode == 200) {
        final b = utf8.decode(r.bodyBytes);
        await p.setString(key, b);
        return Map<String, dynamic>.from(jsonDecode(b) as Map);
      }
    } catch (_) {}
    final c = p.getString(key);
    if (c == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(c) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<(Map<String, dynamic>?, Map<String, dynamic>?)> _load() async =>
      (await _get(_bt, 'krel_bt'), await _get(_st, 'krel_st'));

  Widget _line(String label, String value, {Color? color}) => Padding(
        padding: EdgeInsets.only(top: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: K.muted, fontSize: 12.5))),
          Text(value, style: TextStyle(color: color ?? K.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Map<String, dynamic>?, Map<String, dynamic>?)>(
      future: _f,
      builder: (context, snap) {
        final bt = snap.data?.$1;
        final st = snap.data?.$2;
        if (bt == null) return SizedBox.shrink();
        final e = (bt['evaluationFinale'] as Map?) ?? {};
        final p1 = ((e['paris1x2'] as Map?)?['c70'] as Map?) ?? {};
        final pb = ((e['parisButs'] as Map?)?['c70'] as Map?) ?? {};
        final n1 = (p1['n'] as num?) ?? 0;
        final nb = (pb['n'] as num?) ?? 0;
        final h1 = (p1['hit'] as num?) ?? 0;
        final hb = (pb['hit'] as num?) ?? 0;
        final n = n1 + nb;
        final hit = n == 0 ? 0 : (h1 * n1 + hb * nb) / n;
        final jours = ((bt['periodes'] as Map?)?['joursEvaluation'] as num?) ?? 40;
        final coupons = ((e['coupons'] as List?) ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
        final vipReal = (st?['vip'] as Map?) ?? {};
        final legs = (vipReal['legs'] as num?) ?? 0;
        final legsWon = (vipReal['legsWon'] as num?) ?? 0;
        final cps = (vipReal['coupons'] as num?) ?? 0;
        final cpsWon = (vipReal['couponsWon'] as num?) ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: K.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: K.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: K.green.withAlpha(40), borderRadius: BorderRadius.circular(11)),
                    child: Icon(Icons.verified_rounded, color: K.green, size: 22),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Fiabilité mesurée', style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text(
                        n == 0
                            ? 'Mesure en cours…'
                            : 'Paris VIP à 70 % et plus : ${hit.toStringAsFixed(0)} % gagnés sur ${_n(n)} paris testés',
                        style: TextStyle(color: K.muted, fontSize: 12.5, height: 1.3),
                      ),
                    ]),
                  ),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.muted),
                ]),
              ),
            ),
            if (_open)
              Padding(
                padding: EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 1, color: K.border),
                  SizedBox(height: 8),
                  Text('Test sur $jours jours de matchs passés, jamais vus par le modèle',
                      style: TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  for (final c in coupons)
                    _line('${c['coupon']}',
                        (c['jours'] as num? ?? 0) == 0 ? '—' : '${c['gagnes']}/${c['jours']} gagnés (${c['reussite']} %)'),
                  if (legs > 0) ...[
                    SizedBox(height: 10),
                    Text('En réel depuis le lancement',
                        style: TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    _line('Matchs VIP', '${_n(legsWon)}/${_n(legs)} gagnés', color: K.green),
                    _line('Coupons VIP', '${_n(cpsWon)}/${_n(cps)} gagnés', color: K.green),
                  ],
                  SizedBox(height: 10),
                  Text('Résultats passés : aucune garantie de gain. Pariez prudemment. 18+',
                      style: TextStyle(color: K.amber, fontSize: 11.5, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
