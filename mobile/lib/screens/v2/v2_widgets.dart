import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/coupon.dart' show Coupon, Leg;
import '../../widgets/coupon_receipt.dart' show shareCoupon;
import '../../l10n/tr.dart';
import '../../models/v2.dart';
import '../../services/analytics.dart';
import '../../services/codes.dart';
import '../../services/logo_cache.dart';
import '../../widgets/forecast_card.dart' show K, hm;
import '../../widgets/jersey.dart';
import '../account_screen.dart';

/// Coupon du jour → coupon partageable en image (même reçu que « Créer coupon »).
Coupon v2ToCoupon(V2Coupon c) => Coupon(DateTime.now(), [
      for (final l in c.legs)
        Leg(
          matchId: l.ptId ?? 0,
          home: l.home,
          away: l.away,
          league: l.leagueLabel,
          flag: l.flag ?? '',
          pick: l.mk,
          odd: l.odd,
          prob: l.p.round(),
          date: l.date,
          txt: l.label,
          est: l.est,
          result: l.r ?? 'pending',
          score: l.score,
        ),
    ]);

/// Prochains coupons : compte à rebours jusqu'à 05:00 (heure de calcul du moteur).
class V2NextCountdown extends StatefulWidget {
  V2NextCountdown({super.key});
  @override
  State<V2NextCountdown> createState() => _V2NextCountdownState();
}

class _V2NextCountdownState extends State<V2NextCountdown> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    var next = DateTime.utc(now.year, now.month, now.day, 5, 10);
    if (!now.isBefore(next)) next = next.add(Duration(days: 1));
    final left = next.difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    final txt = '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}';
    final p = 1 - left.inSeconds / 86400;
    return Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        SizedBox(
          width: 58,
          height: 58,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(value: p.clamp(0.0, 1.0), strokeWidth: 5, color: Colors.white, backgroundColor: Color(0x33FFFFFF)),
            Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 24),
          ]),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            T('Nouveaux coupons dans', style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 13, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text(txt, style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()])),
          ]),
        ),
      ]),
    );
  }
}

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

/// Ligne « Résultats d'hier · Historique › » (sans statistiques de la semaine).
Widget v2WeekLine((int, int) week, {VoidCallback? onHistory}) {
  return InkWell(
    onTap: onHistory,
    child: Padding(
      padding: EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(children: [
        Icon(Icons.calendar_month_rounded, color: K.indigoText, size: 16),
        SizedBox(width: 7),
        T("Résultats d'hier", style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
        Spacer(),
        if (onHistory != null) ...[
          T('Historique', style: TextStyle(color: K.indigoText, fontSize: 12.5, fontWeight: FontWeight.w800)),
          Icon(Icons.chevron_right_rounded, color: K.indigoText, size: 18),
        ],
      ]),
    ),
  );
}

/// Drapeau du championnat.
Widget v2Flag(String? url) => url == null || url.isEmpty
    ? Icon(Icons.emoji_events_outlined, color: K.amber, size: 15)
    : ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CachedNetworkImage(
            imageUrl: url, width: 18, height: 13, fit: BoxFit.cover, errorWidget: (_, __, ___) => SizedBox(width: 18)),
      );

/// En-tête de championnat (comme l'onglet Matchs).
Widget v2LeagueHead(V2Leg l, {bool live = false}) => Container(
      color: K.groupHead,
      padding: EdgeInsets.fromLTRB(12, 9, 10, 9),
      child: Row(children: [
        v2Flag(l.flag),
        SizedBox(width: 8),
        Expanded(
          child: T(l.leagueLabel.isEmpty ? 'Football' : l.leagueLabel,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
        if (live) Container(width: 7, height: 7, decoration: BoxDecoration(color: K.red, shape: BoxShape.circle)),
      ]),
    );

/// Groupe de cartes d'un même championnat.
class V2Group extends StatelessWidget {
  final List<V2Leg> legs;
  final Set<String>? favs;
  final void Function(V2Leg)? onStar;
  V2Group(this.legs, {super.key, this.favs, this.onStar});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: K.border)),
      child: Column(children: [
        v2LeagueHead(legs.first, live: legs.any((l) => l.r == 'live')),
        for (var i = 0; i < legs.length; i++) ...[
          if (i > 0) Container(height: 1, color: K.border),
          V2MatchRow(legs[i], fav: favs?.contains(legs[i].key), onStar: onStar),
        ],
      ]),
    );
  }
}

/// Regroupe des événements par championnat (dans l'ordre des heures).
List<Widget> v2Groups(List<V2Leg> legs, {Set<String>? favs, void Function(V2Leg)? onStar}) {
  final sorted = [...legs]..sort((a, b) => (a.date ?? DateTime(2100)).compareTo(b.date ?? DateTime(2100)));
  final groups = <String, List<V2Leg>>{};
  for (final l in sorted) {
    groups.putIfAbsent(l.leagueLabel, () => []).add(l);
  }
  return [for (final g in groups.values) V2Group(g, favs: favs, onStar: onStar)];
}

/// Carte d'un match avec son pari : logos, heure ou minute, score (ou statistique), code du pari, confiance, cote.
class V2MatchRow extends StatelessWidget {
  final V2Leg leg;
  final bool showLeague;
  final bool? fav;
  final void Function(V2Leg)? onStar;
  V2MatchRow(this.leg, {super.key, this.showLeague = false, this.fav, this.onStar});

  (int?, int?) _nums() {
    final pair = leg.statPair;
    if (pair != null) return (pair[0], pair[1]);
    final m = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(leg.score ?? '');
    return m == null ? (null, null) : (int.parse(m[1]!), int.parse(m[2]!));
  }

  Widget _team(String name, String? logo, int? n, bool win) => Row(children: [
        TeamCrest(name: name, logo: logo ?? LogoCache.get(name), size: 18),
        SizedBox(width: 7),
        Expanded(
          child: Text(name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: win ? FontWeight.w900 : FontWeight.w600)),
        ),
        if (n != null) ...[
          SizedBox(width: 6),
          Text('$n', style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w900)),
        ],
      ]);

  @override
  Widget build(BuildContext context) {
    final l = leg;
    final c = v2Color(l.r);
    final (h, a) = _nums();
    final done = l.r == 'won' || l.r == 'lost' || l.r == 'void';
    Widget time;
    if (done) {
      time = Icon(l.r == 'won' ? Icons.check_circle_rounded : l.r == 'lost' ? Icons.cancel_rounded : Icons.remove_circle_rounded,
          color: c, size: 20);
    } else if (l.r == 'live') {
      time = Text(l.minute ?? 'Live', textAlign: TextAlign.center, style: TextStyle(color: K.red, fontSize: 12, fontWeight: FontWeight.w900));
    } else {
      time = Text(l.date == null ? '--:--' : hm(l.date!), style: TextStyle(color: K.text, fontSize: 12.5, fontWeight: FontWeight.w800));
    }
    final pair = l.statPair;
    final String? statLine = pair != null && pair[0] != null && pair[1] != null
        ? '${tr(l.statName!)} : ${pair[0]! + pair[1]!}'
        : (l.fam == 'mt' && l.h1 != null ? '${tr('Mi-temps')} : ${l.h1![0]}-${l.h1![1]}' : null);
    return InkWell(
      onTap: () => showV2Why(context, l),
      child: Container(
        color: l.r == 'live' ? Color(0x14EF4444) : null,
        padding: EdgeInsets.fromLTRB(6, 7, 8, 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showLeague)
            Padding(
              padding: EdgeInsets.only(left: 42, bottom: 4),
              child: Row(children: [
                v2Flag(l.flag),
                SizedBox(width: 6),
                Expanded(
                  child: T(l.leagueLabel,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(width: 40, child: Center(child: time)),
            SizedBox(width: 4),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _team(l.home, l.hl, h, h != null && a != null && h > a && pair == null),
                SizedBox(height: 3),
                _team(l.away, l.al, a, h != null && a != null && a > h && pair == null),
                if (statLine != null) ...[
                  SizedBox(height: 5),
                  Text(statLine, style: TextStyle(color: K.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                ],
              ]),
            ),
            SizedBox(width: 10),
            SizedBox(
              width: 104,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (l.code.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: c.withAlpha(40), borderRadius: BorderRadius.circular(6)),
                      child: Text(l.code, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900)),
                    ),
                  if (onStar != null) ...[
                    SizedBox(width: 4),
                    // Étoile bien visible : touche pour suivre ce pari dans « Mes favoris ».
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => onStar!(l),
                      child: Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(fav == true ? Icons.star_rounded : Icons.star_border_rounded, color: K.amber, size: 23),
                      ),
                    ),
                  ],
                ]),
                SizedBox(height: 4),
                T(l.label,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c, fontSize: 11.5, fontWeight: FontWeight.w800, height: 1.15)),
                SizedBox(height: 2),
                Text('${v2Pct(l.p)} · ${l.est ? '≈' : '@'}${v2Num(l.odd)}',
                    style: TextStyle(color: K.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                if (l.ex) ...[
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: K.green.withAlpha(36), borderRadius: BorderRadius.circular(6)),
                    child: T('✓ Expert', style: TextStyle(color: K.green, fontSize: 11, fontWeight: FontWeight.w900)),
                  ),
                ],
              ]),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Aucune source nommée dans les explications (anciennes journées comprises).
String v2CleanWhy(String w) => w
    .replaceAll("PrimaTips est d'accord", "Une 2e analyse indépendante est d'accord")
    .replaceAll('Nos analystes Expert', 'Nos analystes');

/// « Pourquoi ce choix » : en bref, en français facile, avec les données visibles.
void showV2Why(BuildContext context, V2Leg l) {
  final c = v2Color(l.r);
  final rows = <(String, String)>[
    if (l.score != null) ('Score', l.score!.replaceAll('-', ' - ')),
    if (l.h1 != null) ('Mi-temps', '${l.h1![0]} - ${l.h1![1]}'),
    for (final e in const [('c', 'Corners'), ('f', 'Fautes'), ('s', 'Tirs'), ('t', 'Tirs cadrés')])
      if (l.st[e.$1] != null && l.st[e.$1]![0] != null && l.st[e.$1]![1] != null)
        (e.$2, '${l.st[e.$1]![0]} - ${l.st[e.$1]![1]}'),
  ];
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: K.card,
    showDragHandle: true,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            v2Flag(l.flag),
            SizedBox(width: 8),
            Expanded(child: T(l.leagueLabel, style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w700))),
            if (l.date != null) Text(hm(l.date!), style: TextStyle(color: K.muted, fontSize: 12.5)),
          ]),
          SizedBox(height: 10),
          Text('${l.home} - ${l.away}', style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              if (l.code.isNotEmpty) ...[
                Text(l.code, style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
                SizedBox(width: 10),
              ],
              Expanded(child: T(l.label, style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w800))),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(v2Pct(l.p), style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w900)),
                Text('${l.est ? '≈' : '@'} ${v2Num(l.odd)}', style: TextStyle(color: K.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ]),
            ]),
          ),
          if (l.r != null) ...[SizedBox(height: 10), v2ResultBadge(l.r)],
          if (rows.isNotEmpty) ...[
            SizedBox(height: 14),
            for (final (k, v) in rows)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: T(k, style: TextStyle(color: K.muted, fontSize: 13.5))),
                  Text(v, style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w800)),
                ]),
              ),
          ],
          if (l.why.isNotEmpty) ...[
            SizedBox(height: 14),
            T('Pourquoi ce choix', style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            for (final w in l.why)
              Padding(
                padding: EdgeInsets.only(top: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: EdgeInsets.only(top: 6), child: Icon(Icons.circle, size: 6, color: K.indigoText)),
                  SizedBox(width: 8),
                  Expanded(child: Text(v2CleanWhy(w), style: TextStyle(color: K.text, fontSize: 13.5, height: 1.4))),
                ]),
              ),
          ],
        ]),
      ),
    ),
  );
}

/// Carte d'un coupon : titre, cote totale, résultat, matchs (chacun avec son championnat), bilan de la semaine.
class V2CouponCard extends StatelessWidget {
  final String title;
  final V2Coupon? coupon;
  final (int, int)? week;
  final VoidCallback? onHistory;
  final Color accent;
  // Code 1xBet du coupon (saisi dans KOUNADIA Admin) : clé du coupon et jour.
  final String? codeKey;
  final String? codeDay;
  V2CouponCard(
      {super.key,
      required this.title,
      required this.coupon,
      this.week,
      this.onHistory,
      this.accent = const Color(0xFF4F46E5),
      this.codeKey,
      this.codeDay});

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
          decoration: BoxDecoration(gradient: LinearGradient(colors: [accent.withAlpha(80), accent.withAlpha(20)])),
          child: Row(children: [
            Expanded(child: T(title, style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w900))),
            if (c?.r != null) ...[v2ResultBadge(c!.r), SizedBox(width: 8)],
            if (c != null) Text('@ ${v2Num(c.odd)}', style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900)),
            if (c != null && !c.locked && c.legs.isNotEmpty)
              IconButton(
                tooltip: tr('Partager'),
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.share_rounded, color: K.text, size: 22),
                onPressed: () => shareCoupon(context, v2ToCoupon(c)),
              ),
          ]),
        ),
        if (c == null)
          Padding(
            padding: EdgeInsets.all(16),
            child: T("Pas de coupon pour cette cote aujourd'hui.", style: TextStyle(color: K.muted, fontSize: 13.5)),
          )
        else if (c.locked)
          _locked(context, c)
        else
          for (var i = 0; i < c.legs.length; i++) ...[
            if (i > 0) Container(height: 1, color: K.border),
            V2MatchRow(c.legs[i], showLeague: true),
          ],
        // Code 1xBet : affiché sur le coupon du jour (avant, pendant et après les matchs).
        if (c != null && !c.locked && codeKey != null)
          ValueListenableBuilder<Map<String, String>>(
            valueListenable: Codes.data,
            builder: (_, __, ___) {
              final code = Codes.of(codeKey!, codeDay);
              if (code == null) return SizedBox.shrink();
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(height: 1, color: K.border),
                V2CodeRow(code: code, kind: codeKey!),
              ]);
            },
          ),
        if (week != null) ...[
          Container(height: 1, color: K.border),
          v2WeekLine(week!, onHistory: onHistory),
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
              child: Text('${c.n} ${tr(c.n > 1 ? 'matchs' : 'match')} · Premium',
                  style: TextStyle(color: K.text, fontSize: 14, fontWeight: FontWeight.w800)),
            ),
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

/// Code 1xBet d'un coupon : l'utilisateur le copie puis le charge dans 1xBet (Coupon › Charger).
class V2CodeRow extends StatelessWidget {
  final String code;
  final String kind;
  V2CodeRow({super.key, required this.code, required this.kind});

  static const _blue = Color(0xFF1A73E8);

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: code));
    Analytics.log('code_copy', {'k': kind});
    Analytics.log('code_copy_$kind');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      duration: Duration(seconds: 5),
      content: T('Code $code copié. Dans 1xBet : Coupon › Charger un coupon, puis colle le code.'),
    ));
  }

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => _copy(context),
        child: Container(
          color: _blue.withAlpha(26),
          padding: EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            Icon(Icons.confirmation_number_rounded, color: _blue, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                T('Code coupon 1xBet', style: TextStyle(color: K.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(code,
                      style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1.6, fontFamily: 'monospace')),
                ),
              ]),
            ),
            SizedBox(width: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => _copy(context),
              icon: Icon(Icons.copy_rounded, size: 17),
              label: T('Copier', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ]),
        ),
      );
}

/// Message sans détail technique (connexion, données absentes…).
const kV2Unavailable = 'Les données ne sont pas disponibles pour le moment. Tire vers le bas pour réessayer.';
