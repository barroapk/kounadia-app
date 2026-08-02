import "package:flutter/material.dart";
import "../models/match_analysis.dart";
import "../models/standings.dart";
import "match_summary_card.dart";
import "match_timeline_view.dart";

class MatchDetailsTab extends StatefulWidget {
  final MatchAnalysis analysis;
  final StandingsResponse? standings;
  final VoidCallback onSeeStats;
  final VoidCallback onSeeStandings;

  const MatchDetailsTab({
    super.key,
    required this.analysis,
    this.standings,
    required this.onSeeStats,
    required this.onSeeStandings,
  });

  @override
  State<MatchDetailsTab> createState() => _MatchDetailsTabState();
}

class _MatchDetailsTabState extends State<MatchDetailsTab> {
  bool _timelineExpanded = false;

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF16A34A)),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  IconData _eventIcon(MatchEvent e) {
    switch (e.type) {
      case "Goal":
        return Icons.sports_soccer;
      case "Card":
        return Icons.square_rounded;
      case "subst":
        return Icons.swap_horiz;
      default:
        return Icons.circle;
    }
  }

  Color _eventColor(MatchEvent e) {
    switch (e.type) {
      case "Goal":
        return const Color(0xFF16A34A);
      case "Card":
        return e.detail == "Red Card" ? const Color(0xFFDC2626) : const Color(0xFFEAB308);
      default:
        return Colors.grey[500]!;
    }
  }

  String _minuteLabel(MatchEvent e) {
    final base = e.minute ?? 0;
    return e.extraMinute != null ? "$base+${e.extraMinute}'" : "$base'";
  }

  Widget _eventRow(MatchEvent e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text(_minuteLabel(e), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
          Icon(_eventIcon(e), size: 14, color: _eventColor(e)),
          const SizedBox(width: 8),
          Expanded(
            child: Text("${e.player ?? ''}${e.team != null ? ' · ${e.team}' : ''}",
                style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _timelinePreview() {
    final events = widget.analysis.events;
    if (events == null || events.isEmpty) {
      return const Text("Aucun événement pour ce match.", style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    final sorted = List<MatchEvent>.from(events)
      ..sort((a, b) {
        final ta = (a.minute ?? 0) * 100 + (a.extraMinute ?? 0);
        final tb = (b.minute ?? 0) * 100 + (b.extraMinute ?? 0);
        return tb.compareTo(ta);
      });

    final visible = _timelineExpanded ? sorted : sorted.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MatchTimelineView(
          events: visible,
          homeTeam: widget.analysis.homeTeam,
          shrinkWrap: true,
        ),
        if (sorted.length > 3)
          InkWell(
            onTap: () => setState(() => _timelineExpanded = !_timelineExpanded),
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _timelineExpanded ? "Réduire" : "Voir toute la chronologie",
                style: const TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  double? _asNumber(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString().replaceAll('%', ''));
  }

  Widget _keyStatsPreview() {
    final stats = widget.analysis.statistics;
    if (stats == null) {
      return const Text("Statistiques indisponibles.", style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    const keyStats = {
      "Ball Possession": "Possession",
      "expected_goals": "xG",
      "Total Shots": "Tirs",
      "Shots on Goal": "Tirs cadrés",
    };

    final rows = <Widget>[];
    keyStats.forEach((key, label) {
      final home = stats.home[key];
      final away = stats.away[key];
      if (home == null && away == null) return;

      final homeNum = _asNumber(home) ?? 0;
      final awayNum = _asNumber(away) ?? 0;
      final total = homeNum + awayNum;
      final homeRatio = total > 0 ? homeNum / total : 0.5;

      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("${home ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
                Text("${away ?? '-'}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(flex: (homeRatio * 100).round().clamp(1, 99), child: Container(height: 5, color: const Color(0xFF16A34A))),
                  Expanded(flex: (100 - (homeRatio * 100).round()).clamp(1, 99), child: Container(height: 5, color: Colors.grey[300])),
                ],
              ),
            ),
          ],
        ),
      ));
    });

    if (rows.isEmpty) {
      return const Text("Statistiques indisponibles.", style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows,
        InkWell(
          onTap: widget.onSeeStats,
          child: const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text("Voir toutes les statistiques", style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _miniStandings() {
    final standings = widget.standings;
    if (standings == null || standings.standings.isEmpty) {
      return const Text("Classement indisponible pour cette compétition.", style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    StandingRow? findRow(String team) {
      try {
        return standings.standings.firstWhere((r) => r.teamName == team);
      } catch (_) {
        return null;
      }
    }

    final homeRow = findRow(widget.analysis.homeTeam);
    final awayRow = findRow(widget.analysis.awayTeam);

    Widget row(StandingRow? r, String fallbackName) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(width: 28, child: Text(r != null ? "${r.position}e" : "-", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5))),
            Expanded(child: Text(r?.teamName ?? fallbackName, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)),
            if (r != null) Text("${r.points} pts", style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        row(homeRow, widget.analysis.homeTeam),
        row(awayRow, widget.analysis.awayTeam),
        InkWell(
          onTap: widget.onSeeStandings,
          child: const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text("Voir le classement complet", style: TextStyle(color: Color(0xFF16A34A), fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _formBar(String label, TeamForm form) {
    final total = form.matchesAnalyzed;
    if (total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text("$label : pas assez de données.", style: const TextStyle(fontSize: 12, color: Colors.grey)),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                if (form.wins > 0) Expanded(flex: form.wins, child: Container(height: 10, color: const Color(0xFF16A34A))),
                if (form.draws > 0) Expanded(flex: form.draws, child: Container(height: 10, color: Colors.grey[400])),
                if (form.losses > 0) Expanded(flex: form.losses, child: Container(height: 10, color: const Color(0xFFDC2626))),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text("${form.wins}V ${form.draws}N ${form.losses}D sur $total match(s)",
              style: TextStyle(color: Colors.grey[600], fontSize: 11)),
        ],
      ),
    );
  }

  Widget _headToHeadBar(HeadToHead h2h) {
    if (!h2h.available || (h2h.totalMatches ?? 0) == 0) {
      return const Text("Aucun historique de confrontation disponible.", style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    final winsA = h2h.teamAWins ?? 0;
    final draws = h2h.draws ?? 0;
    final winsB = h2h.teamBWins ?? 0;
    final teamAName = h2h.teamA ?? "Équipe A";
    final teamBName = h2h.teamB ?? "Équipe B";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("$winsA", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF16A34A))),
            Text("$draws nuls", style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
            Text("$winsB", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Row(
            children: [
              if (winsA > 0) Expanded(flex: winsA, child: Container(height: 10, color: const Color(0xFF16A34A))),
              if (draws > 0) Expanded(flex: draws, child: Container(height: 10, color: Colors.grey[400])),
              if (winsB > 0) Expanded(flex: winsB, child: Container(height: 10, color: Colors.grey[700])),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "$teamAName : $winsA victoire(s) · $teamBName : $winsB victoire(s) · $draws nul(s) · ${h2h.totalMatches} confrontation(s) au total",
          style: TextStyle(color: Colors.grey[600], fontSize: 10.5),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysis = widget.analysis;

    return ListView(
      padding: const EdgeInsets.only(top: 10, bottom: 16),
      children: [
        MatchSummaryCard(
          statistics: analysis.statistics,
          events: analysis.events,
          homeTeam: analysis.homeTeam,
          awayTeam: analysis.awayTeam,
        ),
        _sectionCard(title: "Chronologie", icon: Icons.timeline, child: _timelinePreview()),
        _sectionCard(title: "Statistiques clés", icon: Icons.bar_chart, child: _keyStatsPreview()),
        _sectionCard(title: "Classement", icon: Icons.leaderboard_outlined, child: _miniStandings()),
        _sectionCard(
          title: "Forme récente",
          icon: Icons.show_chart,
          child: Column(
            children: [
              _formBar(analysis.homeTeam, analysis.home),
              _formBar(analysis.awayTeam, analysis.away),
            ],
          ),
        ),
        _sectionCard(title: "Face à face", icon: Icons.compare_arrows, child: _headToHeadBar(analysis.headToHead)),
      ],
    );
  }
}
