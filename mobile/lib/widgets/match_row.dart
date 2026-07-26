import "package:flutter/material.dart";
import "../models/match.dart";

class MatchRow extends StatelessWidget {
  final Match match;
  final VoidCallback onTap;

  const MatchRow({super.key, required this.match, required this.onTap});

  bool get _isLive => match.status == "IN_PLAY" || match.status == "PAUSED";
  bool get _isFinished => match.status == "FINISHED";

  String get _statusText {
    if (_isLive) {
      return match.status == "PAUSED"
          ? "MT"
          : (match.minute != null ? "${match.minute}'" : "LIVE");
    }
    if (_isFinished) return "Terminé";
    final date = DateTime.tryParse(match.utcDate)?.toLocal();
    if (date == null) return "";
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    final hasScore = match.homeScore != null && match.awayScore != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                _statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: _isLive ? FontWeight.bold : FontWeight.normal,
                  color: _isLive ? const Color(0xFFDC2626) : Colors.grey[600],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.homeTeam,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          hasScore ? "${match.homeScore}" : "",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          match.awayTeam,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        child: Text(
                          hasScore ? "${match.awayScore}" : "",
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
