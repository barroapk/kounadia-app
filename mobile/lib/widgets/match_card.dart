import "package:flutter/material.dart";
import "../models/match.dart";
import "match_status_widget.dart";

class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;

  MatchCard({super.key, required this.match, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasScore = match.homeScore != null && match.awayScore != null;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: MatchStatusWidget(
                  status: match.status,
                  minute: match.minute,
                  utcDate: match.utcDate,
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.homeTeam,
                      style: TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    hasScore ? "${match.homeScore}" : "-",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      match.awayTeam,
                      style: TextStyle(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    hasScore ? "${match.awayScore}" : "-",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
