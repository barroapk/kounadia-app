import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'kounadia_data_service.dart' show FriendlyError;
import 'live_socket.dart' show kLiveBase;
import 'match_detail_service.dart' show StandRow;

/// Pays de footlive.fr (accord du site) : compétitions et classements en plus de PrimaTips.
class FlCountry {
  final String slug, flag, en, fr, section;
  const FlCountry(this.slug, this.flag, this.en, this.fr, this.section);
  String get img => 'https://flagcdn.com/w40/$flag.png';
}

const kFlCountries = <FlCountry>[
  FlCountry('france', 'fr', 'France', 'France', 'Europe'),
  FlCountry('angleterre', 'gb-eng', 'England', 'Angleterre', 'Europe'),
  FlCountry('italie', 'it', 'Italy', 'Italie', 'Europe'),
  FlCountry('allemagne', 'de', 'Germany', 'Allemagne', 'Europe'),
  FlCountry('espagne', 'es', 'Spain', 'Espagne', 'Europe'),
  FlCountry('portugal', 'pt', 'Portugal', 'Portugal', 'Europe'),
  FlCountry('belgique', 'be', 'Belgium', 'Belgique', 'Europe'),
  FlCountry('suisse', 'ch', 'Switzerland', 'Suisse', 'Europe'),
  FlCountry('albanie', 'al', 'Albania', 'Albanie', 'Europe'),
  FlCountry('andorre', 'ad', 'Andorra', 'Andorre', 'Europe'),
  FlCountry('armenie', 'am', 'Armenia', 'Arménie', 'Europe'),
  FlCountry('autriche', 'at', 'Austria', 'Autriche', 'Europe'),
  FlCountry('azerbaidjan', 'az', 'Azerbaijan', 'Azerbaïdjan', 'Europe'),
  FlCountry('bielorussie', 'by', 'Belarus', 'Biélorussie', 'Europe'),
  FlCountry('bosnie-herzegovine', 'ba', 'Bosnia&Herz.', 'Bosnie-Herzégovine', 'Europe'),
  FlCountry('bulgarie', 'bg', 'Bulgaria', 'Bulgarie', 'Europe'),
  FlCountry('croatie', 'hr', 'Croatia', 'Croatie', 'Europe'),
  FlCountry('chypre', 'cy', 'Cyprus', 'Chypre', 'Europe'),
  FlCountry('danemark', 'dk', 'Denmark', 'Danemark', 'Europe'),
  FlCountry('ecosse', 'gb-sct', 'Scotland', 'Écosse', 'Europe'),
  FlCountry('estonie', 'ee', 'Estonia', 'Estonie', 'Europe'),
  FlCountry('finlande', 'fi', 'Finland', 'Finlande', 'Europe'),
  FlCountry('georgie', 'ge', 'Georgia', 'Géorgie', 'Europe'),
  FlCountry('grece', 'gr', 'Greece', 'Grèce', 'Europe'),
  FlCountry('hongrie', 'hu', 'Hungary', 'Hongrie', 'Europe'),
  FlCountry('iles-feroe', 'fo', 'Faroe Islands', 'Îles Féroé', 'Europe'),
  FlCountry('islande', 'is', 'Iceland', 'Islande', 'Europe'),
  FlCountry('irlande', 'ie', 'Ireland', 'Irlande', 'Europe'),
  FlCountry('israel', 'il', 'Israel', 'Israël', 'Europe'),
  FlCountry('kazakhstan', 'kz', 'Kazakhstan', 'Kazakhstan', 'Europe'),
  FlCountry('lettonie', 'lv', 'Latvia', 'Lettonie', 'Europe'),
  FlCountry('lituanie', 'lt', 'Lithuania', 'Lituanie', 'Europe'),
  FlCountry('luxembourg', 'lu', 'Luxembourg', 'Luxembourg', 'Europe'),
  FlCountry('malte', 'mt', 'Malta', 'Malte', 'Europe'),
  FlCountry('moldavie', 'md', 'Moldova', 'Moldavie', 'Europe'),
  FlCountry('montenegro', 'me', 'Montenegro', 'Monténégro', 'Europe'),
  FlCountry('pays-bas', 'nl', 'Netherlands', 'Pays-Bas', 'Europe'),
  FlCountry('norvege', 'no', 'Norway', 'Norvège', 'Europe'),
  FlCountry('pologne', 'pl', 'Poland', 'Pologne', 'Europe'),
  FlCountry('macedoine-du-nord', 'mk', 'North Macedonia', 'Macédoine du Nord', 'Europe'),
  FlCountry('republique-tcheque', 'cz', 'Czech Republic', 'République Tchèque', 'Europe'),
  FlCountry('roumanie', 'ro', 'Romania', 'Roumanie', 'Europe'),
  FlCountry('russie', 'ru', 'Russia', 'Russie', 'Europe'),
  FlCountry('saint-marin', 'sm', 'San Marino', 'Saint-Marin', 'Europe'),
  FlCountry('serbie', 'rs', 'Serbia', 'Serbie', 'Europe'),
  FlCountry('slovaquie', 'sk', 'Slovakia', 'Slovaquie', 'Europe'),
  FlCountry('slovenie', 'si', 'Slovenia', 'Slovénie', 'Europe'),
  FlCountry('suede', 'se', 'Sweden', 'Suède', 'Europe'),
  FlCountry('turquie', 'tr', 'Turkiye', 'Turquie', 'Europe'),
  FlCountry('ukraine', 'ua', 'Ukraine', 'Ukraine', 'Europe'),
  FlCountry('argentine', 'ar', 'Argentina', 'Argentine', 'Amérique du Sud'),
  FlCountry('bolivie', 'bo', 'Bolivia', 'Bolivie', 'Amérique du Sud'),
  FlCountry('bresil', 'br', 'Brazil', 'Brésil', 'Amérique du Sud'),
  FlCountry('canada', 'ca', 'Canada', 'Canada', 'Amérique du Nord et centrale'),
  FlCountry('chili', 'cl', 'Chile', 'Chili', 'Amérique du Sud'),
  FlCountry('colombie', 'co', 'Colombia', 'Colombie', 'Amérique du Sud'),
  FlCountry('costa-rica', 'cr', 'Costa Rica', 'Costa Rica', 'Amérique du Nord et centrale'),
  FlCountry('equateur', 'ec', 'Ecuador', 'Équateur', 'Amérique du Sud'),
  FlCountry('etats-unis', 'us', 'USA', 'États-Unis', 'Amérique du Nord et centrale'),
  FlCountry('guatemala', 'gt', 'Guatemala', 'Guatemala', 'Amérique du Nord et centrale'),
  FlCountry('honduras', 'hn', 'Honduras', 'Honduras', 'Amérique du Nord et centrale'),
  FlCountry('mexique', 'mx', 'Mexico', 'Mexique', 'Amérique du Nord et centrale'),
  FlCountry('paraguay', 'py', 'Paraguay', 'Paraguay', 'Amérique du Sud'),
  FlCountry('perou', 'pe', 'Peru', 'Pérou', 'Amérique du Sud'),
  FlCountry('uruguay', 'uy', 'Uruguay', 'Uruguay', 'Amérique du Sud'),
  FlCountry('venezuela', 've', 'Venezuela', 'Venezuela', 'Amérique du Sud'),
  FlCountry('arabie-saoudite', 'sa', 'Saudi Arabia', 'Arabie saoudite', 'Asie'),
  FlCountry('bahrein', 'bh', 'Bahrain', 'Bahreïn', 'Asie'),
  FlCountry('chine', 'cn', 'China', 'Chine', 'Asie'),
  FlCountry('coree-du-sud', 'kr', 'South Korea', 'Corée du Sud', 'Asie'),
  FlCountry('emirats-arabes-unis', 'ae', 'United Arab Emirates', 'Émirats arabes unis', 'Asie'),
  FlCountry('hong-kong', 'hk', 'Hong Kong', 'Hong Kong', 'Asie'),
  FlCountry('inde', 'in', 'India', 'Inde', 'Asie'),
  FlCountry('iran', 'ir', 'Iran', 'Iran', 'Asie'),
  FlCountry('japon', 'jp', 'Japan', 'Japon', 'Asie'),
  FlCountry('koweit', 'kw', 'Kuwait', 'Koweït', 'Asie'),
  FlCountry('liban', 'lb', 'Lebanon', 'Liban', 'Asie'),
  FlCountry('malaisie', 'my', 'Malaysia', 'Malaisie', 'Asie'),
  FlCountry('qatar', 'qa', 'Qatar', 'Qatar', 'Asie'),
  FlCountry('singapour', 'sg', 'Singapore', 'Singapour', 'Asie'),
  FlCountry('syrie', 'sy', 'Syria', 'Syrie', 'Asie'),
  FlCountry('thailande', 'th', 'Thailand', 'Thaïlande', 'Asie'),
  FlCountry('ouzbekistan', 'uz', 'Uzbekistan', 'Ouzbékistan', 'Asie'),
  FlCountry('afrique-du-sud', 'za', 'South Africa', 'Afrique du Sud', 'Afrique'),
  FlCountry('algerie', 'dz', 'Algeria', 'Algérie', 'Afrique'),
  FlCountry('egypte', 'eg', 'Egypt', 'Égypte', 'Afrique'),
  FlCountry('kenya', 'ke', 'Kenya', 'Kenya', 'Afrique'),
  FlCountry('maroc', 'ma', 'Morocco', 'Maroc', 'Afrique'),
  FlCountry('nigeria', 'ng', 'Nigeria', 'Nigéria', 'Afrique'),
  FlCountry('senegal', 'sn', 'Senegal', 'Sénégal', 'Afrique'),
  FlCountry('tunisie', 'tn', 'Tunisia', 'Tunisie', 'Afrique'),
  FlCountry('australie', 'au', 'Australia', 'Australie', 'Océanie'),
  FlCountry('nouvelle-zelande', 'nz', 'New Zealand', 'Nouvelle-Zélande', 'Océanie'),
];

FlCountry? flCountryOf(String en) {
  final k = en.trim().toLowerCase();
  for (final c in kFlCountries) {
    if (c.en.toLowerCase() == k || c.fr.toLowerCase() == k) return c;
  }
  return null;
}

/// Une compétition footlive : titre (sans le pays) et lien du classement (null si aucun).
class FlComp {
  final String title;
  final String? standings;
  FlComp(this.title, this.standings);
}

class FootliveService {
  static const _base = 'https://www.footlive.fr';
  static final _cache = <String, (DateTime, String)>{};

  /// Version navigateur : passe par le robot KOUNADIA (autorisations du navigateur).
  static String _url(String path) => kIsWeb && kLiveBase.isNotEmpty ? '$kLiveBase/fl$path' : '$_base$path';

  static Future<String> _get(String path) async {
    final c = _cache[path];
    if (c != null && DateTime.now().difference(c.$1) < const Duration(minutes: 10)) return c.$2;
    try {
      final r = await http.get(Uri.parse(_url(path)), headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android) KOUNADIA'}).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw FriendlyError('Ce classement est momentanément indisponible. Réessayez dans un instant.');
      final h = utf8.decode(r.bodyBytes, allowMalformed: true);
      _cache[path] = (DateTime.now(), h);
      if (_cache.length > 40) _cache.remove(_cache.keys.first);
      return h;
    } on FriendlyError {
      rethrow;
    } catch (e) {
      if (e is SocketException || e is TimeoutException || e is http.ClientException) {
        throw FriendlyError('Vous êtes hors connexion. Vérifiez votre connexion internet puis réessayez.');
      }
      throw FriendlyError('Ce classement est momentanément indisponible. Réessayez dans un instant.');
    }
  }

  static String _txt(String s) => s
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAllMapped(RegExp(r'&#(\d+);'), (m) => String.fromCharCode(int.parse(m[1]!)))
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Compétitions d'un pays (jeunes et réserves exclues).
  static Future<List<FlComp>> competitions(FlCountry c) async {
    final h = await _get('/${c.slug}/');
    final out = <FlComp>[];
    final seen = <String>{};
    final youth = RegExp(r'\bU-?1[3-9]\b|\bU-?2[0-3]\b|youth|reserve|primavera|moins de \d+ ans|jeunes|espoirs', caseSensitive: false);
    for (final m in RegExp(r"id='compName_\d+'([\s\S]*?)</table>").allMatches(h)) {
      final b = m[1]!;
      var title = _txt(RegExp(r'<h2>([\s\S]*?)</h2>').firstMatch(b)?[1] ?? '');
      if (title.toLowerCase().startsWith('${c.fr.toLowerCase()} ')) title = title.substring(c.fr.length + 1).trim();
      if (title.isEmpty || youth.hasMatch(title) || !seen.add(title)) continue;
      final st = RegExp(r"href='(/classement/[^']+)'").firstMatch(b)?[1];
      out.add(FlComp(title, st));
    }
    return out;
  }

  /// Classement d'une compétition (une ou plusieurs poules).
  static Future<List<List<StandRow>>> standings(String path) async {
    final h = await _get(path);
    final out = <List<StandRow>>[];
    for (final t in RegExp(r"<table class='standings'>([\s\S]*?)</table>").allMatches(h)) {
      final rows = <StandRow>[];
      for (final r in RegExp(r"<td class='text-center'>(\d+)</td>([\s\S]*?)(?=<tr>|</tbody>|$)").allMatches(t[1]!)) {
        final cells = RegExp(r'<td[^>]*>([\s\S]*?)</td>').allMatches(r[2]!).map((x) => _txt(x[1]!)).toList();
        if (cells.length < 7) continue;
        final g = RegExp(r'(\d+)\s*-\s*(\d+)').firstMatch(cells[5]);
        final gf = g?[1] ?? '', ga = g?[2] ?? '';
        final d = g == null ? 0 : int.parse(gf) - int.parse(ga);
        rows.add(StandRow(int.parse(r[1]!), cells[0], '', cells[1], cells[2], cells[3], cells[4], gf, ga,
            g == null ? '' : (d > 0 ? '+$d' : '$d'), cells[6]));
      }
      if (rows.isNotEmpty) out.add(rows);
    }
    return out;
  }
}
