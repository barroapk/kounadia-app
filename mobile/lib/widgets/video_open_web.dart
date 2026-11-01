import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/highlights.dart';

Future<void> openHighlight(BuildContext context, HlVideo v, {String? title}) async {
  try {
    await launchUrl(Uri.parse(v.url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Version navigateur : pas de lecteur intégré, la vidéo s'ouvre dans YouTube.
class HlPlayerHost extends StatelessWidget {
  final Widget child;
  HlPlayerHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}
