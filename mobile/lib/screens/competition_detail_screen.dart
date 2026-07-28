import "package:flutter/material.dart";
import "../models/standings.dart";
import "../services/api_service.dart";
import "../services/last_competition_service.dart";
import "../widgets/cached_logo.dart";

class CompetitionDetailScreen extends StatefulWidget {
  final String name;
  final String? code;

  const CompetitionDetailScreen({super.key, required this.name, this.code});

  @override
  State<CompetitionDetailScreen> createState() => _CompetitionDetailScreenState();
}

class _CompetitionDetailScreenState extends State<CompetitionDetailScreen> {
  final ApiService _apiService = ApiService();
  final LastCompetitionService _lastCompetitionService = LastCompetitionService();
  Future<StandingsResponse?>? _standingsFuture;

  @override
  void initState() {
    super.initState();
    _lastCompetitionService.setLast(widget.name);
    if (widget.code != null) {
      _standingsFuture = _apiService.getStandings(widget.code!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: widget.code == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Classement non disponible pour cette compétition pour l'instant.",
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : FutureBuilder<StandingsResponse?>(
              future: _standingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data;
                if (data == null || data.standings.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Classement indisponible pour le moment.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: data.standings.length,
                  itemBuilder: (context, index) {
                    final row = data.standings[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 24, child: Text("${row.position}")),
                          CachedLogo(url: row.teamCrest, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(row.teamName, overflow: TextOverflow.ellipsis)),
                          SizedBox(width: 28, child: Text("${row.playedGames}", textAlign: TextAlign.center)),
                          SizedBox(width: 32, child: Text("${row.goalDifference}", textAlign: TextAlign.center)),
                          SizedBox(
                            width: 32,
                            child: Text(
                              "${row.points}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
