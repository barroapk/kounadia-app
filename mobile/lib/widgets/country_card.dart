import "package:flutter/material.dart";
import "cached_logo.dart";

class CountryCard extends StatelessWidget {
  final String title;
  final String? flagUrl;
  final int matchCount;
  final bool initiallyExpanded;
  final List<Widget> children;
  final IconData? fallbackIcon;

  const CountryCard({
    super.key,
    required this.title,
    this.flagUrl,
    required this.matchCount,
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
              Text("$matchCount", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}
