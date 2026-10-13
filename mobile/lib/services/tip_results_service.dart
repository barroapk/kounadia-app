import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/tip_result.dart';

class TipResultsService {
  Future<List<TipResult>> _get(String path, String source) async {
    final r = await http
        .get(Uri.parse('${ApiConfig.baseUrl}$path'))
        .timeout(const Duration(seconds: 90));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    return ((data['results'] as List?) ?? [])
        .map((e) => TipResult.fromJson(e as Map<String, dynamic>, source))
        .toList();
  }

  Future<List<TipResult>> getAll() async {
    final out = <TipResult>[];
    var errors = 0;
    try {
      out.addAll(await _get('/scoregpt/results', 'ia'));
    } catch (_) {
      errors++;
    }
    try {
      out.addAll(await _get('/nerdytips/results', 'expert'));
    } catch (_) {
      errors++;
    }
    if (errors == 2) throw Exception('Historique indisponible');
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }
}
