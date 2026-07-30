import "package:flutter/material.dart";
import "cached_logo.dart";

class MatchHeader extends StatelessWidget {
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamCrest;
  final String? awayTeamCrest;
  final int? homeScore;
  final int? awayScore;
  final String? statusLabel;
  final bool isLive;

  const MatchHeader({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamCrest,
    this.awayTeamCrest,
    this.homeScore,
    this.awayScore,
    this.statusLabel,
    this.isLive = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasScore = homeScore != null && awayScore != null;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        children: [
          if (statusLabel != null)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isLive ? const Color(0xFFDC2626) : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel!,
                style: TextStyle(
                  color: isLive ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    CachedLogo(url: homeTeamCrest, size: 60, fallbackIcon: Icons.shield_outlined),
                    const SizedBox(height: 8),
                    Text(
                      homeTeam,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 90,
                child: Text(
                  hasScore ? "$homeScore - $awayScore" : "VS",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    CachedLogo(url: awayTeamCrest, size: 60, fallbackIcon: Icons.shield_outlined),
                    const SizedBox(height: 8),
                    Text(
                      awayTeam,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
