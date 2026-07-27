import "package:flutter/material.dart";
import "package:cached_network_image/cached_network_image.dart";

class CachedLogo extends StatelessWidget {
  final String? url;
  final double size;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const CachedLogo({
    super.key,
    required this.url,
    this.size = 20,
    this.fallbackIcon = Icons.shield_outlined,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(fallbackIcon, size: size, color: fallbackColor ?? Colors.grey[400]),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (context, url) => SizedBox(width: size, height: size),
      errorWidget: (context, url, error) => SizedBox(
        width: size,
        height: size,
        child: Icon(fallbackIcon, size: size, color: fallbackColor ?? Colors.grey[400]),
      ),
    );
  }
}
