import "package:flutter/material.dart";
import "../models/standings.dart";
import "../config/competition_zones.dart";
import "cached_logo.dart";

class StandingsTable extends StatefulWidget {
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

  @override
  State<StandingsTable> createState() => _StandingsTableState();
}

class _GroupHeader {
  final String title;
  _GroupHeader(this.title);
}

class _StandingsTableState extends State<StandingsTable> {
  final ScrollController _scrollController = ScrollController();
  static const double _rowHeight = 52;
  static const _roundRobinCodes = {'PL', 'PD', 'BL1', 'SA', 'FL1', 'DED', 'PPL', 'ELC', 'BSA'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlighted());
  }

  @override
  void didUpdateWidget(covariant StandingsTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlighted());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlighted() {
    if (widget.highlightHomeTeam == null && widget.highlightAwayTeam == null) return;
    if (!_scrollController.hasClients) return;

    final index = widget.data.standings.indexWhere(
      (row) => row.teamName == widget.highlightHomeTeam || row.teamName == widget.highlightAwayTeam,
    );
    if (index == -1) return;

    final target = (index * _rowHeight - 100).clamp(0, double.infinity).toDouble();
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  double? get _seasonProgress {
    if (!_roundRobinCodes.contains(widget.data.competitionCode)) return null;
    if (widget.data.totalTeams < 2 || widget.data.standings.isEmpty) return null;

    final avgPlayed = widget.data.standings.map((s) => s.playedGames).reduce((a, b) => a + b) /
        widget.data.standings.length;
    final expectedTotal = (widget.data.totalTeams - 1) * 2;
    if (expectedTotal <= 0) return null;

    return (avgPlayed / expectedTotal).clamp(0, 1);
  }

  Widget _legend() {
    final hasZones = COMPETITION_ZONES.containsKey(widget.data.competitionCode);
    if (!hasZones) return const SizedBox.shrink();

    Widget dot(Color color, String label) {
      return Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        children: [
          dot(const Color(0xFF2563EB), "Ligue des Champions"),
          dot(const Color(0xFFF97316), "Coupe d'Europe"),
          dot(const Color(0xFFDC2626), "Relégation"),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    final progress = _seasonProgress;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CachedLogo(
                url: widget.data.competitionEmblem,
                size: 32,
                fallbackIcon: Icons.emoji_events,
                fallbackColor: const Color(0xFF16A34A),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.data.competitionName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                    if (widget.data.season != null)
                      Text("Saison ${widget.data.season}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              if (widget.data.availableSeasons.isNotEmpty && widget.onSeasonChanged != null)
                DropdownButton<String>(
                  value: widget.data.availableSeasons.any(
                    (s) => s.startYear == widget.data.season?.split('-').first,
                  )
                      ? widget.data.availableSeasons
                          .firstWhere((s) => s.startYear == widget.data.season?.split('-').first)
                          .startYear
                      : widget.data.availableSeasons.first.startYear,
                  underline: const SizedBox(),
                  isDense: true,
                  items: widget.data.availableSeasons
                      .map((s) => DropdownMenuItem(value: s.startYear, child: Text(s.label, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) widget.onSeasonChanged!(value);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _columnHeaderCell(String label, double width) {
    return SizedBox(
      width: width,
      child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _cell(String value, double width, {bool bold = false}) {
    return SizedBox(
      width: width,
      child: Text(value, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seasonNotStarted = widget.data.standings.every((row) => row.playedGames == 0);

    return Column(
      children: [
        _header(context),
        _legend(),
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
          child: Builder(
            builder: (context) {
              final hasGroups = widget.data.standings.any((s) => s.group != null);

              final List<dynamic> displayItems = [];
              if (hasGroups) {
                String? lastGroup;
                for (final row in widget.data.standings) {
                  if (row.group != lastGroup) {
                    displayItems.add(_GroupHeader(row.group ?? ''));
                    lastGroup = row.group;
                  }
                  displayItems.add(row);
                }
              } else {
                displayItems.addAll(widget.data.standings);
              }

              return ListView.builder(
                controller: _scrollController,
                itemCount: displayItems.length,
                itemBuilder: (context, index) {
                  final item = displayItems[index];

                  if (item is _GroupHeader) {
                    return Container(
                      width: double.infinity,
                      color: const Color(0xFFF4F5F7),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Text(
                        item.title.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 0.5),
                      ),
                    );
                  }

                  final row = item as StandingRow;
                  final isHighlighted =
                      row.teamName == widget.highlightHomeTeam || row.teamName == widget.highlightAwayTeam;
                  final zoneColor = (seasonNotStarted || hasGroups)
                      ? null
                      : zoneColorFor(widget.data.competitionCode, row.position, widget.data.totalTeams);
                  final barColor = isHighlighted ? const Color(0xFF16A34A) : (zoneColor ?? Colors.transparent);
                  final rowIndex = displayItems.take(index).whereType<StandingRow>().length;

                  return Container(
                    height: _rowHeight,
                    color: isHighlighted ? const Color(0xFF16A34A).withOpacity(0.08) : (rowIndex.isEven ? Colors.white : const Color(0xFFFAFAFA)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Container(width: 4, height: 32, color: barColor),
                        const SizedBox(width: 8),
                        SizedBox(width: 22, child: Text("${row.position}", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                        SizedBox(width: 26, child: CachedLogo(url: row.teamCrest, size: 20)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              row.teamName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal),
                            ),
                          ),
                        ),
                        _cell("${row.playedGames}", 26),
                        _cell("${row.won}", 22),
                        _cell("${row.draw}", 22),
                        _cell("${row.lost}", 22),
                        _cell(row.goalDifference > 0 ? "+${row.goalDifference}" : "${row.goalDifference}", 32),
                        _cell("${row.points}", 32, bold: true),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
