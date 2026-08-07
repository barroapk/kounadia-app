import "dart:async";
import "package:flutter/material.dart";
import "cached_logo.dart";

class MatchHeaderCard extends StatefulWidget {
  final String homeTeam;
  final String awayTeam;
  final String? homeTeamCrest;
  final String? awayTeamCrest;
  final int? homeScore;
  final int? awayScore;
  final String? wonAfter;
  final String? competition;
  final String? venue;
  final String? referee;
  final bool isLive;
  final bool isPaused;
  final bool isFinished;
  final DateTime? kickoff;

  const MatchHeaderCard({
    super.key,
    required this.homeTeam,
    required this.awayTeam,
    this.homeTeamCrest,
    this.awayTeamCrest,
    this.homeScore,
    this.awayScore,
    this.wonAfter,
    this.competition,
    this.venue,
    this.referee,
    this.isLive = false,
    this.isPaused = false,
    this.isFinished = false,
    this.kickoff,
  });

  @override
  State<MatchHeaderCard> createState() => _MatchHeaderCardState();
}

class _MatchHeaderCardState extends State<MatchHeaderCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if ((widget.isLive || (widget.kickoff != null && !widget.isFinished))) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _countdownText() {
    final now = DateTime.now().toUtc();
    final diff = widget.kickoff!.difference(now);
    if (diff.isNegative) return "";
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;
    if (d > 0) return "Coup d'envoi dans ${d}j ${h}h ${m}min";
    if (h > 0) return "Coup d'envoi dans ${h}h ${m.toString().padLeft(2, '0')}min";
    return "Coup d'envoi dans ${m}min ${s.toString().padLeft(2, '0')}s";
  }

  /// Estimation locale (pas une vraie donnée temps réel) : notre backend
  /// n'expose pas encore la minute précise sur cet écran, contrairement à
  /// la liste des matchs. Même logique d'approximation que MatchRow.
  String? _estimatedMinute() {
    if (widget.isPaused) return "MT";
    if (!widget.isLive || widget.kickoff == null) return null;

    final elapsed = DateTime.now().toUtc().difference(widget.kickoff!).inMinutes;
    if (elapsed <= 45) {
      return "${elapsed < 1 ? 1 : elapsed}'";
    }

    const halftimeBreak = 15;
    final secondHalfMinute = elapsed - halftimeBreak;

    if (secondHalfMinute <= 90) {
      return "${secondHalfMinute < 46 ? 46 : secondHalfMinute}'";
    }

    return "90+'";
  }

  @override
  Widget build(BuildContext context) {
    final hasScore = widget.homeScore != null && widget.awayScore != null;
    final minute = _estimatedMinute();

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: Column(
                  children: [
                    CachedLogo(url: widget.homeTeamCrest, size: 64, fallbackIcon: Icons.shield_outlined),
                    const SizedBox(height: 6),
                    Text(
                      widget.homeTeam,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      hasScore
                          ? "${widget.homeScore} - ${widget.awayScore}"
                            "${widget.wonAfter != null ? " (${widget.wonAfter})" : ""}"
                          : "VS",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 34,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (minute != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          minute,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      )
                    else if (widget.isFinished)
                      Text("Terminé", style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600))
                    else if (widget.kickoff != null)
                      Text(_countdownText(), style: const TextStyle(color: Color(0xFF16A34A), fontSize: 11.5, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    CachedLogo(url: widget.awayTeamCrest, size: 64, fallbackIcon: Icons.shield_outlined),
                    const SizedBox(height: 6),
                    Text(
                      widget.awayTeam,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.competition != null) ...[
            const SizedBox(height: 12),
            Text(widget.competition!, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
          if (widget.venue != null || widget.referee != null) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              children: [
                if (widget.venue != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.stadium_outlined, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(widget.venue!, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
                  ]),
                if (widget.referee != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sports_outlined, size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(widget.referee!, style: TextStyle(color: Colors.grey[600], fontSize: 11.5)),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
