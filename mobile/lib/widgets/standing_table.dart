import 'package:flutter/material.dart';
import '../services/logo_cache.dart';
import '../services/match_detail_service.dart' show StandRow;
import 'forecast_card.dart' show K;
import 'jersey.dart';
import 'k_ui.dart';

String frZone(String z) {
  var s = z;
  const m = {
    'Relegation': 'Relégation',
    'Champions League': 'Ligue des champions',
    'Europa League': 'Ligue Europa',
    'Conference League': 'Ligue Conférence',
    'Play Offs': 'Barrages',
    'Playoffs': 'Barrages',
    '1/8-finals': '8es de finale',
    'Quarter-finals': 'Quarts de finale',
    'Semi-finals': 'Demi-finales',
  };
  m.forEach((k, v) => s = s.replaceAll(k, v));
  return s;
}

class StandingTable extends StatelessWidget {
  final List<StandRow> rows;
  final Set<String> highlight;
  final bool full;
  const StandingTable({super.key, required this.rows, this.highlight = const {}, this.full = false});

  @override
  Widget build(BuildContext context) {
    const palette = [K.green, K.indigo, Color(0xFF06B6D4), K.amber, Color(0xFFA855F7)];
    final zones = <String, Color>{};
    for (final r in rows) {
      if (r.zone.isEmpty || zones.containsKey(r.zone)) continue;
      zones[r.zone] = RegExp(r'releg', caseSensitive: false).hasMatch(r.zone)
          ? K.red
          : palette[zones.length % palette.length];
    }
    const hs = TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w700);
    Widget cell(String t, double w, TextStyle s) =>
        SizedBox(width: w, child: Text(t, textAlign: TextAlign.center, style: s));
    List<Widget> nums(StandRow? r, TextStyle s) => [
          cell(r?.mp ?? 'J', 26, s),
          if (full) ...[cell(r?.w ?? 'G', 24, s), cell(r?.d ?? 'N', 24, s), cell(r?.l ?? 'P', 24, s)],
          cell(r?.diff ?? 'Diff', 36, s),
          cell(r?.pts ?? 'Pts', 32, s.copyWith(fontWeight: FontWeight.w800)),
        ];

    final list = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(children: [
          cell('#', 24, hs),
          const SizedBox(width: 30),
          const Expanded(child: Text('Équipe', style: hs)),
          ...nums(null, hs),
        ]),
      ),
    ];
    for (final r in rows) {
      final mine = highlight.contains(r.team);
      final ts = TextStyle(color: K.text, fontSize: 13, fontWeight: mine ? FontWeight.w800 : FontWeight.w500);
      list.add(Container(height: 1, color: K.border));
      list.add(Container(
        color: mine ? const Color(0x264F46E5) : null,
        padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
        child: Row(children: [
          Container(width: 4, height: 22, color: zones[r.zone] ?? Colors.transparent),
          const SizedBox(width: 8),
          cell('${r.pos}', 24, ts),
          TeamCrest(name: r.team, logo: LogoCache.get(r.team), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(r.team, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts)),
          ...nums(r, ts),
        ]),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(decoration: kBox(), clipBehavior: Clip.antiAlias, child: Column(children: list)),
        if (zones.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: zones.entries
                .map((e) => Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Text(frZone(e.key), style: const TextStyle(color: K.muted, fontSize: 12)),
                    ]))
                .toList(),
          ),
        ],
      ],
    );
  }
}
