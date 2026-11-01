import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/live_match.dart';
import '../services/highlights.dart';
import '../services/primatips_service.dart' show frName;
import '../l10n/tr.dart';
import 'forecast_card.dart' show K, kMessage, hm, two;
import 'video_open.dart';

/// Matchs › Temps forts : les vidéos des grands matchs, une carte par match, de la plus récente à la plus ancienne.
class HighlightsList extends StatefulWidget {
  /// Matchs connus de l'app (pour le score et le championnat à jour).
  final Map<int, LiveMatch> byId;
  HighlightsList({super.key, required this.byId});

  @override
  State<HighlightsList> createState() => _HighlightsListState();
}

class _HighlightsListState extends State<HighlightsList> {
  @override
  void initState() {
    super.initState();
    Highlights.changed.addListener(_re);
    Highlights.load();
  }

  @override
  void dispose() {
    Highlights.changed.removeListener(_re);
    super.dispose();
  }

  void _re() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = Highlights.recent();
    return RefreshIndicator(
      color: K.indigo,
      backgroundColor: K.card,
      onRefresh: () => Highlights.load(force: true),
      child: l.isEmpty
          ? ListView(physics: AlwaysScrollableScrollPhysics(), children: [
              SizedBox(height: 80),
              kMessage('Aucun temps fort pour le moment.\nLes vidéos des grands matchs arrivent environ 2 h après la fin.'),
            ])
          : ListView.builder(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(12, 0, 12, 96),
              itemCount: l.length,
              itemBuilder: (_, i) => Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _HlCard(v: l[i], m: widget.byId[l[i].match]),
              ),
            ),
    );
  }
}

class _HlCard extends StatelessWidget {
  final HlVideo v;
  final LiveMatch? m;
  _HlCard({required this.v, this.m});

  String _day(DateTime d) {
    final now = DateTime.now();
    final a = DateTime(d.year, d.month, d.day), b = DateTime(now.year, now.month, now.day);
    final n = b.difference(a).inDays;
    final day = n == 0 ? tr("Aujourd'hui") : n == 1 ? tr('Hier') : '${two(d.day)}/${two(d.month)}';
    return '$day · ${hm(d)}';
  }

  @override
  Widget build(BuildContext context) {
    final home = m?.home ?? v.home, away = m?.away ?? v.away;
    final score = m != null && m!.hs != null && m!.as_ != null ? '${m!.hs} - ${m!.as_}' : v.score.replaceAll('-', ' - ');
    final league = frName(m?.league ?? v.league);
    final shadow = [Shadow(blurRadius: 8, color: Colors.black87)];
    return GestureDetector(
      onTap: () => openHighlight(context, v, title: '$home - $away', src: 'liste'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: v.thumb,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Color(0xFF14532D)),
              errorWidget: (_, __, ___) => Container(color: Color(0xFF14532D)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withAlpha(120), Colors.black.withAlpha(30), Colors.black.withAlpha(200)],
                  stops: [0, .45, 1],
                ),
              ),
            ),
            // Championnat et date.
            Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Row(children: [
                if (league.isNotEmpty)
                  Flexible(
                    child: Text(league.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1, shadows: shadow)),
                  ),
                Spacer(),
                if (v.date != null) Text(_day(v.date!), style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, shadows: shadow)),
              ]),
            ),
            // Bouton de lecture.
            Center(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(color: Color(0xE6FF0000), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 12)]),
                child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
            ),
            // Équipes et score.
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Expanded(
                    child: Text(home,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, shadows: shadow)),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 10),
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withAlpha(150), borderRadius: BorderRadius.circular(8)),
                    child: Text(score.isEmpty ? '–' : score, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  Expanded(
                    child: Text(away,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, shadows: shadow)),
                  ),
                ]),
                SizedBox(height: 4),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.play_circle_outline_rounded, color: Colors.white70, size: 14),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text('${tr('Temps forts')} · ${v.channel}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white70, fontSize: 12, shadows: shadow)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
