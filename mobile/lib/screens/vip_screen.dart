import 'package:flutter/material.dart';
import '../models/coupon.dart' show fx;
import '../models/vip.dart';
import '../services/vip_service.dart';
import '../widgets/coupon_receipt.dart';
import '../widgets/forecast_card.dart' show K, hm, two, frDay, kMessage, kOfflineBanner;
import '../widgets/jersey.dart';
import '../widgets/knd_banner.dart';
import '../widgets/vip_reliability.dart';

class VipScreen extends StatefulWidget {
  final bool standalone;
  VipScreen({super.key, this.standalone = false});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  late Future<VipData> _f = VipService.load();
  int _view = 0;

  Future<void> _refresh() async {
    setState(() => _f = VipService.load());
    try {
      await _f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final body = FutureBuilder<VipData>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Center(child: CircularProgressIndicator(color: K.indigo));
        }
        if (snap.hasError) return kMessage(snap.error.toString(), onRetry: _refresh);
        final d = snap.data!;
        final children = <Widget>[
          if (d.offline) kOfflineBanner(),
          _switch(d.history.length),
          SizedBox(height: 12),
          if (_view == 0) ..._today(d.today) else ..._history(d.history),
          SizedBox(height: 14),
          Text(
            "Indice de confiance calculé par KOUNADIA à partir des probabilités, des statistiques, de la forme, "
            "du classement et des cotes. Aucun coupon n'est garanti. 18+ · Jouez de manière responsable.",
            textAlign: TextAlign.center,
            style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.4),
          ),
        ];
        return RefreshIndicator(
          color: K.indigo,
          backgroundColor: K.card,
          onRefresh: _refresh,
          child: ListView(
            physics: AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: children,
          ),
        );
      },
    );
    if (!widget.standalone) return Scaffold(backgroundColor: K.bg, body: body);
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        foregroundColor: K.text,
        title: Text('Coupon VIP', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: body,
    );
  }

  Widget _switch(int nHist) {
    Widget half(String label, int v) {
      final sel = _view == v;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _view = v),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 150),
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: sel ? K.indigo : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(label,
                style: TextStyle(color: sel ? Colors.white : K.muted, fontSize: 13.5, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: K.border),
      ),
      child: Row(children: [half('VIP du jour', 0), half('Historique · $nHist', 1)]),
    );
  }

  Widget _hero(VipDay? d) {
    final date = d == null ? null : DateTime.tryParse(d.date);
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F1A0E), Color(0xFF8A6A12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Color(0x66F5C542)),
      ),
      child: Row(children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(color: Color(0x33F5C542), shape: BoxShape.circle),
          child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFF5C542), size: 30),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Coupon VIP du jour',
                style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
            SizedBox(height: 4),
            Text(
              date == null
                  ? 'Publié chaque matin à 6h · matchs de 8h à 4h'
                  : '${frDay(date)} · ${d!.analyzed} matchs analysés · ${d!.coupons.length} coupons',
              style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12.5, height: 1.35),
            ),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _today(VipDay? d) {
    final now = DateTime.now();
    final ymd = '${now.year}-${two(now.month)}-${two(now.day)}';
    final children = <Widget>[_hero(d), SizedBox(height: 12), VipReliability(), SizedBox(height: 14), KndBanner()];
    if (d == null || d.coupons.isEmpty) {
      children.addAll([
        SizedBox(height: 30),
        kMessage('Les coupons VIP du jour sont publiés chaque matin à 6h.\nRevenez un peu plus tard.'),
      ]);
      return children;
    }
    if (d.date != ymd) {
      children.add(Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('Coupons en cours (publiés le ${d.date.split('-').reversed.join('/')}) · nouveaux coupons à 6h',
            style: TextStyle(color: K.amber, fontSize: 12.5, fontWeight: FontWeight.w700)),
      ));
    }
    if (d.singles.isNotEmpty) {
      children
        ..add(VipSinglesCard(legs: d.singles))
        ..add(SizedBox(height: 12));
    }
    for (final c in d.coupons) {
      children
        ..add(VipCouponCard(coupon: c, expanded: true))
        ..add(SizedBox(height: 12));
    }
    return children;
  }

  List<Widget> _history(List<VipDay> h) {
    if (h.isEmpty) {
      return [KndBanner(), SizedBox(height: 30), kMessage("L'historique des coupons VIP apparaîtra ici dès demain.")];
    }
    final out = <Widget>[KndBanner()];
    for (final d in h) {
      final date = DateTime.tryParse(d.date);
      out.add(Padding(
        padding: EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(date == null ? d.date : frDay(date),
                style: TextStyle(color: K.text, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: K.green.withAlpha(40), borderRadius: BorderRadius.circular(12)),
            child: Text('${d.won}/${d.coupons.length} gagné${d.won > 1 ? 's' : ''}',
                style: TextStyle(color: K.green, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ]),
      ));
      if (d.singles.isNotEmpty) {
        out
          ..add(VipSinglesCard(legs: d.singles, expanded: false))
          ..add(SizedBox(height: 10));
      }
      for (final c in d.coupons) {
        out
          ..add(VipCouponCard(coupon: c, expanded: false))
          ..add(SizedBox(height: 10));
      }
    }
    return out;
  }
}

class VipCouponCard extends StatefulWidget {
  final VipCoupon coupon;
  final bool expanded;
  VipCouponCard({super.key, required this.coupon, required this.expanded});

  @override
  State<VipCouponCard> createState() => _VipCouponCardState();
}

class _VipCouponCardState extends State<VipCouponCard> {
  late bool _open = widget.expanded;

  List<Color> get _grad => switch (widget.coupon.tier) {
        2 => [Color(0xFF059669), Color(0xFF0D9488)],
        5 => [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        99 => [Color(0xFF831843), Color(0xFFBE123C)],
        _ => [Color(0xFFD97706), Color(0xFFDC2626)],
      };

  Widget _leg(VipLeg l) {
    final rc = l.result == 'won'
        ? K.green
        : l.result == 'lost'
            ? K.red
            : l.result == 'live'
                ? K.amber
                : K.muted;
    final d = l.date;
    return Container(
      color: (l.result == 'won' || l.result == 'lost') ? rc.withAlpha(30) : null,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 44,
          child: Column(children: [
            Text(d == null ? '--:--' : hm(d), style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(d == null ? '' : '${two(d.day)}/${two(d.month)}', style: TextStyle(color: K.muted, fontSize: 10.5)),
            if (l.result != 'pending')
              Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(
                  l.result == 'won'
                      ? Icons.check_circle_rounded
                      : l.result == 'lost'
                          ? Icons.cancel_rounded
                          : l.result == 'void'
                              ? Icons.remove_circle_outline_rounded
                              : Icons.radio_button_checked_rounded,
                  color: rc,
                  size: 16,
                ),
              ),
          ]),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.league, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.muted, fontSize: 11)),
            SizedBox(height: 4),
            Row(children: [
              TeamCrest(name: l.home, logo: l.hl, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(l.home,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ]),
            SizedBox(height: 3),
            Row(children: [
              TeamCrest(name: l.away, logo: l.al, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(l.away,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ]),
            SizedBox(height: 5),
            Text(l.label,
                style: TextStyle(
                    color: (l.result == 'won' || l.result == 'lost') ? rc : K.indigoText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
            for (final r in l.reasons)
              Padding(
                padding: EdgeInsets.only(top: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.lightbulb_outline_rounded, size: 13, color: K.amber),
                  ),
                  SizedBox(width: 5),
                  Expanded(child: Text(r, style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.3))),
                ]),
              ),
          ]),
        ),
        SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('@${fx(l.odd)}', style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: K.indigoSoft, borderRadius: BorderRadius.circular(8)),
            child: Text('${l.conf.round()} %',
                style: TextStyle(color: K.indigoText, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          if (l.score != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(l.score!.replaceAll('-', ' - '),
                  style: TextStyle(color: K.text, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.coupon;
    final (stLabel, stColor) = switch (c.status) {
      'won' => ('Gagné', K.green),
      'lost' => ('Perdu', K.red),
      'live' => ('En cours', K.amber),
      'na' => ('Indisponible', Colors.white),
      _ => ('En attente', Colors.white),
    };
    final rows = <Widget>[];
    if (_open) {
      for (var i = 0; i < c.legs.length; i++) {
        if (i > 0) rows.add(Container(height: 1, color: K.border));
        rows.add(_leg(c.legs[i]));
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: K.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: K.border),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _grad, begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(c.tier == 99 ? 'GROSSES COTES' : 'COUPON COTE ${c.tier}',
                        style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                  ]),
                  SizedBox(height: 4),
                  Text('${c.legs.length} matchs · confiance moyenne ${c.avgConf.round()} %',
                      style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(c.legs.isEmpty ? '—' : '×${fx(c.total)}', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                Container(
                  margin: EdgeInsets.only(top: 3),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Color(0x33000000), borderRadius: BorderRadius.circular(10)),
                  child: Text(stLabel, style: TextStyle(color: stColor, fontSize: 11.5, fontWeight: FontWeight.w800)),
                ),
              ]),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white),
            ]),
          ),
        ),
        if (c.legs.isEmpty)
          Padding(
            padding: EdgeInsets.all(16),
            child: Text("Coupon indisponible aujourd'hui : moins de 3 sélections solides à grosse cote. Nous préférons ne pas compléter artificiellement.",
                style: TextStyle(color: K.muted, fontSize: 13, height: 1.4)),
          ),
        if (c.tier == 99 && c.legs.isNotEmpty && _open)
          Container(
            width: double.infinity,
            color: K.amber.withAlpha(30),
            padding: EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Text('⚠️ Grosse cote = gain élevé mais probabilité de réussite faible. Misez prudemment.',
                style: TextStyle(color: K.amber, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
          ),
        ...rows,
        if (_open && c.legs.isNotEmpty) ...[
          Container(height: 1, color: K.border),
          Padding(
            padding: EdgeInsets.fromLTRB(14, 2, 4, 2),
            child: Row(children: [
              Icon(Icons.insights_rounded, color: K.muted, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text('Probabilité estimée ≈ ${c.prob.toStringAsFixed(c.prob < 10 ? 1 : 0).replaceAll('.', ',')} %',
                    style: TextStyle(color: K.muted, fontSize: 12.5)),
              ),
              IconButton(
                tooltip: 'Partager',
                onPressed: () => shareCoupon(context, c.toCoupon()),
                icon: Icon(Icons.share_rounded, color: K.muted, size: 20),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class VipSinglesCard extends StatefulWidget {
  final List<VipLeg> legs;
  final bool expanded;
  VipSinglesCard({super.key, required this.legs, this.expanded = true});

  @override
  State<VipSinglesCard> createState() => _VipSinglesCardState();
}

class _VipSinglesCardState extends State<VipSinglesCard> {
  late bool _open = widget.expanded;

  Widget _row(VipLeg l) {
    final rc = l.result == 'won'
        ? K.green
        : l.result == 'lost'
            ? K.red
            : l.result == 'live'
                ? K.amber
                : K.muted;
    final d = l.date;
    return Container(
      color: (l.result == 'won' || l.result == 'lost') ? rc.withAlpha(30) : null,
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 44,
          child: Column(children: [
            Text(d == null ? '--:--' : hm(d), style: TextStyle(color: K.text, fontSize: 13, fontWeight: FontWeight.w700)),
            Text(d == null ? '' : '${two(d.day)}/${two(d.month)}', style: TextStyle(color: K.muted, fontSize: 10.5)),
            if (l.result != 'pending')
              Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(
                  l.result == 'won'
                      ? Icons.check_circle_rounded
                      : l.result == 'lost'
                          ? Icons.cancel_rounded
                          : l.result == 'void'
                              ? Icons.remove_circle_outline_rounded
                              : Icons.radio_button_checked_rounded,
                  color: rc,
                  size: 16,
                ),
              ),
          ]),
        ),
        SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.league, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: K.muted, fontSize: 11)),
            SizedBox(height: 4),
            Row(children: [
              TeamCrest(name: l.home, logo: l.hl, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(l.home,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ]),
            SizedBox(height: 3),
            Row(children: [
              TeamCrest(name: l.away, logo: l.al, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(l.away,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: K.text, fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ]),
            SizedBox(height: 5),
            Text(l.label,
                style: TextStyle(
                    color: (l.result == 'won' || l.result == 'lost') ? rc : K.indigoText,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800)),
            if (l.reasons.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: EdgeInsets.only(top: 1), child: Icon(Icons.lightbulb_outline_rounded, size: 13, color: K.amber)),
                  SizedBox(width: 5),
                  Expanded(child: Text(l.reasons.first, style: TextStyle(color: K.muted, fontSize: 11.5, height: 1.3))),
                ]),
              ),
          ]),
        ),
        SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('@${fx(l.odd)}', style: TextStyle(color: K.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: K.indigoSoft, borderRadius: BorderRadius.circular(8)),
            child: Text('${l.conf.round()} %', style: TextStyle(color: K.indigoText, fontSize: 11.5, fontWeight: FontWeight.w800)),
          ),
          if (l.score != null)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(l.score!.replaceAll('-', ' - '), style: TextStyle(color: K.text, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final legs = widget.legs;
    final done = legs.where((l) => l.result == 'won' || l.result == 'lost').length;
    final won = legs.where((l) => l.result == 'won').length;
    final rows = <Widget>[];
    if (_open) {
      for (var i = 0; i < legs.length; i++) {
        if (i > 0) rows.add(Container(height: 1, color: K.border));
        rows.add(_row(legs[i]));
      }
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: K.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: K.border)),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Container(
            padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF0E7490), Color(0xFF0D9488)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text('TOP 5 DES PARIS SÛRS',
                        style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                  ]),
                  SizedBox(height: 4),
                  Text('Paris individuels, confiance ≥ 70 % · à jouer séparément',
                      style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 12)),
                ]),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: Color(0x33000000), borderRadius: BorderRadius.circular(10)),
                child: Text(done == 0 ? '${legs.length} paris' : '$won/$done gagnés',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.white),
            ]),
          ),
        ),
        ...rows,
      ]),
    );
  }
}
