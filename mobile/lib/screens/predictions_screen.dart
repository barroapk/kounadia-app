import "package:flutter/material.dart";
import "../models/eligible_match.dart";
import "../services/api_service.dart";
import "../widgets/empty_state.dart";
import "../widgets/loading_skeleton.dart";
import "match_detail_screen.dart";

class PredictionsScreen extends StatefulWidget {
  const PredictionsScreen({super.key});

  @override
  State<PredictionsScreen> createState() => _PredictionsScreenState();
}

class _PredictionsScreenState extends State<PredictionsScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<EligibleMatch>> _predictionsFuture;

  @override
  void initState() {
    super.initState();
    _predictionsFuture = _apiService.getTodaysPredictions();
  }

  void _reload() {
    setState(() {
      _predictionsFuture = _apiService.getTodaysPredictions();
    });
  }

  Color _sideColor(String side) {
    if (side == 'balanced') return Colors.grey[600]!;
    return const Color(0xFF16A34A);
  }

  IconData _sideIcon(String side) {
    if (side == 'home') return Icons.arrow_back;
    if (side == 'away') return Icons.arrow_forward;
    return Icons.balance;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EligibleMatch>>(
      future: _predictionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingSkeleton();
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Erreur : ${snapshot.error}"),
                  const SizedBox(height: 12),
                  ElevatedButton(onPressed: _reload, child: const Text("Réessayer")),
                ],
              ),
            ),
          );
        }

        final predictions = snapshot.data ?? [];

        if (predictions.isEmpty) {
          return const EmptyState(
            icon: Icons.insights,
            message:
                "Pas assez de données historiques aujourd'hui pour proposer une analyse fiable.\nRevenez bientôt : la base s'enrichit chaque jour.",
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _predictionsFuture;
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: predictions.length,
            itemBuilder: (context, index) {
              final p = predictions[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MatchDetailScreen(
                          matchId: p.matchId,
                          homeTeam: p.homeTeam,
                          awayTeam: p.awayTeam,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.competition,
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "${p.homeTeam} vs ${p.awayTeam}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ),
                            Icon(_sideIcon(p.favoredSide), size: 18, color: _sideColor(p.favoredSide)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Indice de force : ${p.homeElo} · ${p.awayElo}",
                          style: TextStyle(color: Colors.grey[500], fontSize: 11),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _sideColor(p.favoredSide).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            p.note,
                            style: TextStyle(
                              color: _sideColor(p.favoredSide),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
