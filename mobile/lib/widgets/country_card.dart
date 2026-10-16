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

  CountryCard({
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
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          leading: CachedLogo(
            url: flagUrl,
            size: 28,
            fallbackIcon: fallbackIcon ?? Icons.flag_outlined,
          ),
          title: Text(title, style: TextStyle(fontSize: 15)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.emoji_events, size: 13, color: Colors.grey[500]),
              SizedBox(width: 2),
              Text("$competitionCount", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              if (matchCount > 0) ...[
                SizedBox(width: 8),
                Icon(Icons.sports_soccer, size: 13, color: Colors.grey[500]),
                SizedBox(width: 2),
                Text("$matchCount", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
              SizedBox(width: 4),
              Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}
