import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../services/account.dart';
import '../../services/codes.dart';
import '../../services/v2_live.dart';
import '../../services/v2_service.dart';
import '../../widgets/forecast_card.dart' show K, kMessage, kOfflineBanner;
import '../../widgets/knd_banner.dart';
import 'v2_cats.dart';
import 'v2_history_screen.dart';
import 'v2_widgets.dart';

/// Les coupons du jour : 2 gratuits, 3 VIP.
final kFreeCats = <(String, String, Color)>[
  ('single', 'Single du jour', Color(0xFF16A34A)),
  ('free', 'Coupon gratuit', Color(0xFF0EA5E9)),
];
final kVipCats = <(String, String, Color)>[
  ('vip2', 'Coupon VIP · cote 2', Color(0xFFD4A017)),
  ('vip3', 'Coupon VIP · cote 3', Color(0xFFEA580C)),
  ('vip5', 'Coupon VIP · cote 5', Color(0xFFDC2626)),
];

V2Cat dayCat(String key, String title) => V2Cat(title, coupon: (d) => d.coupons[key]);

class CouponDayScreen extends StatefulWidget {
  CouponDayScreen({super.key});

  @override
  State<CouponDayScreen> createState() => _CouponDayScreenState();
}

class _CouponDayScreenState extends State<CouponDayScreen> {
  late Future<V2Data> _f;
  bool? _prem;

  @override
  void initState() {
    super.initState();
    _f = _load();
    _prem = Account.premium;
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
    unawaited(Codes.load());
  }

  Future<V2Data> _load({bool force = false}) async {
    unawaited(Codes.load(force: force));
    final d = await V2Service.shared(force: force);
    final t = d.today;
    if (t != null) V2Live.follow(this, [for (final c in t.coupons.values) ...?c?.legs]);
    return d;
  }

  void _userChanged() {
    if (_prem == Account.premium || !mounted) return;
    _prem = Account.premium;
    setState(() => _f = _load(force: true));
  }

  Future<void> _reload() async {
    final f = _load(force: true);
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        // Onglets en pastilles : Gratuits / VIP (VIP en or).
        Container(
          margin: EdgeInsets.fromLTRB(14, 12, 14, 4),
          height: 46,
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16)),
          child: TabBar(
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: K.muted,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            tabs: [
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.card_giftcard_rounded, size: 17), SizedBox(width: 6), Text(tr('Coupons gratuits'))])),
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.workspace_premium_rounded, size: 17, color: Color(0xFFD4A017)), SizedBox(width: 6), Text(tr('Coupons VIP'))])),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<V2Data>(
            future: _f,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Center(child: CircularProgressIndicator(color: K.indigo));
              }
              if (snap.hasError) return kMessage(kV2Unavailable, onRetry: _reload);
              final d = snap.data!;
              return TabBarView(children: [_list(d, kFreeCats, true), _list(d, kVipCats, false)]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _list(V2Data d, List<(String, String, Color)> cats, bool free) {
    final t = d.today;
    final monday = v2Monday(DateTime.now());
    // Coupons VIP : leur historique et leurs résultats restent réservés au Premium.
    final hideHist = !free && !Account.premium;
    return RefreshIndicator(
      color: K.indigo,
      onRefresh: _reload,
      child: ListView(physics: AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(14, 12, 14, 110), children: [
        if (d.offline) kOfflineBanner(),
        if (t == null) ...[
          // Avant le calcul du matin : compte à rebours, et les coupons d'hier restent visibles avec leurs résultats.
          V2NextCountdown(),
          if (d.history.isNotEmpty && !hideHist) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(4, 2, 4, 10),
              child: T('Résultats d\'hier', style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            for (final (key, title, color) in cats)
              if (d.history.first.coupons[key] != null)
                V2CouponCard(title: title, coupon: d.history.first.coupons[key], accent: color),
          ],
        ] else ...[
          for (final (key, title, color) in cats) ...[
            V2CouponCard(
              title: title,
              coupon: t.coupons[key],
              accent: color,
              codeKey: key,
              codeDay: t.day,
              week: hideHist ? null : dayCat(key, title).period(d, monday, monday.add(Duration(days: 7))),
              onHistory: hideHist ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => V2HistoryScreen(dayCat(key, title), d))),
            ),
            if (free && key == 'single') KndBanner(),
          ],
          if (!free) KndBanner(),
        ],
        SizedBox(height: 6),
        T('18+ · Aucun gain garanti · Joue de manière responsable.',
            textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5)),
      ]),
    );
  }
}
