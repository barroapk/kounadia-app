import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../widgets/forecast_card.dart' show K, hm, frDay;
import '../account_screen.dart';

String v2Num(double v, [int dec = 2]) => v.toStringAsFixed(dec).replaceAll('.', ',');
String v2Pct(double v) => '${v.round()} %';

Color v2Color(String? r) => r == 'won'
    ? K.green
    : r == 'lost'
        ? K.red
        : r == 'live'
            ? K.amber
            : r == 'void'
                ? K.muted
                : K.pending;

Widget v2ResultBadge(String? r, {double size = 12}) {
  if (r == null) return SizedBox.shrink();
  final (txt, icon) = switch (r) {
    'won' => ('Gagné', Icons.check_circle_rounded),
    'lost' => ('Perdu', Icons.cancel_rounded),
    'live' => ('En cours', Icons.play_circle_fill_rounded),
    _ => ('Annulé', Icons.remove_circle_rounded),
  };
  final c = v2Color(r);
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: c.withAlpha(36), borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: c, size: size + 2),
      SizedBox(width: 4),
      T(txt, style: TextStyle(color: c, fontSize: size, fontWeight: FontWeight.w800)),
    ]),
  );
}

/// Bilan 14 jours : « 9 gagnés · 1 perdu · 90 % ».
Widget v2StatLine(V2Stat s, {VoidCallback? onHistory}) {
  final txt = s.total == 0
      ? tr('Bilan 14 jours : pas encore de résultat')
      : '${tr('Bilan 14 jours')} : ${s.won} ${tr(s.won > 1 ? 'gagnés' : 'gagné')} · ${s.lost} ${tr(s.lost > 1 ? 'perdus' : 'perdu')} · ${s.pct?.round() ?? 0} %';
  return InkWell(
    onTap: onHistory,
    child: Padding(
      padding: EdgeInsets.fromLTRB(12, 9, 8, 9),
      child: Row(children: [
        Icon(Icons.insights_rounded, color: K.indigoText, size: 16),
        SizedBox(width: 7),
        Expanded(child: Text(txt, style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600))),
        if (onHistory != null) ...[
          T('Historique', style: TextStyle(color: K.indigoText, fontSize: 12.5, fontWeight: FontWeight.w800)),
          Icon(Icons.chevron_right_rounded, color: K.indigoText, size: 18),
        ],
      ]),
    ),
  );
}

/// Ligne d'un événement : heure, match, pari (code + texte), confiance KOUNADIA, cote, résultat.
class V2LegRow extends StatefulWidget {
  final V2Leg leg;
  final bool showDay;
  V2LegRow(this.leg, {super.key, this.showDay = false});

  @override
  State<V2LegRow> createState() => _V2LegRowState();
}

class _V2LegRowState extends State<V2LegRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.leg;
    final c = v2Color(l.r);
    final d = l.date;
    Widget time;
    if (l.r == 'won' || l.r == 'lost' || l.r == 'void') {
      time = Icon(l.r == 'won' ? Icons.check_circle_rounded : l.r == 'lost' ? Icons.cancel_rounded : Icons.remove_circle_rounded,
          color: c, size: 22);
    } else if (l.r == 'live') {
      time = T('En\ncours', textAlign: TextAlign.center, style: TextStyle(color: K.amber, fontSize: 11, fontWeight: FontWeight.w800, height: 1.1));
    } else {
      time = Text(d == null ? '--:--' : hm(d), style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700));
    }
    return InkWell(
      onTap: l.why.isEmpty ? null : () => setState(() => _open = !_open),
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 9, 12, 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 44, child: Padding(padding: EdgeInsets.only(top: 2), child: Center(child: time))),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${l.home} - ${l.away}${l.score != null ? '  (${l.score})' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text(
                    [if (widget.showDay && d != null) frDay(d), if (l.league.isNotEmpty) l.league].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.muted, fontSize: 11.5)),
                SizedBox(height: 6),
                Row(children: [
                  if (l.code.isNotEmpty) ...[
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(color: K.indigoSoft, borderRadius: BorderRadius.circular(6)),
                      child: Text(l.code, style: TextStyle(color: K.indigoText, fontSize: 12.5, fontWeight: FontWeight.w900)),
                    ),
                    SizedBox(width: 7),
                  ],
                  Expanded(
                    child: T(l.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: c, fontSize: 13.5, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ]),
            ),
            SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(v2Pct(l.p), style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w900)),
              SizedBox(height: 2),
              Text('${l.est ? '≈' : '@'} ${v2Num(l.odd)}', style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              if (l.why.isNotEmpty)
                Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: K.muted, size: 18),
            ]),
          ]),
          if (_open && l.why.isNotEmpty)
            Container(
              margin: EdgeInsets.only(left: 44, top: 8),
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(color: K.bg, borderRadius: BorderRadius.circular(10)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                T('Pourquoi ce choix', style: TextStyle(color: K.text, fontSize: 12, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                for (final w in l.why)
                  Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text('• $w', style: TextStyle(color: K.muted, fontSize: 12, height: 1.35)),
                  ),
                if (l.est)
                  Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: T('≈ : cote estimée par KOUNADIA. Vérifie la cote chez ton bookmaker.',
                        style: TextStyle(color: K.muted, fontSize: 11, fontStyle: FontStyle.italic)),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Carte d'un coupon : titre, cote totale, chance KOUNADIA, événements, bilan 14 jours.
class V2CouponCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final V2Coupon? coupon;
  final V2Stat? stat;
  final VoidCallback? onHistory;
  final Color accent;
  final bool showDay;
  V2CouponCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.coupon,
    this.stat,
    this.onHistory,
    this.accent = const Color(0xFF4F46E5),
    this.showDay = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = coupon;
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [accent.withAlpha(70), accent.withAlpha(18)])),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                T(title, style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900)),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  T(subtitle!, style: TextStyle(color: K.muted, fontSize: 12)),
                ],
              ]),
            ),
            if (c != null)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('@ ${v2Num(c.odd)}', style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900)),
                Text('${tr('Chance KOUNADIA')} ${v2Pct(c.p)}', style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ]),
          ]),
        ),
        if (c == null)
          Padding(
            padding: EdgeInsets.all(16),
            child: T("Pas assez de matchs fiables aujourd'hui pour ce coupon.",
                style: TextStyle(color: K.muted, fontSize: 13.5)),
          )
        else if (c.locked)
          _locked(context, c)
        else ...[
          if (c.r != null)
            Padding(padding: EdgeInsets.fromLTRB(12, 10, 12, 0), child: Align(alignment: Alignment.centerLeft, child: v2ResultBadge(c.r))),
          for (var i = 0; i < c.legs.length; i++) ...[
            if (i > 0) Container(height: 1, color: K.border),
            V2LegRow(c.legs[i], showDay: showDay),
          ],
        ],
        if (stat != null) ...[
          Container(height: 1, color: K.border),
          v2StatLine(stat!, onHistory: onHistory),
        ],
      ]),
    );
  }

  Widget _locked(BuildContext context, V2Coupon c) => Padding(
        padding: EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.lock_rounded, color: Color(0xFFD4A017), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('${c.n} ${tr(c.n > 1 ? 'événements' : 'événement')} · ${tr('réservé aux abonnés Premium')}',
                  style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            if (c.r != null) v2ResultBadge(c.r),
          ]),
          SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Color(0xFFD4A017), foregroundColor: Colors.black, minimumSize: Size.fromHeight(44)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountScreen())),
            icon: Icon(Icons.workspace_premium_rounded),
            label: T('Débloquer avec Premium', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ]),
      );
}
