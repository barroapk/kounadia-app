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

String _p(num? v) => v == null ? '—' : '${v.toStringAsFixed(1).replaceAll('.', ',')} %';
String _d(String? iso) {
  final p = (iso ?? '').split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : '—';
}

/// Carte « Fiabilité mesurée » : backtest indépendant + résultats réels.
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

  Widget _title(String t) => Padding(
        padding: EdgeInsets.only(top: 12, bottom: 2),
        child: Text(t, style: TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
      );

  Widget _line(String label, String value, {Color? color, String? sub}) => Padding(
        padding: EdgeInsets.only(top: 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(label, style: TextStyle(color: K.muted, fontSize: 12.5))),
            SizedBox(width: 8),
            Text(value, style: TextStyle(color: color ?? K.text, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ]),
          if (sub != null) Text(sub, style: TextStyle(color: K.muted, fontSize: 11)),
        ]),
      );

  String? _ic(Map? m) {
    final ic = m?['ic'];
    if (ic is! List || ic.length != 2 || ic[0] == null) return null;
    return 'Marge d\'erreur : entre ${_p(ic[0] as num)} et ${_p(ic[1] as num)}';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Map<String, dynamic>?, Map<String, dynamic>?)>(
      future: _f,
      builder: (context, snap) {
        final bt = snap.data?.$1;
        final st = snap.data?.$2;
        if (bt == null) return SizedBox.shrink();
        final per = (bt['periodes'] as Map?) ?? {};
        final e = (bt['evaluationFinale'] as Map?) ?? {};
        final p1 = (e['paris1x2'] as Map?)?['c70'] as Map?;
        final pb = (e['parisButs'] as Map?)?['c70'] as Map?;
        final br = (e['brier1x2'] as Map?) ?? {};
        final coupons = ((e['coupons'] as List?) ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
        final real = (st?['vip'] as Map?) ?? {};
        final legs = (real['legs'] as num?) ?? 0;

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
                      Text('Paris à 70 % et plus — 1X2 : ${_p(p1?['hit'] as num?)} · Buts : ${_p(pb?['hit'] as num?)}',
                          style: TextStyle(color: K.muted, fontSize: 12.5, height: 1.3)),
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
                  Text('Test du ${_d(per['evalDu'] as String?)} au ${_d(per['evalAu'] as String?)} (${per['joursEvaluation'] ?? '—'} jours), sur des matchs jamais vus par le modèle',
                      style: TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
                  _title('Paris individuels (confiance 70 % et plus)'),
                  _line('1X2 et double chance', '${_p(p1?['hit'] as num?)} · ${_n((p1?['n'] as num?) ?? 0)} paris', sub: _ic(p1)),
                  _line('Plus/Moins de buts, les deux marquent', '${_p(pb?['hit'] as num?)} · ${_n((pb?['n'] as num?) ?? 0)} paris', sub: _ic(pb)),
                  _line('Précision 1X2 (Brier, plus bas = mieux)',
                      'KOUNADIA ${br['kounadiaFormule'] ?? '—'} · marché ${br['marche'] ?? '—'}'),
                  _title('Coupons sur la période de test'),
                  for (final c in coupons)
                    _line(
                      '${c['coupon']}${c['coupon'] == 'Grosses cotes' ? ' (suspendu)' : ''}',
                      (c['jours'] as num? ?? 0) == 0 ? '—' : '${c['gagnes']}/${c['jours']} gagnés (${_p(c['reussite'] as num?)})',
                      sub: (c['jours'] as num? ?? 0) < 30 ? 'Échantillon insuffisant pour conclure' : null,
                    ),
                  if (legs > 0) ...[
                    _title('En réel depuis le lancement'),
                    _line('Matchs VIP', '${_n((real['legsWon'] as num?) ?? 0)}/${_n(legs)} gagnés', color: K.green),
                    _line('Coupons VIP', '${_n((real['couponsWon'] as num?) ?? 0)}/${_n((real['coupons'] as num?) ?? 0)} gagnés', color: K.green),
                  ],
                  SizedBox(height: 12),
                  Text("Perdre plusieurs coupons d'affilée est normal. Résultats passés : aucune garantie de gain. 18+",
                      style: TextStyle(color: K.amber, fontSize: 11.5, fontWeight: FontWeight.w700, height: 1.35)),
                ]),
              ),
          ]),
        );
      },
    );
  }
}
