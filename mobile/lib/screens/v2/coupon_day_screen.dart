import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../services/account.dart';
import '../../services/v2_service.dart';
import '../../widgets/forecast_card.dart' show K, frDay, hm, kHonest, kMessage, kOfflineBanner;
import '../../widgets/knd_banner.dart';
import 'v2_history_screen.dart';
import 'v2_widgets.dart';

/// Les 5 coupons du jour : 2 gratuits, 3 VIP.
final kDayCats = <(String, String, String, Color)>[
  ('single', 'Single du jour', 'Un seul match, le plus sûr du jour', Color(0xFF16A34A)),
  ('free', 'Coupon gratuit', '2 à 3 événements, cote autour de 1,5', Color(0xFF0EA5E9)),
  ('vip2', 'VIP · Cote 2 à 2,5', 'Sélection Premium', Color(0xFFD4A017)),
  ('vip3', 'VIP · Cote 3 à 3,5', 'Sélection Premium', Color(0xFFEA580C)),
  ('vip5', 'VIP · Cote 5 à 5,5', 'Sélection Premium · plus risqué', Color(0xFFDC2626)),
];

V2Cat dayCat(String key, String title) => V2Cat(key, title, coupon: (d) => d.coupons[key]);

class CouponDayScreen extends StatefulWidget {
  CouponDayScreen({super.key});

  @override
  State<CouponDayScreen> createState() => _CouponDayScreenState();
}

class _CouponDayScreenState extends State<CouponDayScreen> with AutomaticKeepAliveClientMixin {
  late Future<V2Data> _f;
  bool? _prem;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _f = V2Service.shared();
    _prem = Account.premium;
    Account.user.addListener(_userChanged);
  }

  @override
  void dispose() {
    Account.user.removeListener(_userChanged);
    super.dispose();
  }

  void _userChanged() {
    if (_prem == Account.premium || !mounted) return;
    _prem = Account.premium;
    setState(() => _f = V2Service.shared(force: true));
  }

  Future<void> _reload() async {
    final f = V2Service.shared(force: true);
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<V2Data>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: K.indigo));
        }
        if (snap.hasError) return kMessage(snap.error.toString(), onRetry: _reload);
        final d = snap.data!;
        final t = d.today;
        final five = DateTime.utc(2000, 1, 1, 5, 15).toLocal(); // calcul officiel du robot : 05:12 GMT
        return RefreshIndicator(
          color: K.indigo,
          onRefresh: _reload,
          child: ListView(padding: EdgeInsets.fromLTRB(14, 12, 14, 96), children: [
            if (d.offline) kOfflineBanner(),
            Row(children: [
              Expanded(
                child: Text(t?.date == null ? tr('Coupon du jour') : '${tr('Coupon du jour')} · ${frDay(t!.date!)}',
                    style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              if (t != null)
                Text('${t.matches} ${tr('matchs analysés')}', style: TextStyle(color: K.muted, fontSize: 12)),
            ]),
            SizedBox(height: 4),
            T('Chaque pari est choisi pour sa forte chance de passer, à partir de 1,15. Les coupons sont publiés chaque matin et ne changent plus.',
                style: TextStyle(color: K.muted, fontSize: 12.5, height: 1.35)),
            SizedBox(height: 14),
            if (t == null)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
                child: Text('${tr('Les coupons du jour arrivent chaque matin vers')} ${hm(five)}.',
                    style: TextStyle(color: K.text, fontSize: 14)),
              )
            else ...[
              _section('Gratuit'),
              for (final c in kDayCats.take(2)) _card(d, t, c),
              KndBanner(),
              SizedBox(height: 6),
              _section('VIP'),
              for (final c in kDayCats.skip(2)) _card(d, t, c),
            ],
            SizedBox(height: 8),
            T(kHonest, textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.4)),
          ]),
        );
      },
    );
  }

  Widget _section(String t) => Padding(
        padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: T(t.toUpperCase(), style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
      );

  Widget _card(V2Data d, V2Day t, (String, String, String, Color) c) {
    final (key, title, sub, color) = c;
    return V2CouponCard(
      title: title,
      subtitle: sub,
      coupon: t.coupons[key],
      stat: d.stat(key),
      accent: color,
      onHistory: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => V2HistoryScreen(dayCat(key, title), d))),
    );
  }
}
