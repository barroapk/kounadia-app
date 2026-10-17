import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../services/fav_leagues.dart';
import '../services/primatips_service.dart' show frLeague;
import '../services/scores_service.dart';
import '../widgets/forecast_card.dart' show K, kMessage;

class _Lg {
  final String key;
  final String name;
  final String flag;
  final Set<String> teams = {};
  _Lg(this.key, this.name, this.flag);
}

String _n(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

/// Paramètres › Mes championnats : recherche instantanée (championnat ou équipe) + étoiles.
class FavLeaguesScreen extends StatefulWidget {
  FavLeaguesScreen({super.key});

  @override
  State<FavLeaguesScreen> createState() => _FavLeaguesScreenState();
}

class _FavLeaguesScreenState extends State<FavLeaguesScreen> {
  List<_Lg> _all = [];
  bool _loading = true;
  String _q = '';

  @override
  void initState() {
    super.initState();
    FavLeagues.load();
    _load();
  }

  Future<void> _load() async {
    try {
      final (days, _) = await ScoresService.load();
      final map = <String, _Lg>{};
      for (final l in days.values) {
        for (final m in l) {
          final lg = map.putIfAbsent(m.leagueLabel, () => _Lg(m.leagueLabel, frLeague(m.leagueLabel), m.flag));
          lg.teams..add(m.home)..add(m.away);
        }
      }
      // Favoris absents des 3 jours affichés : on les garde dans la liste.
      for (final k in FavLeagues.set.value) {
        map.putIfAbsent(k, () => _Lg(k, frLeague(k), ''));
      }
      _all = map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        foregroundColor: K.text,
        title: Text('Mes championnats', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: FavLeagues.set,
        builder: (_, fav, __) {
          if (_loading) return Center(child: CircularProgressIndicator(color: K.indigo));
          final q = _n(_q.trim());
          final rows = <(_Lg, String?)>[];
          for (final lg in _all) {
            if (q.isEmpty) {
              rows.add((lg, null));
            } else if (_n(lg.name).contains(q) || _n(lg.key).contains(q)) {
              rows.add((lg, null));
            } else {
              final t = lg.teams.where((x) => _n(x).contains(q)).toList();
              if (t.isNotEmpty) rows.add((lg, t.take(2).join(', ')));
            }
          }
          int fv(_Lg x) => fav.contains(x.key) ? 0 : 1;
          rows.sort((a, b) {
            final c = fv(a.$1) - fv(b.$1);
            return c != 0 ? c : a.$1.name.compareTo(b.$1.name);
          });
          return Column(children: [
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                style: TextStyle(color: K.text),
                decoration: InputDecoration(
                  hintText: 'Chercher un championnat ou une équipe…',
                  hintStyle: TextStyle(color: K.muted),
                  prefixIcon: Icon(Icons.search_rounded, color: K.muted),
                  filled: true,
                  fillColor: K.card,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: K.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: K.border)),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 2, 16, 6),
              child: Row(children: [
                Icon(Icons.star_rounded, color: K.amber, size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text('${fav.length} favori${fav.length > 1 ? 's' : ''} · affichés en premier dans Matchs',
                      style: TextStyle(color: K.muted, fontSize: 12.5)),
                ),
              ]),
            ),
            Expanded(
              child: rows.isEmpty
                  ? kMessage(_all.isEmpty ? 'Liste indisponible hors connexion.' : 'Aucun résultat.')
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final (lg, team) = rows[i];
                        final on = fav.contains(lg.key);
                        return Material(
                          color: K.card,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => FavLeagues.toggle(lg.key),
                            child: Container(
                              padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: on ? K.amber : K.border),
                              ),
                              child: Row(children: [
                                if (lg.flag.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: CachedNetworkImage(
                                      imageUrl: lg.flag,
                                      width: 20,
                                      height: 14,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => SizedBox(width: 20),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                ],
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(lg.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w700)),
                                    if (team != null)
                                      Text('Équipe : $team',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: K.muted, fontSize: 12)),
                                  ]),
                                ),
                                Icon(on ? Icons.star_rounded : Icons.star_border_rounded,
                                    color: on ? K.amber : K.muted, size: 26),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
