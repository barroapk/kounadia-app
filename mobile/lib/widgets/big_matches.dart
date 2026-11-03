import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/live_match.dart';
import '../services/highlights.dart';
import '../services/primatips_service.dart' show frName;
import '../l10n/tr.dart';
import 'forecast_card.dart' show hm;
import 'jersey.dart';
import 'video_open.dart';

String _n(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
    .trim();

/// Rang d'un grand championnat (plus petit = plus important) ; null si ce n'est pas un grand championnat.
int? bigRank(LiveMatch m) {
  final c = _n(m.country), l = _n(m.league);
  if (RegExp(r'\b(women|feminine|u19|u20|u21|u23|youth|reserve)\b').hasMatch(l)) return null;
  if (RegExp(r'\b(caf|afc|concacaf|conmebol)\b').hasMatch(l) && l.contains('champions')) return null;
  if (l.contains('champions league')) return 0;
  if (RegExp(r'world cup|coupe du monde|africa cup|coupe d afrique|euro 20|european championship').hasMatch(l)) return 0;
  if (l.contains('europa league')) return 2;
  if (RegExp(r'nations league|conference league|club world cup|super cup|supercopa|supercoppa').hasMatch(l)) return 3;
  bool p(String cr, String lr) => RegExp(cr).hasMatch(c) && RegExp(lr).hasMatch(l);
  if (p(r'^(england|angleterre)$', r'^premier league$')) return 1;
  if (p(r'^(spain|espagne)$', r'^(la ?liga|laliga|primera division|liga)$')) return 1;
  if (p(r'^(italy|italie)$', r'^serie a$')) return 1;
  if (p(r'^(germany|allemagne)$', r'^bundesliga$')) return 1;
  if (p(r'^france$', r'^ligue 1$')) return 1;
  if (p(r'^portugal$', r'^(primeira liga|liga portugal)')) return 4;
  if (p(r'^(netherlands|pays bas)$', r'^eredivisie$')) return 4;
  return null;
}

/// Grands matchs du jour : direct d'abord, puis à venir, puis terminés (tous ceux du jour, au plus 30 :
/// un soir de Ligue des champions, les matchs terminés ne sont plus coupés par la limite).
List<LiveMatch> bigMatches(List<LiveMatch> all) {
  final l = all.where((m) => bigRank(m) != null && m.status != 'postponed').toList();
  int st(LiveMatch m) => m.status == 'live' ? 0 : (m.status == 'finished' ? 2 : 1);
  l.sort((a, b) {
    final s = st(a).compareTo(st(b));
    if (s != 0) return s;
    final r = bigRank(a)!.compareTo(bigRank(b)!);
    if (r != 0 && st(a) != 2) return r;
    final da = a.date ?? DateTime(2000), db = b.date ?? DateTime(2000);
    return st(a) == 2 ? db.compareTo(da) : da.compareTo(db);
  });
  return l.take(30).toList();
}

/// Bandeau des grands matchs, qui défile seul de droite à gauche.
class BigMatchesCarousel extends StatefulWidget {
  final List<LiveMatch> matches;
  final String? Function(String team) logo;
  final void Function(LiveMatch m) onOpen;
  BigMatchesCarousel({super.key, required this.matches, required this.logo, required this.onOpen});

  @override
  State<BigMatchesCarousel> createState() => _BigMatchesCarouselState();
}

class _BigMatchesCarouselState extends State<BigMatchesCarousel> {
  static const _loop = 10000;
  late final PageController _pc = PageController(viewportFraction: 0.9, initialPage: _start());
  Timer? _auto;
  DateTime _pauseUntil = DateTime(2000);

  int _start() {
    final n = widget.matches.length;
    return n <= 1 ? 0 : (_loop ~/ 2) - ((_loop ~/ 2) % n);
  }

  @override
  void initState() {
    super.initState();
    Highlights.load();
    Highlights.changed.addListener(_re);
    _auto = Timer.periodic(Duration(milliseconds: 4500), (_) => _next());
  }

  void _re() {
    if (mounted) setState(() {});
  }

  void _next() {
    if (!mounted || widget.matches.length <= 1 || !_pc.hasClients) return;
    if (DateTime.now().isBefore(_pauseUntil) || !TickerMode.of(context)) return;
    Highlights.load();
    _pc.nextPage(duration: Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() {
    _auto?.cancel();
    Highlights.changed.removeListener(_re);
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.matches;
    if (list.isEmpty) return SizedBox.shrink();
    final n = list.length;
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 180,
        child: NotificationListener<ScrollNotification>(
          onNotification: (s) {
            // L'utilisateur fait défiler lui-même : on attend avant de reprendre.
            if (s is ScrollStartNotification && s.dragDetails != null) _pauseUntil = DateTime.now().add(Duration(seconds: 9));
            return false;
          },
          child: PageView.builder(
            controller: _pc,
            padEnds: false,
            itemCount: n <= 1 ? n : _loop,
            itemBuilder: (_, i) {
              final m = list[i % n];
              return Padding(
                padding: EdgeInsets.only(right: 10),
                child: _BigCard(m: m, logo: widget.logo, onOpen: () => widget.onOpen(m)),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BigCard extends StatelessWidget {
  final LiveMatch m;
  final String? Function(String) logo;
  final VoidCallback onOpen;
  _BigCard({required this.m, required this.logo, required this.onOpen});

  Widget _side(String name) => Expanded(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(30)),
            child: TeamCrest(name: name, logo: logo(name), size: 44),
          ),
          SizedBox(height: 8),
          Text(name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.15, shadows: [Shadow(blurRadius: 6, color: Colors.black54)])),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final live = m.status == 'live';
    final done = m.status == 'finished';
    final has = m.hs != null && m.as_ != null;
    // Temps forts : seulement pour un match terminé depuis moins de 3 jours.
    final recent = m.date != null && DateTime.now().difference(m.date!) < Duration(days: 3);
    final hl = done && recent ? Highlights.of(m.id) : null;
    final center = <Widget>[
      if (has && (live || done))
        Text('${m.hs}  -  ${m.as_}',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1, shadows: [Shadow(blurRadius: 8, color: Colors.black54)]))
      else
        Text(m.date != null ? hm(m.date!) : '--:--',
            style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, shadows: [Shadow(blurRadius: 8, color: Colors.black54)])),
      if (live && (m.minute ?? '').isNotEmpty) ...[
        SizedBox(height: 4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Color(0xFFEF4444), borderRadius: BorderRadius.circular(8)),
          child: Text(m.minute!, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
        ),
      ],
      if (hl != null) ...[
        SizedBox(height: 6),
        _PlayButton(onTap: () => openHighlight(context, hl, title: '${m.home} - ${m.away}', src: 'carte')),
      ],
    ];
    final status = live
        ? tr('En direct')
        : done
            ? (hl != null ? tr('Terminé · Temps forts') : tr('Terminé'))
            : tr('À venir');
    return GestureDetector(
      onTap: onOpen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _Stadium(live: live),
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(children: [
              Text(frName(m.league).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withAlpha(235), fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  _side(m.home),
                  SizedBox(width: 108, child: Column(mainAxisSize: MainAxisSize.min, children: center)),
                  _side(m.away),
                ]),
              ),
              Container(height: 1, color: Colors.white.withAlpha(70)),
              SizedBox(height: 7),
              Row(children: [
                if (live) ...[
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                  SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(status,
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: live ? FontWeight.w800 : FontWeight.w600)),
                ),
                Icon(Icons.north_east_rounded, color: Colors.white, size: 18),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final VoidCallback onTap;
  _PlayButton({required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: EdgeInsets.fromLTRB(4, 3, 10, 3),
            decoration: BoxDecoration(
              color: Color(0xE6FF0000),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
              Text(tr('Temps forts'), style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      );
}

/// Fond « stade la nuit » dessiné (tribunes, projecteurs, pelouse rayée et lignes) : léger, sans image à télécharger.
class _Stadium extends CustomPainter {
  final bool live;
  _Stadium({required this.live});

  @override
  void paint(Canvas c, Size s) {
    final r = Offset.zero & s;
    // Tribunes (haut) puis pelouse (bas).
    c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1220), Color(0xFF1B2A3A), Color(0xFF14532D), Color(0xFF166534)],
            stops: [0, .32, .5, 1],
          ).createShader(r));
    // Points de foule dans les tribunes.
    final rnd = math.Random(7);
    final crowd = Paint();
    for (var i = 0; i < 260; i++) {
      final x = rnd.nextDouble() * s.width, y = rnd.nextDouble() * s.height * .44;
      crowd.color = Colors.white.withAlpha(8 + rnd.nextInt(26));
      c.drawCircle(Offset(x, y), .8 + rnd.nextDouble() * 1.1, crowd);
    }
    // Bandes de pelouse.
    final stripe = Paint()..color = Colors.white.withAlpha(10);
    final top = s.height * .48;
    for (var i = 0; i < 8; i += 2) {
      final w = s.width / 8;
      c.drawRect(Rect.fromLTWH(i * w, top, w, s.height - top), stripe);
    }
    // Lignes du terrain.
    final line = Paint()
      ..color = Colors.white.withAlpha(55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    c.drawLine(Offset(s.width / 2, top), Offset(s.width / 2, s.height), line);
    c.drawOval(Rect.fromCenter(center: Offset(s.width / 2, s.height * .8), width: s.width * .3, height: s.height * .22), line);
    c.drawLine(Offset(0, top), Offset(s.width, top), line);
    // Projecteurs.
    for (final x in [.12, .88]) {
      final o = Offset(s.width * x, s.height * .06);
      c.drawCircle(
          o,
          s.width * .32,
          Paint()
            ..shader = RadialGradient(colors: [Colors.white.withAlpha(70), Colors.white.withAlpha(0)])
                .createShader(Rect.fromCircle(center: o, radius: s.width * .32)));
    }
    if (live) {
      c.drawRect(r, Paint()..color = Color(0x1AEF4444));
    }
    // Voile sombre pour bien lire le texte.
    c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black.withAlpha(60), Colors.black.withAlpha(20), Colors.black.withAlpha(110)],
          ).createShader(r));
  }

  @override
  bool shouldRepaint(_Stadium o) => o.live != live;
}
