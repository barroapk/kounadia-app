import 'package:flutter/material.dart';
import '../models/tip.dart';
import '../services/tips_service.dart';

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  final _service = TipsService();
  double _min = 0.6;
  late Future<({List<Tip> tips, String source})> _future;

  static const _leagues = {
    'premier-league': 'Premier League',
    'la-liga': 'LaLiga',
    'serie-a': 'Serie A',
    'bundesliga': 'Bundesliga',
    'ligue-1': 'Ligue 1',
  };

  @override
  void initState() {
    super.initState();
    _future = _service.getTips(min: _min);
  }

  void _reload() {
    setState(() {
      _future = _service.getTips(min: _min);
    });
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String _fmtDate(DateTime d) {
    const j = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
    return '${j[d.weekday - 1]} ${_two(d.day)}/${_two(d.month)} · '
        '${_two(d.hour)}:${_two(d.minute)}';
  }

  String _pct(double p) => '${(p * 100).round()} %';

  String _pickLabel(Tip t) {
    switch (t.pick) {
      case 'home':
        return '1 · ${t.home} gagne';
      case 'away':
        return '2 · ${t.away} gagne';
      default:
        return 'N · Match nul';
    }
  }

  Widget _tipCard(BuildContext context, Tip t) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_leagues[t.league] ?? t.league} · ${_fmtDate(t.date)}',
                style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text('${t.home} – ${t.away}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(_pickLabel(t),
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w600)),
                ),
                Text(_pct(t.prob),
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: t.prob, minHeight: 6),
            ),
            const SizedBox(height: 6),
            Text(
                '1 : ${_pct(t.pHome)}   N : ${_pct(t.pDraw)}   2 : ${_pct(t.pAway)}',
                style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pronostics')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Wrap(
              spacing: 8,
              children: [0.6, 0.7, 0.8].map((v) {
                return ChoiceChip(
                  label: Text('≥ ${(v * 100).round()} %'),
                  selected: _min == v,
                  onSelected: (_) {
                    _min = v;
                    _reload();
                  },
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<({List<Tip> tips, String source})>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pronostics indisponibles'),
                        const SizedBox(height: 8),
                        FilledButton(
                            onPressed: _reload,
                            child: const Text('Réessayer')),
                      ],
                    ),
                  );
                }
                final tips = snap.data!.tips;
                final source = snap.data!.source;
                if (tips.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucun favori à ${_pct(_min)} ou plus '
                        'dans les 7 prochains jours.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.builder(
                    itemCount: tips.length + 1,
                    itemBuilder: (context, i) {
                      if (i == tips.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Source : $source',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall),
                        );
                      }
                      return _tipCard(context, tips[i]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
