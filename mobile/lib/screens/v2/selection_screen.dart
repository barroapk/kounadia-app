import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../services/account.dart';
import '../../services/v2_live.dart';
import '../../services/v2_service.dart';
import '../../widgets/forecast_card.dart' show K, kMessage, kOfflineBanner;
import '../../widgets/knd_banner.dart';
import 'v2_cats.dart';
import 'v2_history_screen.dart';
import 'v2_widgets.dart';

/// Une catégorie du menu ☰ de la Sélection du jour.
class SelFilter {
  final String key, title;
  final IconData icon;
  final String? fam; // catégorie d'événements
  final String? coupon; // c2, c5, c10
  const SelFilter(this.key, this.title, this.icon, {this.fam, this.coupon});

  List<V2Leg> legs(V2Selection s) {
    if (key == 'all') return s.top;
    return s.byFam.where((l) => l.fam == fam).toList()..sort((a, b) => b.p.compareTo(a.p));
  }

  V2Cat cat() => V2Cat(title,
      coupon: coupon == null ? null : (d) => d.selection?.coupons[coupon],
      legs: coupon != null ? null : (d) => d.selection == null ? const <V2Leg>[] : legs(d.selection!));
}

const kSelFilters = <SelFilter>[
  SelFilter('all', 'Coups sûrs', Icons.verified_rounded),
  SelFilter('dc', 'Double chance (1X · X2 · 12)', Icons.shield_rounded, fam: 'dc'),
  SelFilter('res', 'Victoire (1 · 2)', Icons.emoji_events_rounded, fam: 'res'),
  SelFilter('buts', 'Plus / moins de buts', Icons.sports_soccer_rounded, fam: 'buts'),
  SelFilter('btts', 'Les deux équipes marquent', Icons.compare_arrows_rounded, fam: 'btts'),
  SelFilter('equipe', "Buts d'une équipe", Icons.groups_rounded, fam: 'equipe'),
  SelFilter('mt', 'Buts par mi-temps', Icons.timelapse_rounded, fam: 'mt'),
  SelFilter('stc', 'Corners', Icons.flag_rounded, fam: 'stc'),
  SelFilter('stf', 'Fautes', Icons.front_hand_rounded, fam: 'stf'),
  SelFilter('sts', 'Tirs', Icons.ads_click_rounded, fam: 'sts'),
  SelFilter('stt', 'Tirs cadrés', Icons.gps_fixed_rounded, fam: 'stt'),
  SelFilter('c2', 'Coupon cote 2+', Icons.confirmation_number_rounded, coupon: 'c2'),
  SelFilter('c5', 'Coupon cote 5+', Icons.confirmation_number_rounded, coupon: 'c5'),
  SelFilter('c10', 'Coupon cote 10+', Icons.local_fire_department_rounded, coupon: 'c10'),
];

class SelectionScreen extends StatefulWidget {
  SelectionScreen({super.key});

  @override
  State<SelectionScreen> createState() => _SelectionScreenState();
}

class _SelectionScreenState extends State<SelectionScreen> {
  late Future<V2Data> _f;
  SelFilter _sel = kSelFilters.first;
  Set<String> _favs = {};
  String _favDay = '';

  @override
  void initState() {
    super.initState();
    _f = _load();
    Account.user.addListener(_userChanged);
    V2Live.tick.addListener(_live);
  }

  @override
  void dispose() {
    Account.user.removeListener(_userChanged);
    V2Live.tick.removeListener(_live);
    V2Live.stop(this);
    super.dispose();
  }

  void _live() {
    if (mounted) setState(() {});
  }

  Future<V2Data> _load({bool force = false}) async {
    final d = await V2Service.shared(force: force);
    final s = d.today?.selection;
    if (s != null) V2Live.follow(this, s.allLegs);
    _favDay = d.today?.day ?? '';
    try {
      final p = await SharedPreferences.getInstance();
      _favs = (p.getStringList('kv2_fav_$_favDay') ?? const []).toSet();
    } catch (_) {}
    return d;
  }

  Future<void> _star(V2Leg l) async {
    setState(() => _favs.contains(l.key) ? _favs.remove(l.key) : _favs.add(l.key));
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('kv2_fav_$_favDay', _favs.toList());
    } catch (_) {}
  }

  void _userChanged() {
    if (mounted) setState(() => _f = _load(force: true));
  }

  Future<void> _reload() async {
    final f = _load(force: true);
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  int _count(V2Selection s, SelFilter f) => f.coupon != null ? (s.coupons[f.coupon] == null ? 0 : 1) : f.legs(s).length;

  /// Menu ☰ : panneau latéral assez large pour lire les catégories, avec barre de défilement visible.
  Future<void> _openMenu(V2Data d) async {
    final s = d.today?.selection;
    final w = MediaQuery.of(context).size.width;
    final panel = (w * 0.72).clamp(250.0, 340.0).toDouble();
    final picked = await showGeneralDialog<SelFilter>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'menu',
      barrierColor: Colors.black.withAlpha(110),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) {
        final ctl = ScrollController();
        return Align(
          alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
          child: Material(
            color: K.card,
            child: SafeArea(
              child: SizedBox(
                width: panel,
                height: double.infinity,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 10, 10),
                    child: T('Catégories', style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
                  ),
                  Container(height: 1, color: K.border),
                  Expanded(
                    child: Scrollbar(
                      controller: ctl,
                      thumbVisibility: true,
                      child: ListView(
                        controller: ctl,
                        padding: EdgeInsets.only(bottom: 16),
                        children: [for (final f in kSelFilters) _menuItem(ctx, f, s == null ? null : _count(s, f))],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a, _, child) => SlideTransition(
        position: Tween(begin: Offset(isRtl ? 1 : -1, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)),
        child: child,
      ),
    );
    if (picked != null && mounted) setState(() => _sel = picked);
  }

  Widget _menuItem(BuildContext ctx, SelFilter f, int? n) {
    final on = f.key == _sel.key;
    final empty = n == 0;
    return InkWell(
      onTap: () => Navigator.pop(ctx, f),
      child: Container(
        color: on ? K.indigoSoft : null,
        padding: EdgeInsets.fromLTRB(16, 13, 14, 13),
        child: Row(children: [
          Icon(f.icon, size: 20, color: on ? K.indigoText : empty ? K.border : K.muted),
          SizedBox(width: 12),
          Expanded(
            child: T(f.title,
                style: TextStyle(color: empty ? K.muted : K.text, fontSize: 14, fontWeight: on ? FontWeight.w900 : FontWeight.w600)),
          ),
          if (n != null && f.coupon == null) Text('$n', style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: FutureBuilder<V2Data>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator(color: K.indigo));
          }
          if (snap.hasError) return kMessage(kV2Unavailable, onRetry: _reload);
          final d = snap.data!;
          // Avant le calcul du matin : les Coups sûrs d'hier restent visibles, avec leurs résultats.
          final s = d.today?.selection ?? (d.history.isNotEmpty ? d.history.first.selection : null);
          return Column(children: [
            Container(
              color: K.bg,
              child: TabBar(
                labelColor: K.text,
                unselectedLabelColor: K.muted,
                indicatorColor: K.indigo,
                labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                tabs: [
                  Tab(text: tr('Coups sûrs')),
                  Tab(text: _favs.isEmpty ? tr('Mes favoris') : '${tr('Mes favoris')} (${_favs.length})'),
                ],
              ),
            ),
            Expanded(child: TabBarView(children: [_selection(d, s), _favorites(d, s)])),
          ]);
        },
      ),
    );
  }

  Widget _wrap(V2Data d, List<Widget> children) => RefreshIndicator(
        color: K.indigo,
        onRefresh: _reload,
        child: ListView(physics: AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(12, 10, 12, 96), children: [
          if (d.offline) kOfflineBanner(),
          ...children,
          SizedBox(height: 6),
          T('18+ · Aucun gain garanti · Joue de manière responsable.',
              textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5)),
        ]),
      );

  Widget _selection(V2Data d, V2Selection? s) {
    final f = _sel;
    final monday = v2Monday(DateTime.now());
    final week = f.cat().period(d, monday, monday.add(Duration(days: 7)));
    final body = <Widget>[];
    if (d.today == null) {
      body.add(V2NextCountdown());
      if (s != null) {
        body.add(Padding(
          padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: T('Résultats d\'hier', style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
        ));
      }
    }
    if (s == null || s.locked) {
      body.add(SizedBox(height: 260, child: kMessage("Les Coups sûrs du jour ne sont pas encore prêts. Tire vers le bas pour actualiser.")));
    } else if (f.coupon != null) {
      body.add(V2CouponCard(
        title: f.title,
        coupon: s.coupons[f.coupon],
        week: week,
        accent: f.coupon == 'c10' ? Color(0xFFDC2626) : f.coupon == 'c5' ? Color(0xFFEA580C) : Color(0xFF4F46E5),
        onHistory: () => _history(d, f),
      ));
    } else {
      final legs = f.legs(s);
      body.add(Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
        child: v2WeekLine(week, onHistory: () => _history(d, f)),
      ));
      if (legs.isEmpty) {
        body.add(SizedBox(height: 200, child: kMessage("Rien dans cette catégorie aujourd'hui.")));
      } else {
        body.addAll(v2Groups(legs, favs: _favs, onStar: _star));
      }
    }
    // En-tête fixe (menu, catégories) ; seules les cartes de matchs défilent.
    final header = Container(
      color: K.bg,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Material(
          color: K.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: K.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openMenu(d),
            child: Padding(padding: EdgeInsets.all(10), child: Icon(Icons.menu_rounded, color: K.text)),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: T(f.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
        ),
      ]),
      SizedBox(height: 10),
      _chips(s),
      ]),
    );
    return Column(children: [
      header,
      Container(height: 1, color: K.border),
      Expanded(child: _wrap(d, [...body, KndBanner()])),
    ]);
  }

  /// Les catégories toujours visibles sous le titre (en plus du menu ☰).
  Widget _chips(V2Selection? s) {
    final ready = s != null && !s.locked;
    final list = [for (final f in kSelFilters) if (f.key == _sel.key || !ready || _count(s!, f) > 0) f];
    return SizedBox(
      height: 38,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        for (final f in list)
          Padding(
            padding: EdgeInsetsDirectional.only(end: 8),
            child: Material(
              color: f.key == _sel.key ? K.indigo : K.card,
              shape: StadiumBorder(side: BorderSide(color: f.key == _sel.key ? K.indigo : K.border)),
              child: InkWell(
                customBorder: StadiumBorder(),
                onTap: () => setState(() => _sel = f),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(f.icon, size: 16, color: f.key == _sel.key ? Colors.white : K.muted),
                    SizedBox(width: 6),
                    T(_short(f), style: TextStyle(color: f.key == _sel.key ? Colors.white : K.text, fontSize: 13, fontWeight: FontWeight.w800)),
                    if (ready && f.coupon == null) ...[
                      SizedBox(width: 6),
                      Text('${_count(s!, f)}', style: TextStyle(color: f.key == _sel.key ? Color(0xDDFFFFFF) : K.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  /// Nom court d'une catégorie pour les pastilles.
  String _short(SelFilter f) => const {
        'dc': 'Double chance', 'res': 'Victoire', 'buts': 'Buts', 'btts': 'Les deux marquent', 'equipe': "Buts d'une équipe",
        'mt': 'Mi-temps', 'c2': 'Cote 2+', 'c5': 'Cote 5+', 'c10': 'Cote 10+',
      }[f.key] ?? f.title;

  Widget _favorites(V2Data d, V2Selection? s) {
    final all = <String, V2Leg>{for (final l in [...?s?.top, ...?s?.byFam]) l.key: l};
    final legs = [for (final k in _favs) if (all[k] != null) all[k]!];
    return _wrap(d, [
      if (legs.isEmpty)
        SizedBox(height: 300, child: kMessage('Touche ☆ sur un pari des Coups sûrs pour le suivre ici.'))
      else
        ...v2Groups(legs, favs: _favs, onStar: _star),
    ]);
  }

  void _history(V2Data d, SelFilter f) => Navigator.push(context, MaterialPageRoute(builder: (_) => V2HistoryScreen(f.cat(), d)));
}
