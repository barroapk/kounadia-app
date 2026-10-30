import 'package:flutter/material.dart';
import '../services/fav_leagues.dart';
import '../services/primatips_service.dart';
import '../widgets/forecast_card.dart' show K, kMessage;
import '../widgets/k_ui.dart';
import '../l10n/tr.dart';

String _n(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');

Widget _star(bool on, {bool dim = false}) => Icon(on ? Icons.star_rounded : Icons.star_border_rounded,
    color: on ? (dim ? K.amber.withAlpha(120) : K.amber) : K.muted, size: 26);

/// Paramètres › Mes championnats : même disposition que Classements
/// (sections › pays › compétitions), avec une étoile sur chaque ligne.
class FavLeaguesScreen extends StatefulWidget {
  FavLeaguesScreen({super.key});

  @override
  State<FavLeaguesScreen> createState() => _FavLeaguesScreenState();
}

class _FavLeaguesScreenState extends State<FavLeaguesScreen> {
  late Future<List<PtSection>> _f = PrimaTipsService.countries();
  String _q = '';

  @override
  void initState() {
    super.initState();
    FavLeagues.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar(tr('Mes championnats')),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = _n(v.trim())),
            style: TextStyle(color: K.text),
            cursorColor: K.indigo,
            decoration: InputDecoration(
              hintText: tr('Rechercher un pays ou une compétition'),
              hintStyle: TextStyle(color: K.muted, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: K.muted),
              filled: true,
              fillColor: K.card,
              contentPadding: EdgeInsets.symmetric(vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: K.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: K.indigo)),
            ),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: FavLeagues.set,
            builder: (_, fav, __) => FutureBuilder<List<PtSection>>(
              future: _f,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return kLoader();
                final children = <Widget>[];
                // Mes favoris, toujours en tête.
                final favs = fav
                    .where((k) => _q.isEmpty || _n(frLeague(k)).contains(_q) || _n(k).contains(_q))
                    .toList()
                  ..sort((a, b) => frLeague(a).compareTo(frLeague(b)));
                if (favs.isNotEmpty) {
                  children.add(kTitle('${tr('Mes favoris')} · ${fav.length}'));
                  children.add(kDividers(favs.map(_favTile).toList()));
                }
                if (snap.hasError) {
                  children.add(SizedBox(height: 24));
                  children.add(kMessage(snap.error.toString(),
                      onRetry: () => setState(() => _f = PrimaTipsService.countries())));
                } else {
                  for (final s in snap.data!) {
                    final items = s.items
                        .where((i) => _q.isEmpty || _n(i.name).contains(_q) || _n(frName(i.name)).contains(_q))
                        .toList();
                    if (items.isEmpty) continue;
                    children.add(kTitle(s.title));
                    children.add(kDividers(items.map((l) => _countryTile(l, fav)).toList()));
                  }
                }
                if (children.isEmpty) return kMessage('Aucun résultat pour cette recherche.');
                return ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 32), children: children);
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _favTile(String k) => InkWell(
        onTap: () => FavLeagues.toggleExact(k),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 11, 10, 11),
          child: Row(children: [
            Expanded(
              child: T(frLeague(k),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w700)),
            ),
            _star(true),
          ]),
        ),
      );

  Widget _countryTile(PtLink l, Set<String> fav) {
    final pre = '${l.name} - ';
    final n = fav.where((k) => k == l.name || k.startsWith(pre)).length;
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FavCountryScreen(link: l))),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          PtImage(l.img, w: 26, h: 18),
          SizedBox(width: 12),
          Expanded(
            child: T(frName(l.name), style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
          if (n > 0) ...[
            Icon(Icons.star_rounded, color: K.amber, size: 18),
            SizedBox(width: 2),
            Text('$n', style: TextStyle(color: K.amber, fontWeight: FontWeight.w800, fontSize: 13)),
            SizedBox(width: 6),
          ],
          Icon(Icons.chevron_right_rounded, color: K.muted),
        ]),
      ),
    );
  }
}

/// Compétitions d'un pays (mêmes listes que Classements) avec étoiles.
class FavCountryScreen extends StatefulWidget {
  final PtLink link;
  FavCountryScreen({super.key, required this.link});

  @override
  State<FavCountryScreen> createState() => _FavCountryScreenState();
}

class _FavCountryScreenState extends State<FavCountryScreen> {
  late Future<List<PtTable>> _f = PrimaTipsService.countryTables(widget.link, titlesOnly: true);

  Widget _row(String label, String key, bool on, {bool dim = false, bool bold = false}) => InkWell(
        onTap: () => FavLeagues.toggleExact(key),
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            Expanded(
              child: T(label,
                  style: TextStyle(
                      color: K.text, fontSize: 14.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
            ),
            _star(on, dim: dim),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final name = widget.link.name;
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar(frName(name)),
      body: ValueListenableBuilder<Set<String>>(
        valueListenable: FavLeagues.set,
        builder: (_, fav, __) => FutureBuilder<List<PtTable>>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return kLoader();
            final all = fav.contains(name);
            final rows = <Widget>[
              _row('${tr('Tout')} · ${frName(name)}', name, all, bold: true),
            ];
            final seen = <String>{};
            for (final t in snap.data ?? const <PtTable>[]) {
              final title = t.title.trim();
              if (title.isEmpty || !seen.add(title)) continue;
              final key = '$name - $title';
              final own = fav.contains(key);
              rows.add(_row(tr(title), key, own || all, dim: all && !own));
            }
            return ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              kTitle('Compétitions'),
              kDividers(rows),
              if (snap.hasError) ...[
                SizedBox(height: 16),
                kMessage(snap.error.toString(),
                    onRetry: () => setState(() => _f = PrimaTipsService.countryTables(widget.link, titlesOnly: true))),
              ],
              Padding(
                padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: T('Tes favoris sont affichés en premier dans Matchs.',
                    style: TextStyle(color: K.muted, fontSize: 12.5)),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
