import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/sg_tip.dart';

class SgTipsService {
  Future<List<SgTip>> getToday() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/scoregpt/today');
    final r = await http.get(uri).timeout(const Duration(seconds: 90));
    if (r.statusCode != 200) {
      throw Exception('Pronostics indisponibles');
    }
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return ((data['matches'] as List?) ?? [])
        .map((e) => SgTip.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }
}
