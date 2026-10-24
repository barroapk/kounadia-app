import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../services/account.dart';
import '../../services/v2_service.dart';
import '../../widgets/forecast_card.dart' show K, frDay, kHonest, kMessage, kOfflineBanner;
import '../../widgets/knd_banner.dart';
import 'v2_history_screen.dart';
import 'v2_widgets.dart';

/// Une rubrique du menu ☰ de la Sélection du jour.
class SelFilter {
  final String key, title;
  final IconData icon;
  final String? fam; // catégorie d'événements
  final String? coupon; // c2, c5, c10
  const SelFilter(this.key, this.title, this.icon, {this.fam, this.coupon});

  String get statKey => coupon != null
      ? 'sel_$coupon'
      : key == 'all'
          ? 'sel_top'
          : 'fam_$key';

  List<V2Leg> legs(V2Selection s) {
    if (key == 'all') return s.top;
    if (key == 'fav') return s.fav;
    return s.byFam.where((l) => l.fam == fam).toList()..sort((a, b) => b.p.compareTo(a.p));
  }

  V2Cat cat() => V2Cat(statKey, title,
      coupon: coupon == null ? null : (d) => d.selection?.coupons[coupon],
      legs: coupon != null ? null : (d) => d.selection == null ? const <V2Leg>[] : legs(d.selection!));
}

const kSelFilters = <SelFilter>[
  SelFilter('all', 'Tous', Icons.apps_rounded),
  SelFilter('dc', 'Double chance (1X · X2 · 12)', Icons.shield_rounded, fam: 'dc'),
  SelFilter('res', 'Victoire (1 · 2)', Icons.emoji_events_rounded, fam: 'res'),
  SelFilter('fav', 'Favoris', Icons.star_rounded),
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

  @override
  void initState() {
    super.initState();
    _f = V2Service.shared();
    Account.user.addListener(_userChanged);
  }

  @override
  void dispose() {
    Account.user.removeListener(_userChanged);
    super.dispose();
  }

  void _userChanged() {
    if (mounted) setState(() => _f = V2Service.shared(force: true));
  }

  Future<void> _reload() async {
    final f = V2Service.shared(force: true);
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  int _count(V2Selection s, SelFilter f) =>
      f.coupon != null ? (s.coupons[f.coupon] == null ? 0 : 1) : f.legs(s).length;

  /// Menu ☰ : liste verticale qui occupe une partie de l'écran (le reste reste visible).
  Future<void> _openMenu(V2Data d) async {
    final s = d.today?.selection;
    final w = MediaQuery.of(context).size.width;
    final panel = (w * 0.42).clamp(170.0, 260.0).toDouble();
    final picked = await showGeneralDialog<SelFilter>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'menu',
      barrierColor: Colors.black.withAlpha(110),
      transitionDuration: Duration(milliseconds: 200),
      pageBuilder: (ctx, _, __) => Align(
        alignment: isRtl ? Alignment.centerRight : Alignment.centerLeft,
        child: Material(
          color: K.card,
          child: SafeArea(
            child: SizedBox(
              width: panel,
              height: double.infinity,
              child: ListView(padding: EdgeInsets.symmetric(vertical: 8), children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(14, 6, 10, 10),
                  child: T('Trier la sélection', style: TextStyle(color: K.text, fontSize: 15, fontWeight: FontWeight.w900)),
                ),
                for (final f in kSelFilters)
                  _menuItem(ctx, f, s == null ? null : _count(s, f)),
              ]),
            ),
          ),
        ),
      ),
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
        padding: EdgeInsets.fromLTRB(14, 11, 10, 11),
        child: Row(children: [
          Icon(f.icon, size: 18, color: on ? K.indigoText : empty ? K.border : K.muted),
          SizedBox(width: 10),
          Expanded(
            child: T(f.title,
                style: TextStyle(color: empty ? K.muted : K.text, fontSize: 13, fontWeight: on ? FontWeight.w900 : FontWeight.w600)),
          ),
          if (n != null && f.coupon == null)
            Text('$n', style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<V2Data>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: K.indigo));
        }
        if (snap.hasError) return kMessage(snap.error.toString(), onRetry: _reload);
        final d = snap.data!;
        final s = d.today?.selection;
        final f = _sel;
        final body = <Widget>[];
        if (s == null || s.locked) {
          body.add(SizedBox(height: 300, child: kMessage('La Sélection du jour arrive chaque matin. Tire vers le bas pour actualiser.')));
        } else if (f.coupon != null) {
          body.add(V2CouponCard(
            title: f.title,
            subtitle: 'Uniquement avec des événements de la Sélection du jour',
            coupon: s.coupons[f.coupon],
            stat: d.stat(f.statKey),
            accent: f.coupon == 'c10' ? Color(0xFFDC2626) : f.coupon == 'c5' ? Color(0xFFEA580C) : Color(0xFF4F46E5),
            onHistory: () => _history(d, f),
          ));
        } else {
          final legs = f.legs(s);
          body.add(Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (legs.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16),
                  child: T("Aucun événement assez sûr dans cette catégorie aujourd'hui.", style: TextStyle(color: K.muted, fontSize: 13.5)),
                ),
              for (var i = 0; i < legs.length; i++) ...[
                if (i > 0) Container(height: 1, color: K.border),
                V2LegRow(legs[i]),
              ],
              Container(height: 1, color: K.border),
              v2StatLine(d.stat(f.statKey), onHistory: () => _history(d, f)),
            ]),
          ));
        }
        return RefreshIndicator(
          color: K.indigo,
          onRefresh: _reload,
          child: ListView(padding: EdgeInsets.fromLTRB(14, 10, 14, 96), children: [
            if (d.offline) kOfflineBanner(),
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
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  T(f.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
                  if (d.today?.date != null)
                    Text('${tr('Sélection du jour')} · ${frDay(d.today!.date!)}',
                        style: TextStyle(color: K.muted, fontSize: 12)),
                ]),
              ),
            ]),
            SizedBox(height: 8),
            T('Événements choisis par la confiance KOUNADIA (65 % et plus), sur des matchs différents du Coupon du jour. Touche un événement pour voir pourquoi.',
                style: TextStyle(color: K.muted, fontSize: 12, height: 1.35)),
            SizedBox(height: 12),
            ...body,
            SizedBox(height: 10),
            KndBanner(),
            SizedBox(height: 8),
            T(kHonest, textAlign: TextAlign.center, style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.4)),
          ]),
        );
      },
    );
  }

  void _history(V2Data d, SelFilter f) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => V2HistoryScreen(f.cat(), d)));
}
