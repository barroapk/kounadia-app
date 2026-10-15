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
}

const _jours = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _mois = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.',
  'août', 'sept.', 'oct.', 'nov.', 'déc.'];

String two(int n) => n.toString().padLeft(2, '0');
String hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';
String frDay(DateTime d) => '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';
String prettyScore(String? s) => (s ?? '').replaceAll('-', ' - ');

class ForecastCard extends StatelessWidget {
  final Forecast f;
  final bool result;
  const ForecastCard({super.key, required this.f, this.result = false});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String status;
    Color statusColor;
    Color statusBg;
    if (result) {
      status = 'TERMINÉ';
      statusColor = K.indigoText;
      statusBg = K.indigoSoft;
    } else if (now.isBefore(f.date)) {
      status = 'À VENIR';
      statusColor = K.indigoText;
      statusBg = K.indigoSoft;
    } else if (now.isBefore(f.date.add(const Duration(minutes: 115)))) {
      status = 'EN COURS';
      statusColor = K.amber;
      statusBg = const Color(0x33F59E0B);
    } else {
      status = 'TERMINÉ';
      statusColor = K.muted;
      statusBg = K.border;
    }

    final pickColor = result ? (f.won == true ? K.green : K.red) : K.pending;

    Widget center;
    if (result) {
      center = Column(mainAxisSize: MainAxisSize.min, children: [
        Text(f.score ?? '-',
            style: const TextStyle(color: K.text, fontSize: 30, fontWeight: FontWeight.w800)),
        if (f.predicted != null)
          Text('(${f.predicted})',
              style: TextStyle(color: pickColor, fontSize: 15, fontWeight: FontWeight.w700)),
      ]);
    } else if (f.source == 'ia' && f.predicted != null) {
      center = Column(mainAxisSize: MainAxisSize.min, children: [
        Text(f.predicted!,
            style: const TextStyle(color: K.text, fontSize: 28, fontWeight: FontWeight.w800)),
        const Text('prédit', style: TextStyle(color: K.muted, fontSize: 11)),
      ]);
    } else {
      center = Column(mainAxisSize: MainAxisSize.min, children: [
        Text(f.hasTime ? hm(f.date) : '--:--',
            style: const TextStyle(color: K.text, fontSize: 24, fontWeight: FontWeight.w800)),
        const Text("coup d'envoi", style: TextStyle(color: K.muted, fontSize: 11)),
      ]);
    }

    String sub;
    if (result) {
      sub = f.won == true ? 'Validé ✓' : 'Perdu ✗';
    } else if (f.source == 'ia' && f.agree != null && f.models != null) {
      sub = "${f.agree}/${f.models} IA d'accord";
    } else if (f.confidence != null) {
      sub = 'Confiance ${f.confidence!.toStringAsFixed(1)}/10';
    } else {
      sub = '';
    }

    final meta = [
      frDay(f.date),
      if (f.hasTime) hm(f.date),
      if (f.league.isNotEmpty) f.league,
    ].join(' • ');

    return Container(
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: K.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _team(f.home, f.homeLogo, f.homeColors),
                        const SizedBox(height: 16),
                        _team(f.away, f.awayLogo, f.awayColors),
                      ],
                    ),
                  ),
                  SizedBox(width: 84, child: Center(child: center)),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: K.border,
                  ),
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(f.tipFr,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: pickColor,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              )),
                          if (sub.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(sub,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: K.muted, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: K.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: K.muted, fontSize: 13.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _team(String name, String? logo, List<Color> colors) {
    return Row(
      children: [
        TeamCrest(name: name, logo: logo, colors: colors, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: K.text, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ],
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
