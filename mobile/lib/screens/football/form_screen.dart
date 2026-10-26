import '../../widgets/k_err.dart';
import 'package:flutter/material.dart';
import '../../services/logo_cache.dart';
import '../../services/primatips_service.dart';
import '../../widgets/forecast_card.dart' show K, kMessage;
import '../../widgets/jersey.dart';
import '../../widgets/k_ui.dart';
import '../../l10n/tr.dart';

final _cats = [
  ('wins', 'Victoires'),
  ('draws', 'Nuls'),
  ('losses', 'Défaites'),
  ('goals-scored', 'Buts marqués'),
  ('goals-conceded', 'Buts encaissés'),
];

class FormScreen extends StatefulWidget {
  FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  int _cat = 0;
  bool _most = true;
  int _view = 0;
  late Future<List<PtFormTable>> _f = _load();

  Future<List<PtFormTable>> _load() =>
      PrimaTipsService.form('${_most ? 'most' : 'least'}-${_cats[_cat].$1}');

  void _reload(VoidCallback f) => setState(() {
        f();
        _f = _load();
      });

  Widget _seg(List<String> labels, int sel, ValueChanged<int> on) => Container(
        padding: EdgeInsets.all(3),
        decoration: BoxDecoration(
            color: K.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: K.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => on(i),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                    color: i == sel ? K.indigo : Colors.transparent, borderRadius: BorderRadius.circular(9)),
                child: T(labels[i],
                    style: TextStyle(
                        color: i == sel ? Colors.white : K.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final goals = _cat >= 3;
    return Scaffold(
      backgroundColor: K.bg,
      appBar: kAppBar('Forme des équipes'),
      body: Column(children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: _cats.length,
            separatorBuilder: (_, __) => SizedBox(width: 8),
            itemBuilder: (_, i) => kPill(_cats[i].$2, i == _cat, () {
              if (i != _cat) _reload(() => _cat = i);
            }),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Row(children: [
            _seg(['Plus', 'Moins'], _most ? 0 : 1, (i) {
              if ((i == 0) != _most) _reload(() => _most = i == 0);
            }),
            Spacer(),
            _seg(['Général', 'Dom.', 'Ext.'], _view, (i) => setState(() => _view = i)),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<PtFormTable>>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return kLoader();
              if (snap.hasError) {
                return kMessage(kErr(snap.error), onRetry: () => setState(() => _f = _load()));
              }
              final t = snap.data!;
              if (t.isEmpty) return kMessage('Données de forme indisponibles pour le moment.');
              final table = t[_view < t.length ? _view : 0];
              final where = ['tous les matchs', 'à domicile', "à l'extérieur"];
              return ListView(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
                children: [
                  kTitle('${tr(_most ? 'Le plus de' : 'Le moins de')} ${tr(_cats[_cat].$2).toLowerCase()} · ${tr(where[_view])}'),
                  kDividers(table.rows.map((r) => _row(r, goals)).toList()),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _row(PtFormRow r, bool goals) {
    final isPct = r.pct.contains('%');
    final pct = double.tryParse(r.pct.replaceAll('%', '').replaceAll(',', '.').trim());
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 28,
          child: T('${r.pos}',
              textAlign: TextAlign.center,
              style: TextStyle(color: K.muted, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
        SizedBox(width: 4),
        TeamCrest(name: r.team, logo: LogoCache.get(r.team), size: 26),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T(r.team,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            T(r.league,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: K.muted, fontSize: 11.5)),
          ]),
        ),
        SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          T(goals ? '${r.value} buts · ${r.played} m.' : '${r.value} / ${r.played}',
              style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          if (isPct && pct != null)
            SizedBox(
              width: 64,
              child: Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: K.border,
                      color: _cat == 2 || _cat == 4 ? K.red : K.green,
                    ),
                  ),
                ),
              ]),
            )
          else
            T('${r.pct} / match', style: TextStyle(color: K.muted, fontSize: 11.5)),
        ]),
      ]),
    );
  }
}
