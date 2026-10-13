import 'package:flutter/material.dart';
import '../models/tip.dart';
import '../services/tips_service.dart';

const _bg = Color(0xFF1E1E1E);
const _head = Color(0xFF2A2A2A);
const _row = Color(0xFF333333);
const _yellow = Color(0xFFF2FF00);
const _lime = Color(0xFFB6F24A);

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
    'premier-league': 'Angleterre : Premier League',
    'la-liga': 'Espagne : LaLiga',
    'serie-a': 'Italie : Serie A',
    'bundesliga': 'Allemagne : Bundesliga',
    'ligue-1': 'France : Ligue 1',
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
  String _day(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';
  String _hour(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';
  String _pct(double p) => '${(p * 100).round()} %';

  String _pickLabel(Tip t) {
    switch (t.pick) {
      case 'home':
        return 'Victoire ${t.home}';
      case 'away':
        return 'Victoire ${t.away}';
      default:
        return 'Match nul';
    }
  }

  Widget _dayHeader(String day) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Text(day,
              style: const TextStyle(color: Colors.white, fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1.5, color: _yellow)),
        ],
      ),
    );
  }

  Widget _tipCard(Tip t) {
    const white = TextStyle(color: Colors.white, fontSize: 16);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        children: [
          Container(
            color: _head,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Text(_hour(t.date), style: white),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(_leagues[t.league] ?? t.league,
                      style: white, overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.access_time, color: Colors.white),
              ],
            ),
          ),
          Container(
            color: _row,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(t.home,
                      style: white.copyWith(fontSize: 18),
                      overflow: TextOverflow.ellipsis),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('VS',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                ),
                Expanded(
                  child: Text(t.away,
                      textAlign: TextAlign.right,
                      style: white.copyWith(fontSize: 18),
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Container(height: 1, color: Colors.black26),
          Container(
            color: _row,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 14),
                      child: Text(_pickLabel(t),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: _lime,
                              fontWeight: FontWeight.bold,
                              fontSize: 17)),
                    ),
                  ),
                  Container(
                    width: 90,
                    color: _yellow,
                    alignment: Alignment.center,
                    child: Text(_pct(t.prob),
                        style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildList(List<Tip> tips) {
    final byDay = <String, List<Tip>>{};
    final sorted = [...tips]..sort((a, b) => a.date.compareTo(b.date));
    for (final t in sorted) {
      byDay.putIfAbsent(_day(t.date), () => []).add(t);
    }
    final out = <Widget>[];
    byDay.forEach((day, list) {
      list.sort((a, b) => b.prob.compareTo(a.prob));
      out.add(_dayHeader(day));
      out.addAll(list.map(_tipCard));
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text('Pronostics'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [0.6, 0.7, 0.8].map((v) {
                final sel = _min == v;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('≥ ${(v * 100).round()} %'),
                    selected: sel,
                    selectedColor: _yellow,
                    backgroundColor: _row,
                    labelStyle: TextStyle(
                        color: sel ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold),
                    onSelected: (_) {
                      _min = v;
                      _reload();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: FutureBuilder<({List<Tip> tips, String source})>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                      child: CircularProgressIndicator(color: _yellow));
                }
                if (snap.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Pronostics indisponibles',
                            style: TextStyle(color: Colors.white)),
                        const SizedBox(height: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: _yellow,
                              foregroundColor: Colors.black),
                          onPressed: _reload,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  );
                }
                final tips = snap.data!.tips;
                if (tips.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Aucun favori à ${_pct(_min)} ou plus '
                        'dans les 7 prochains jours.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  color: _yellow,
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView(
                    children: [
                      ..._buildList(tips),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Source : ${snap.data!.source}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12)),
                      ),
                    ],
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
