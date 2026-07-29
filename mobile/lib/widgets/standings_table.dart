import "package:flutter/material.dart";
import "../models/standings.dart";
import "cached_logo.dart";

class StandingsTable extends StatelessWidget {
  final StandingsResponse data;
  final String? highlightHomeTeam;
  final String? highlightAwayTeam;
  final ValueChanged<String>? onSeasonChanged;

  const StandingsTable({
    super.key,
    required this.data,
    this.highlightHomeTeam,
    this.highlightAwayTeam,
    this.onSeasonChanged,
  });

  static const _roundRobinCodes = {'PL', 'PD', 'BL1', 'SA', 'FL1', 'DED', 'PPL', 'ELC', 'BSA'};

  double? get _seasonProgress {
    if (!_roundRobinCodes.contains(data.competitionCode)) return null;
    if (data.totalTeams < 2 || data.standings.isEmpty) return null;

    final avgPlayed =
        data.standings.map((s) => s.playedGames).reduce((a, b) => a + b) / data.standings.length;
    final expectedTotal = (data.totalTeams - 1) * 2;
    if (expectedTotal <= 0) return null;

    return (avgPlayed / expectedTotal).clamp(0, 1);
  }

  Widget _header(BuildContext context) {
    final progress = _seasonProgress;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CachedLogo(
                url: data.competitionEmblem,
                size: 32,
                fallbackIcon: Icons.emoji_events,
                fallbackColor: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.competitionName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                    ),
                    if (data.season != null)
                      Text(
                        "Saison ${data.season}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (data.availableSeasons.isNotEmpty && onSeasonChanged != null)
                DropdownButton<String>(
                  value: data.availableSeasons.any((s) => s.startYear == data.season?.split('-').first)
                      ? data.availableSeasons.firstWhere(
                          (s) => s.startYear == data.season?.split('-').first,
                        ).startYear
                      : data.availableSeasons.first.startYear,
                  underline: const SizedBox(),
                  isDense: true,
                  items: data.availableSeasons
                      .map((s) => DropdownMenuItem(value: s.startYear, child: Text(s.label, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onSeasonChanged!(value);
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text("${data.totalTeams} équipes", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Color(0xFF16A34A)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${(progress * 100).round()}% de la saison jouée",
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _columnHeaderCell(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _cell(String value, double width, {bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _header(context),
        Container(
          color: const Color(0xFFF4F5F7),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const SizedBox(width: 4),
              const SizedBox(width: 22),
              const SizedBox(width: 26),
              const Expanded(child: SizedBox()),
              _columnHeaderCell("MJ", 26),
              _columnHeaderCell("G", 22),
              _columnHeaderCell("N", 22),
              _columnHeaderCell("P", 22),
              _columnHeaderCell("Diff.", 32),
              _columnHeaderCell("Pts", 32),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: data.standings.length,
            itemBuilder: (context, index) {
              final row = data.standings[index];
              final isHighlighted =
                  row.teamName == highlightHomeTeam || row.teamName == highlightAwayTeam;

              return Container(
                color: isHighlighted
                    ? const Color(0xFF16A34A).withOpacity(0.08)
                    : (index.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // Réservé pour les futures zones colorées (Ligue des Champions, relégation...).
                    SizedBox(width: 4),
                    SizedBox(
                      width: 22,
                      child: Text("${row.position}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    ),
                    SizedBox(width: 26, child: CachedLogo(url: row.teamCrest, size: 20)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Row(
                          children: [
                            if (isHighlighted)
                              const Padding(
                                padding: EdgeInsets.only(right: 4),
                                child: Icon(Icons.circle, size: 6, color: Color(0xFF16A34A)),
                              ),
                            Expanded(
                              child: Text(
                                row.teamName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _cell("${row.playedGames}", 26),
                    _cell("${row.won}", 22),
                    _cell("${row.draw}", 22),
                    _cell("${row.lost}", 22),
                    _cell(
                      row.goalDifference > 0 ? "+${row.goalDifference}" : "${row.goalDifference}",
                      32,
                    ),
                    _cell("${row.points}", 32, bold: true),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
