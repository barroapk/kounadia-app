import "dart:async";
import "package:flutter/material.dart";

class MatchCountdown extends StatefulWidget {
  final DateTime kickoff;

  const MatchCountdown({super.key, required this.kickoff});

  @override
  State<MatchCountdown> createState() => _MatchCountdownState();
}

class _MatchCountdownState extends State<MatchCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final now = DateTime.now().toUtc();
    final diff = widget.kickoff.difference(now);
    if (mounted) {
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    if (days > 0) return "${days}j ${hours}h ${minutes}min";
    if (hours > 0) return "${hours}h ${minutes.toString().padLeft(2, '0')}min";
    return "${minutes}min ${seconds.toString().padLeft(2, '0')}s";
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF16A34A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.schedule, size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Text(
            "Coup d'envoi dans ${_format(_remaining)}",
            style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
