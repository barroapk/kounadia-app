import 'package:flutter/material.dart';
import '../models/forecast.dart';
import 'jersey.dart';

class K {
  static const bg = Color(0xFF0D1020);
  static const card = Color(0xFF181C32);
  static const border = Color(0xFF2A2F4A);
  static const text = Color(0xFFF3F4F6);
  static const muted = Color(0xFF9CA3BF);
  static const indigo = Color(0xFF4F46E5);
  static const indigoSoft = Color(0xFF2B2E5C);
  static const indigoText = Color(0xFF8B91FF);
  static const pending = Color(0xFFA5B4FC);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
  static const amber = Color(0xFFF59E0B);
  static const groupHead = Color(0xFF1F2440);
}

const _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.',
  'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String two(int n) => n.toString().padLeft(2, '0');
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String frDay(DateTime d) => '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';
String prettyScore(String? s) => (s ?? '').replaceAll('-', ' - ');

/// Carte compacte (même format que les lignes de l'onglet Matchs).
/// [grouped] = true : ligne sans cadre, à placer dans un groupe de compétition.
class ForecastCard extends StatelessWidget {
  final Forecast f;
  final bool result;
  final bool grouped;
  const ForecastCard({super.key, required this.f, this.result = false, this.grouped = false});

  @override
  Widget build(BuildContext context) {
    final row = _row();
    if (grouped) return row;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            color: K.groupHead,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(children: [
              const Icon(Icons.emoji_events_outlined, color: K.amber, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(f.league.isEmpty ? 'Football' : f.league,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text(frDay(f.date), style: const TextStyle(color: K.muted, fontSize: 11.5)),
            ]),
          ),
          row,
        ],
      ),
    );
  }

  Widget _team(String name, String? logo, List<Color> colors, int? goals, bool win) {
    return Row(children: [
      TeamCrest(name: name, logo: logo, colors: colors, size: 16),
      const SizedBox(width: 7),
      Expanded(
        child: Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: K.text, fontSize: 13.5, fontWeight: win ? FontWeight.w800 : FontWeight.w500)),
      ),
      if (goals != null) ...[
        const SizedBox(width: 6),
        Text('$goals', style: const TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
      ],
    ]);
  }

  Widget _row() {
    final now = DateTime.now();
    final pickColor = result ? (f.won == true ? K.green : K.red) : K.pending;
    final sc = RegExp(r'(\d+)\s*[-:]\s*(\d+)').firstMatch(f.score ?? '');
    final hg = result && sc != null ? int.parse(sc[1]!) : null;
    final ag = result && sc != null ? int.parse(sc[2]!) : null;

    Widget time;
    if (result) {
      time = Icon(f.won == true ? Icons.check_circle_rounded : Icons.cancel_rounded, color: pickColor, size: 20);
    } else if (now.isBefore(f.date)) {
      time = Text(f.hasTime ? hm(f.date) : '--:--',
          style: const TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700));
    } else if (now.isBefore(f.date.add(const Duration(minutes: 115)))) {
      time = const Text('En\ncours',
          textAlign: TextAlign.center,
          style: TextStyle(color: K.amber, fontSize: 11, fontWeight: FontWeight.w800, height: 1.1));
    } else {
      time = const Text('Fin', style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w700));
    }

    final parts = <String>[
      if (result && f.predicted != null) 'Prédit ${f.predicted}',
      if (result) f.won == true ? 'Validé' : 'Perdu',
      if (!result && f.source == 'ia' && f.predicted != null) 'Score ${f.predicted}',
      if (!result && f.agree != null && f.models != null) '${f.agree}/${f.models} IA',
      if (!result && f.confidence != null) 'Conf. ${f.confidence!.toStringAsFixed(1)}/10',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Row(children: [
        SizedBox(width: 44, child: Center(child: time)),
        Expanded(
          child: Column(children: [
            _team(f.home, f.homeLogo, f.homeColors, hg, hg != null && ag != null && hg > ag),
            const SizedBox(height: 5),
            _team(f.away, f.awayLogo, f.awayColors, ag, hg != null && ag != null && ag > hg),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 112,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(f.tipFr,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pickColor, fontSize: 12.5, fontWeight: FontWeight.w800, height: 1.2)),
              if (parts.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(parts.join(' · '),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: K.muted, fontSize: 10.5)),
              ],
            ],
          ),
        ),
      ]),
    );
  }
}

Widget kMessage(String text, {VoidCallback? onRetry}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_soccer, color: K.muted, size: 44),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: K.muted, fontSize: 15, height: 1.4)),
          if (onRetry != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: K.indigo),
              child: const Text('Réessayer'),
            ),
          ],
        ],
      ),
    ),
  );
}

Widget kOfflineBanner() {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0x33F59E0B),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      children: [
        Icon(Icons.wifi_off, color: K.amber, size: 18),
        SizedBox(width: 10),
        Expanded(
          child: Text('Hors connexion : dernières données enregistrées.',
              style: TextStyle(color: K.amber, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}
