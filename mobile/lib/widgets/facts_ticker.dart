import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../l10n/facts_text.dart';
import '../l10n/tr.dart';
import '../services/facts_service.dart';
import '../services/primatips_service.dart' show frName;
import 'forecast_card.dart' show K, hm;
import 'jersey.dart';
import 'k_ui.dart';

/// Bandeau « Faits du jour » sous le logo : les faits défilent en boucle, à vitesse de lecture
/// (de droite à gauche ; de gauche à droite en arabe). Toucher le bandeau ouvre la liste complète.
class FactsTicker extends StatefulWidget {
  const FactsTicker({super.key});

  @override
  State<FactsTicker> createState() => _FactsTickerState();
}

class _FactsTickerState extends State<FactsTicker> with SingleTickerProviderStateMixin {
  static const _speed = 40.0; // pixels par seconde : le temps de lire
  final _sc = ScrollController();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  DateTime _pauseUntil = DateTime(2000);
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    FactsService.changed.addListener(_re);
    FactsService.load();
    _refresh = Timer.periodic(const Duration(minutes: 10), (_) => FactsService.load(force: true));
    _ticker = createTicker(_tick);
    _sync();
  }

  // Le défilement ne tourne que s'il y a des faits à montrer (pas d'images calculées pour rien).
  void _sync() {
    final on = FactsService.items.isNotEmpty;
    if (on && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!on && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _re() {
    if (!mounted) return;
    setState(() {});
    _sync();
  }

  void _tick(Duration e) {
    final dt = (e - _last).inMicroseconds / 1e6;
    _last = e;
    if (dt <= 0 || dt > 0.25 || !_sc.hasClients || DateTime.now().isBefore(_pauseUntil)) return;
    _sc.jumpTo(_sc.offset + _speed * dt);
  }

  @override
  void dispose() {
    FactsService.changed.removeListener(_re);
    _refresh?.cancel();
    _ticker.dispose();
    _sc.dispose();
    super.dispose();
  }

  Widget _item(DayFact f) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 26),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          TeamCrest(name: f.team, logo: f.logo, size: 16),
          const SizedBox(width: 7),
          Text(factText(f), style: TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
          if (f.date != null)
            Text('  ·  ${hm(f.date!)}', style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 26),
          Icon(Icons.circle, size: 5, color: K.indigoText.withAlpha(140)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final list = FactsService.items;
    if (list.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
      child: GestureDetector(
        onTap: () => showFactsSheet(context),
        child: Container(
          height: 34,
          decoration: kBox(r: 12),
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            // Repère compact (l'éclair seul) : toute la place pour le texte qui défile.
            Container(
              width: 32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              alignment: Alignment.center,
              child: Semantics(label: tr('Faits du jour'), child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 17)),
            ),
            Expanded(
              child: ShaderMask(
                // Bords en fondu : le texte entre et sort en douceur.
                shaderCallback: (r) => const LinearGradient(
                  colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                  stops: [0, .05, .95, 1],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: NotificationListener<ScrollStartNotification>(
                  onNotification: (n) {
                    // L'utilisateur fait défiler lui-même : on attend avant de reprendre.
                    if (n.dragDetails != null) _pauseUntil = DateTime.now().add(const Duration(seconds: 4));
                    return false;
                  },
                  child: ListView.builder(
                    controller: _sc,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsetsDirectional.only(start: 14),
                    itemBuilder: (_, i) => Center(child: _item(list[i % list.length])),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Liste complète des faits du jour, regroupés par match.
Future<void> showFactsSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: K.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => FractionallySizedBox(heightFactor: 0.82, child: _FactsSheet()),
    );

class _FactsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final list = FactsService.items;
    final byMatch = <String, List<DayFact>>{};
    for (final f in list) {
      byMatch.putIfAbsent(f.id, () => []).add(f);
    }
    return Column(children: [
      const SizedBox(height: 10),
      Container(width: 42, height: 5, decoration: BoxDecoration(color: K.border, borderRadius: BorderRadius.circular(3))),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              T('Faits du jour', style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900)),
              T('Grands championnats · matchs du jour', style: TextStyle(color: K.muted, fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(child: T('Aucun fait marquant pour le moment.', style: TextStyle(color: K.muted)))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                children: [
                  for (final e in byMatch.entries) _match(e.value),
                ],
              ),
      ),
    ]);
  }

  Widget _match(List<DayFact> fs) {
    final f0 = fs.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: kBox(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${frName(f0.lg).toUpperCase()}${f0.date != null ? '  ·  ${hm(f0.date!)}' : ''}',
          style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: .8),
        ),
        const SizedBox(height: 8),
        Row(children: [
          TeamCrest(name: f0.home, logo: f0.hl, size: 22),
          const SizedBox(width: 8),
          Flexible(child: Text(f0.home, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w900))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('–', style: TextStyle(color: K.muted, fontWeight: FontWeight.w900))),
          Flexible(child: Text(f0.away, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w900))),
          const SizedBox(width: 8),
          TeamCrest(name: f0.away, logo: f0.al, size: 22),
        ]),
        const SizedBox(height: 10),
        for (final f in fs)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(_icon(f.k), size: 17, color: _color(f.k)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(factText(f), style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35))),
            ]),
          ),
      ]),
    );
  }

  static IconData _icon(String k) => switch (k) {
        'ws' || 'hw' || 'aw' || 'us' || 'hu' => Icons.trending_up_rounded,
        'ls' || 'nw' || 'hl' || 'anw' => Icons.trending_down_rounded,
        'cs' || 'cs1' || 'c6' || 'c61' => Icons.shield_rounded,
        'bl' => Icons.block_rounded,
        'sc' || 'g5' || 'g6' || 'o25' || 'bt' => Icons.sports_soccer_rounded,
        'h2hw' || 'h2hu' => Icons.compare_arrows_rounded,
        'top' || 'lead' => Icons.emoji_events_rounded,
        'ab' => Icons.personal_injury_rounded,
        _ => Icons.bolt_rounded,
      };

  static Color _color(String k) => switch (k) {
        'ls' || 'nw' || 'hl' || 'anw' || 'bl' || 'ab' => K.red,
        'top' || 'lead' => K.amber,
        _ => K.green,
      };
}
