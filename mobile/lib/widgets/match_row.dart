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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                match.homeTeam,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: _isLive ? FontWeight.bold : FontWeight.normal,
                      color: _isLive ? const Color(0xFFDC2626) : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasScore
                        ? "${match.homeScore} - ${match.awayScore}"
                        : "vs",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: hasScore ? 15 : 13,
                      color: hasScore ? Colors.black : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Text(
                match.awayTeam,
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
