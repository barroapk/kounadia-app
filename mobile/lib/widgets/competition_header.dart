import "package:flutter/material.dart";
import "cached_logo.dart";

class CompetitionHeader extends StatelessWidget {
  final String name;
  final String? emblemUrl;

  CompetitionHeader({super.key, required this.name, this.emblemUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: CachedLogo(
              url: emblemUrl,
              size: 18,
              fallbackIcon: Icons.emoji_events,
              fallbackColor: Color(0xFF16A34A),
            ),
          ),
          Text(
            name,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
