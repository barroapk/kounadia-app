import "dart:async";
import "package:flutter/material.dart";
import "../models/match.dart";

class MatchRow extends StatefulWidget {
  final Match match;
  final VoidCallback onTap;

  const MatchRow({super.key, required this.match, required this.onTap});

  @override
  State<MatchRow> createState() => _MatchRowState();
}

class _MatchRowState extends State<MatchRow> {
  Timer? _ticker;

  static const _liveStatuses = ["LIVE", "IN_PLAY", "PAUSED"];

  bool get _isLive => _liveStatuses.contains(widget.match.status);
  bool get _isFinished => widget.match.status == "FINISHED";
  bool get _hasRealMinute => widget.match.liveMinuteLabel != null;

  @override
  void initState() {
    super.initState();
    // Le ticker local ne sert que de repli : si on a déjà la vraie minute
    // (liveMinuteLabel), pas besoin d'estimer localement.
    if (_isLive && !_hasRealMinute) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _estimatedMinute() {
    final kickoff = DateTime.tryParse(widget.match.utcDate);
    if (kickoff == null) return "LIVE";

    final elapsedMinutes = DateTime.now().toUtc().difference(kickoff).inMinutes;

    if (widget.match.status == "PAUSED") return "MT";
    if (elapsedMinutes <= 45) {
      return elapsedMinutes < 1 ? "1'" : "$elapsedMinutes'";
    }

    const halftimeBreak = 15;
    final secondHalfMinute = elapsedMinutes - halftimeBreak;
    if (secondHalfMinute <= 45) {
      return secondHalfMinute < 46 ? "$secondHalfMinute'" : "45'";
    }
    return "90'+";
  }

  String get _statusText {
    if (_isLive) {
      return widget.match.liveMinuteLabel ?? _estimatedMinute();
    }
    if (_isFinished) return "Terminé";
    final date = DateTime.tryParse(widget.match.utcDate)?.toLocal();
    if (date == null) return "";
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    final hasScore =
        widget.match.homeScore != null && widget.match.awayScore != null;

    return InkWell(
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                widget.match.homeTeam,
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
                        ? "${widget.match.homeScore} - ${widget.match.awayScore}"
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
                widget.match.awayTeam,
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
