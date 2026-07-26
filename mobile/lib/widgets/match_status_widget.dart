import "package:flutter/material.dart";
import "live_badge.dart";

class MatchStatusWidget extends StatelessWidget {
  final String status;
  final int? minute;
  final String utcDate;

  const MatchStatusWidget({
    super.key,
    required this.status,
    required this.minute,
    required this.utcDate,
  });

  bool get _isLive => status == "IN_PLAY" || status == "PAUSED";
  bool get _isFinished => status == "FINISHED";

  String get _timeLabel {
    final date = DateTime.tryParse(utcDate)?.toLocal();
    if (date == null) return "";
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLive) {
      final label = status == "PAUSED"
          ? "Mi-temps"
          : (minute != null ? "$minute'" : "EN DIRECT");
      return LiveBadge(label: label);
    }

    if (_isFinished) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "TERMINÉ",
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Text(
      _timeLabel,
      style: TextStyle(color: Colors.grey[600], fontSize: 13),
    );
  }
}
