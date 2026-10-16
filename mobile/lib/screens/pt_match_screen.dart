import 'package:flutter/material.dart';
import '../models/live_match.dart';
import '../services/match_detail_service.dart';
import '../services/logo_cache.dart';
import '../widgets/forecast_card.dart' show K, kMessage, hm;
import '../widgets/jersey.dart';

class PtMatchScreen extends StatefulWidget {
  final LiveMatch match;
  const PtMatchScreen({super.key, required this.match});

  @override
  State<PtMatchScreen> createState() => _PtMatchScreenState();
}

class _PtMatchScreenState extends State<PtMatchScreen> {
  late Future<MatchDetail> _f = MatchDetailService.load(widget.match);

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        foregroundColor: K.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(m.leagueLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      ),
      body: FutureBuilder<MatchDetail>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: K.indigo));
          }
          if (snap.hasError) {
            return kMessage(snap.error.toString(),
                onRetry: () => setState(() => _f = MatchDetailService.load(m)));
          }
          final d = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _header(m, d),
              const SizedBox(height: 22),
              const Text('PRONOSTICS',
                  style: TextStyle(
                      color: K.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              const SizedBox(height: 10),
              if (d.markets.isEmpty)
                kMessage('Aucun pronostic détaillé pour ce match.')
              else
                ...d.markets.map((x) => _market(x, m)),
              if (d.updated != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Cotes moyennes avant-match · mise à jour ${d.updated}',
                      style: const TextStyle(color: K.muted, fontSize: 11.5)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _teamCol(String name, String? logo) {
    return Column(
      children: [
        TeamCrest(name: name, logo: logo ?? LogoCache.get(name), size: 56),
        const SizedBox(height: 10),
        Text(name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _header(LiveMatch m, MatchDetail d) {
    String center;
    if (d.liveScore != null && d.liveScore!.contains('-')) {
      center = d.liveScore!;
    } else if (m.hs != null && m.as_ != null) {
      center = '${m.hs} - ${m.as_}';
    } else {
      center = m.date != null ? hm(m.date!) : '--:--';
    }
    String status;
    Color sc;
    switch (m.status) {
      case 'live':
        status = (d.liveStatus?.isNotEmpty ?? false) ? d.liveStatus! : (m.minute ?? 'En direct');
        sc = K.red;
        break;
      case 'finished':
        status = 'Terminé';
        sc = K.muted;
        break;
      case 'postponed':
        status = 'Reporté';
        sc = K.amber;
        break;
      default:
        status = 'À venir';
        sc = K.pending;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: K.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _teamCol(m.home, d.homeLogo)),
          SizedBox(
            width: 100,
            child: Column(
              children: [
                const SizedBox(height: 12),
                FittedBox(
                  child: Text(center,
                      style: const TextStyle(
                          color: K.text, fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                Text(status,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: sc, fontSize: 12.5, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          Expanded(child: _teamCol(m.away, d.awayLogo)),
        ],
      ),
    );
  }

  Widget _market(Market x, LiveMatch m) {
    final c = x.status == 'won'
        ? K.green
        : x.status == 'lost'
            ? K.red
            : K.pending;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: K.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(x.nameFr,
                    style: const TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(x.pickFr(m.home, m.away),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (x.odd.isNotEmpty)
                Text('@ ${x.odd}',
                    style: const TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w800)),
              if (x.prob != null)
                Text('${x.prob} %', style: const TextStyle(color: K.muted, fontSize: 12.5)),
            ],
          ),
          if (x.status != 'pending')
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Icon(x.status == 'won' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: c, size: 22),
            ),
        ],
      ),
    );
  }
}
