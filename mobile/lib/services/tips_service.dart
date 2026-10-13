import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/tip.dart';

class TipsService {
  Future<({List<Tip> tips, String source})> getTips(
      {double min = 0.6, int days = 7}) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/tips?min=$min&days=$days');
    Object? lastError;
    for (var i = 1; i <= 3; i++) {
      try {
        final r = await http.get(uri).timeout(const Duration(seconds: 90));
        if (r.statusCode == 200) {
          final data = jsonDecode(r.body) as Map<String, dynamic>;
          return (
            tips: (data['tips'] as List)
                .map((e) => Tip.fromJson(e as Map<String, dynamic>))
                .toList(),
            source: data['source'] as String,
          );
        }
        lastError = 'HTTP ${r.statusCode}';
      } catch (e) {
        lastError = e;
      }
      if (i < 3) await Future.delayed(Duration(seconds: 2 * i));
    }
    throw Exception('Pronostics indisponibles : $lastError');
  }
}
