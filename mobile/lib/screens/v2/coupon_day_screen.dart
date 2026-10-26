import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../services/account.dart';
import '../../services/v2_live.dart';
import '../../services/v2_service.dart';
import '../../widgets/forecast_card.dart' show K, hm, kMessage, kOfflineBanner;
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
  }

  Future<V2Data> _load({bool force = false}) async {
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
        Container(
          color: K.bg,
          child: TabBar(
            labelColor: K.text,
            unselectedLabelColor: K.muted,
            indicatorColor: K.indigo,
            labelStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
            tabs: [Tab(text: tr('Coupons gratuits')), Tab(text: tr('Coupons VIP'))],
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
    final five = DateTime.utc(2000, 1, 1, 5, 15).toLocal();
    return RefreshIndicator(
      color: K.indigo,
      onRefresh: _reload,
      child: ListView(physics: AlwaysScrollableScrollPhysics(), padding: EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
        if (d.offline) kOfflineBanner(),
        if (t == null)
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
            child: Text('${tr('Les coupons du jour arrivent chaque matin vers')} ${hm(five)}.',
                style: TextStyle(color: K.text, fontSize: 14)),
          )
        else ...[
          for (final (key, title, color) in cats) ...[
            V2CouponCard(
              title: title,
              coupon: t.coupons[key],
              accent: color,
              week: dayCat(key, title).period(d, monday, monday.add(Duration(days: 7))),
              onHistory: () => Navigator.push(context, MaterialPageRoute(builder: (_) => V2HistoryScreen(dayCat(key, title), d))),
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
