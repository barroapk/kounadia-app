import '../../widgets/k_err.dart';
import 'package:flutter/material.dart';
import '../../services/primatips_service.dart';
import '../../widgets/forecast_card.dart' show K, kMessage;
import '../../widgets/k_ui.dart';
import '../../widgets/standing_table.dart';
import '../../l10n/tr.dart';

class TablesScreen extends StatefulWidget {
  TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  late Future<List<PtSection>> _f = PrimaTipsService.countries();
  String _q = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar('Classements'),
      body: Column(children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
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
          child: FutureBuilder<List<PtSection>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return kLoader();
              if (snap.hasError) {
                return kMessage(kErr(snap.error),
                    onRetry: () => setState(() => _f = PrimaTipsService.countries()));
              }
              final children = <Widget>[];
              for (final s in snap.data!) {
                final items = s.items
                    .where((i) =>
                        _q.isEmpty ||
                        i.name.toLowerCase().contains(_q) ||
                        frName(i.name).toLowerCase().contains(_q))
                    .toList();
                if (items.isEmpty) continue;
                children.add(kTitle(s.title));
                children.add(kDividers(items.map(_tile).toList()));
              }
              if (children.isEmpty) return kMessage('Aucun résultat pour cette recherche.');
              return ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, 32), children: children);
            },
          ),
        ),
      ]),
    );
  }

  Widget _tile(PtLink l) => InkWell(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => CountryTablesScreen(link: l))),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            PtImage(l.img, w: 26, h: 18),
            SizedBox(width: 12),
            Expanded(
              child: T(frName(l.name),
                  style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right_rounded, color: K.muted),
          ]),
        ),
      );
}

class CountryTablesScreen extends StatefulWidget {
  final PtLink link;
  CountryTablesScreen({super.key, required this.link});

  @override
  State<CountryTablesScreen> createState() => _CountryTablesScreenState();
}

class _CountryTablesScreenState extends State<CountryTablesScreen> {
  late Future<List<PtTable>> _f = PrimaTipsService.tables(widget.link.path);

  Widget _view(PtTable t) => ListView(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [StandingTable(rows: t.rows, full: true)],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar(frName(widget.link.name)),
      body: FutureBuilder<List<PtTable>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return kLoader();
          if (snap.hasError) {
            return kMessage(kErr(snap.error),
                onRetry: () => setState(() => _f = PrimaTipsService.tables(widget.link.path)));
          }
          final t = snap.data!;
          if (t.isEmpty) return kMessage('Aucun classement disponible pour le moment.');
          if (t.length == 1) return _view(t.first);
          return DefaultTabController(
            length: t.length,
            child: Column(children: [
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: K.indigo,
                indicatorWeight: 3,
                labelColor: K.text,
                unselectedLabelColor: K.muted,
                dividerColor: K.border,
                labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                tabs: t.map((x) => Tab(text: tr(x.title.isEmpty ? 'Classement' : x.title))).toList(),
              ),
              Expanded(child: TabBarView(children: t.map(_view).toList())),
            ]),
          );
        },
      ),
    );
  }
}
