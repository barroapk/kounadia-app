import "dart:async";
import "package:flutter/material.dart";
import "../models/match.dart";
import "cached_logo.dart";

class MatchRow extends StatefulWidget {
  final Match match;
  final VoidCallback onTap;

  const MatchRow({super.key, required this.match, required this.onTap});

  @override
  State<MatchRow> createState() => _MatchRowState();
}

class _MatchRowState extends State<MatchRow> {
  Timer? _ticker;
  String? _baseLabel;
  DateTime _anchorTime = DateTime.now();

  static const _liveStatuses = ["LIVE", "IN_PLAY", "PAUSED"];

  bool get _isLive => _liveStatuses.contains(widget.match.status);
  bool get _isFinished => widget.match.status == "FINISHED";

  @override
  void initState() {
    super.initState();
    _baseLabel = widget.match.liveMinuteLabel;
    _anchorTime = DateTime.now();
    if (_isLive) _startTicker();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void didUpdateWidget(covariant MatchRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.match.liveMinuteLabel != oldWidget.match.liveMinuteLabel) {
      _baseLabel = widget.match.liveMinuteLabel;
      _anchorTime = DateTime.now();
    }
    if (_isLive) {
      _startTicker();
    } else {
      _stopTicker();
    }
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  String _computeDisplayLabel() {
    final label = _baseLabel;
    if (label == null) return _estimatedMinuteFallback();

    final simpleMatch = RegExp(r"^(\d+)'$").firstMatch(label);
    if (simpleMatch == null) return label;

    final baseMinute = int.parse(simpleMatch.group(1)!);
    final elapsedSinceSync = DateTime.now().difference(_anchorTime).inMinutes;
    final drift = elapsedSinceSync.clamp(0, 3);
    final computed = baseMinute + drift;

    return "$computed'";
  }

  String _estimatedMinuteFallback() {
    final kickoff = DateTime.tryParse(widget.match.utcDate);
    if (kickoff == null) return "LIVE";
    if (widget.match.status == "PAUSED") return "MT";

    final elapsedMinutes = DateTime.now().toUtc().difference(kickoff).inMinutes;
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
    if (_isLive) return _computeDisplayLabel();
    if (_isFinished) return "Terminé";
    if (widget.match.status == "POSTPONED") return "Reporté";
    if (widget.match.status == "SUSPENDED") return "Ajourné";
    if (widget.match.status == "CANCELLED") return "Annulé";
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      widget.match.homeTeam,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 6),
                  CachedLogo(url: widget.match.homeTeamCrest),
                ],
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
              child: Row(
                children: [
                  CachedLogo(url: widget.match.awayTeamCrest),
                  const SizedBox(width: 6),
                  Flexible(
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
          ],
        ),
      ),
    );
  }
}
