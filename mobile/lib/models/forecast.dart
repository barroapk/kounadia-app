import 'package:flutter/material.dart';

Color? _hex(String s) {
  var h = s.replaceAll('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  if (h.length == 8) h = h.substring(0, 6);
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}

List<Color> _colors(dynamic v) =>
    (v is List ? v : []).map((e) => _hex(e.toString())).whereType<Color>().toList();

class Forecast {
  final String id;
  final String source;
  final DateTime date;
  final bool hasTime;
  final String league;
  final String home;
  final String away;
  final String? homeLogo;
  final String? awayLogo;
  final List<Color> homeColors;
  final List<Color> awayColors;
  final String tipFr;
  final String? predicted;
  final double? confidence;
  final int? agree;
  final int? models;
  final String? score;
  final bool? won;

  Forecast({
    required this.id,
    required this.source,
    required this.date,
    required this.hasTime,
    required this.league,
    required this.home,
    required this.away,
    this.homeLogo,
    this.awayLogo,
    this.homeColors = const [],
    this.awayColors = const [],
    required this.tipFr,
    this.predicted,
    this.confidence,
    this.agree,
    this.models,
    this.score,
    this.won,
  });

  factory Forecast.fromJson(Map<String, dynamic> j, String source) {
    String? s(String k) {
      final v = j[k];
      return v == null || v.toString().isEmpty ? null : v.toString();
    }

    return Forecast(
      id: j['id']?.toString() ?? '',
      source: (j['source'] ?? source).toString(),
      date: DateTime.tryParse(j['date']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      hasTime: j['hasTime'] == null ? true : j['hasTime'] == true,
      league: j['league']?.toString() ?? '',
      home: j['home']?.toString() ?? '',
      away: j['away']?.toString() ?? '',
      homeLogo: s('homeLogo'),
      awayLogo: s('awayLogo'),
      homeColors: _colors(j['homeColors']),
      awayColors: _colors(j['awayColors']),
      tipFr: j['tipFr']?.toString() ?? '',
      predicted: s('predicted'),
      confidence: (j['confidence'] as num?)?.toDouble(),
      agree: (j['agree'] as num?)?.toInt(),
      models: (j['models'] as num?)?.toInt(),
      score: s('score'),
      won: j['won'] is bool ? j['won'] as bool : null,
    );
  }
}
