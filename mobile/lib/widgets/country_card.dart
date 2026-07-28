import "package:flutter/material.dart";
import "cached_logo.dart";

class CountryCard extends StatelessWidget {
  final String title;
  final String? flagUrl;
  final int matchCount;
  final int competitionCount;
  final bool initiallyExpanded;
  final List<Widget> children;
  final IconData? fallbackIcon;

  const CountryCard({
    super.key,
    required this.title,
    this.flagUrl,
    required this.matchCount,
    required this.competitionCount,
    this.initiallyExpanded = false,
    required this.children,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          leading: CachedLogo(
            url: flagUrl,
            size: 28,
            fallbackIcon: fallbackIcon ?? Icons.flag_outlined,
          ),
          title: Text(title, style: const TextStyle(fontSize: 15)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 13, color: Colors.grey[500]),
              const SizedBox(width: 2),
              Text("$competitionCount", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              if (matchCount > 0) ...[
                const SizedBox(width: 8),
                Icon(Icons.sports_soccer, size: 13, color: Colors.grey[500]),
                const SizedBox(width: 2),
                Text("$matchCount", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}
