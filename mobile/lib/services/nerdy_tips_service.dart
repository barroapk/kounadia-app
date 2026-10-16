import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/nerdy_tip.dart';

class NerdyTipsService {
  Future<List<NerdyTip>> getToday() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/nerdytips/today');
    final r = await http.get(uri).timeout(Duration(seconds: 90));
    if (r.statusCode != 200) {
      throw Exception('Pronostics indisponibles');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return ((data['matches'] as List?) ?? [])
        .map((e) => NerdyTip.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
