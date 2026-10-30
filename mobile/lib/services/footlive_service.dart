import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

/// Tous les autres pays (liste des pays de l'app) : présents dans Mes championnats et Classements
/// même quand aucune compétition n'est encore connue (« Tout · pays » couvre alors tous ses championnats).
const kFlMore = <FlCountry>[
  FlCountry('benin', 'bj', 'Benin', 'Bénin', 'Afrique'),
  FlCountry('burkina-faso', 'bf', 'Burkina Faso', 'Burkina Faso', 'Afrique'),
  FlCountry('cameroun', 'cm', 'Cameroon', 'Cameroun', 'Afrique'),
  FlCountry('congo-brazzaville', 'cg', 'Congo - Brazzaville', 'Congo-Brazzaville', 'Afrique'),
  FlCountry('congo-kinshasa', 'cd', 'Congo - Kinshasa', 'Congo-Kinshasa', 'Afrique'),
  FlCountry('cote-d-ivoire', 'ci', 'Côte d’Ivoire', 'Côte d’Ivoire', 'Afrique'),
  FlCountry('gabon', 'ga', 'Gabon', 'Gabon', 'Afrique'),
  FlCountry('ghana', 'gh', 'Ghana', 'Ghana', 'Afrique'),
  FlCountry('guinee', 'gn', 'Guinea', 'Guinée', 'Afrique'),
  FlCountry('guinee-bissau', 'gw', 'Guinea-Bissau', 'Guinée-Bissau', 'Afrique'),
  FlCountry('mali', 'ml', 'Mali', 'Mali', 'Afrique'),
  FlCountry('niger', 'ne', 'Niger', 'Niger', 'Afrique'),
  FlCountry('republique-centrafricaine', 'cf', 'Central African Republic', 'République centrafricaine', 'Afrique'),
  FlCountry('tchad', 'td', 'Chad', 'Tchad', 'Afrique'),
  FlCountry('togo', 'tg', 'Togo', 'Togo', 'Afrique'),
  FlCountry('afghanistan', 'af', 'Afghanistan', 'Afghanistan', 'Asie'),
  FlCountry('angola', 'ao', 'Angola', 'Angola', 'Afrique'),
  FlCountry('anguilla', 'ai', 'Anguilla', 'Anguilla', 'Amérique du Nord et centrale'),
  FlCountry('antigua-et-barbuda', 'ag', 'Antigua & Barbuda', 'Antigua-et-Barbuda', 'Amérique du Nord et centrale'),
  FlCountry('aruba', 'aw', 'Aruba', 'Aruba', 'Amérique du Nord et centrale'),
  FlCountry('bahamas', 'bs', 'Bahamas', 'Bahamas', 'Amérique du Nord et centrale'),
  FlCountry('bangladesh', 'bd', 'Bangladesh', 'Bangladesh', 'Asie'),
  FlCountry('barbade', 'bb', 'Barbados', 'Barbade', 'Amérique du Nord et centrale'),
  FlCountry('belize', 'bz', 'Belize', 'Belize', 'Amérique du Nord et centrale'),
  FlCountry('bermudes', 'bm', 'Bermuda', 'Bermudes', 'Amérique du Nord et centrale'),
  FlCountry('bhoutan', 'bt', 'Bhutan', 'Bhoutan', 'Asie'),
  FlCountry('botswana', 'bw', 'Botswana', 'Botswana', 'Afrique'),
  FlCountry('brunei', 'bn', 'Brunei', 'Brunei', 'Asie'),
  FlCountry('burundi', 'bi', 'Burundi', 'Burundi', 'Afrique'),
  FlCountry('cambodge', 'kh', 'Cambodia', 'Cambodge', 'Asie'),
  FlCountry('cap-vert', 'cv', 'Cape Verde', 'Cap-Vert', 'Afrique'),
  FlCountry('comores', 'km', 'Comoros', 'Comores', 'Afrique'),
  FlCountry('coree-du-nord', 'kp', 'North Korea', 'Corée du Nord', 'Asie'),
  FlCountry('cuba', 'cu', 'Cuba', 'Cuba', 'Amérique du Nord et centrale'),
  FlCountry('curacao', 'cw', 'Curaçao', 'Curaçao', 'Amérique du Nord et centrale'),
  FlCountry('djibouti', 'dj', 'Djibouti', 'Djibouti', 'Afrique'),
  FlCountry('dominique', 'dm', 'Dominica', 'Dominique', 'Amérique du Nord et centrale'),
  FlCountry('erythree', 'er', 'Eritrea', 'Érythrée', 'Afrique'),
  FlCountry('eswatini', 'sz', 'Eswatini', 'Eswatini', 'Afrique'),
  FlCountry('etat-de-la-cite-du-vatican', 'va', 'Vatican City', 'État de la Cité du Vatican', 'Europe'),
  FlCountry('ethiopie', 'et', 'Ethiopia', 'Éthiopie', 'Afrique'),
  FlCountry('fidji', 'fj', 'Fiji', 'Fidji', 'Océanie'),
  FlCountry('gambie', 'gm', 'Gambia', 'Gambie', 'Afrique'),
  FlCountry('gibraltar', 'gi', 'Gibraltar', 'Gibraltar', 'Europe'),
  FlCountry('grenade', 'gd', 'Grenada', 'Grenade', 'Amérique du Nord et centrale'),
  FlCountry('groenland', 'gl', 'Greenland', 'Groenland', 'Amérique du Nord et centrale'),
  FlCountry('guadeloupe', 'gp', 'Guadeloupe', 'Guadeloupe', 'Amérique du Nord et centrale'),
  FlCountry('guam', 'gu', 'Guam', 'Guam', 'Océanie'),
  FlCountry('guernesey', 'gg', 'Guernsey', 'Guernesey', 'Europe'),
  FlCountry('guinee-equatoriale', 'gq', 'Equatorial Guinea', 'Guinée équatoriale', 'Afrique'),
  FlCountry('guyana', 'gy', 'Guyana', 'Guyana', 'Amérique du Sud'),
  FlCountry('guyane-francaise', 'gf', 'French Guiana', 'Guyane française', 'Amérique du Sud'),
  FlCountry('haiti', 'ht', 'Haiti', 'Haïti', 'Amérique du Nord et centrale'),
  FlCountry('ile-de-man', 'im', 'Isle of Man', 'Île de Man', 'Europe'),
  FlCountry('iles-caimans', 'ky', 'Cayman Islands', 'Îles Caïmans', 'Amérique du Nord et centrale'),
  FlCountry('iles-cook', 'ck', 'Cook Islands', 'Îles Cook', 'Océanie'),
  FlCountry('iles-malouines', 'fk', 'Falkland Islands', 'Îles Malouines', 'Amérique du Sud'),
  FlCountry('iles-mariannes-du-nord', 'mp', 'Northern Mariana Islands', 'Îles Mariannes du Nord', 'Océanie'),
  FlCountry('iles-marshall', 'mh', 'Marshall Islands', 'Îles Marshall', 'Océanie'),
  FlCountry('iles-salomon', 'sb', 'Solomon Islands', 'Îles Salomon', 'Océanie'),
  FlCountry('iles-turques-et-caiques', 'tc', 'Turks & Caicos Islands', 'Îles Turques-et-Caïques', 'Amérique du Nord et centrale'),
  FlCountry('iles-vierges-britanniques', 'vg', 'British Virgin Islands', 'Îles Vierges britanniques', 'Amérique du Nord et centrale'),
  FlCountry('iles-vierges-des-etats-unis', 'vi', 'U.S. Virgin Islands', 'Îles Vierges des États-Unis', 'Amérique du Nord et centrale'),
  FlCountry('indonesie', 'id', 'Indonesia', 'Indonésie', 'Asie'),
  FlCountry('irak', 'iq', 'Iraq', 'Irak', 'Asie'),
  FlCountry('jamaique', 'jm', 'Jamaica', 'Jamaïque', 'Amérique du Nord et centrale'),
  FlCountry('jersey', 'je', 'Jersey', 'Jersey', 'Europe'),
  FlCountry('jordanie', 'jo', 'Jordan', 'Jordanie', 'Asie'),
  FlCountry('kirghizstan', 'kg', 'Kyrgyzstan', 'Kirghizstan', 'Asie'),
  FlCountry('kiribati', 'ki', 'Kiribati', 'Kiribati', 'Océanie'),
  FlCountry('kosovo', 'xk', 'Kosovo', 'Kosovo', 'Europe'),
  FlCountry('la-reunion', 're', 'Réunion', 'La Réunion', 'Afrique'),
  FlCountry('laos', 'la', 'Laos', 'Laos', 'Asie'),
  FlCountry('lesotho', 'ls', 'Lesotho', 'Lesotho', 'Afrique'),
  FlCountry('liberia', 'lr', 'Liberia', 'Liberia', 'Afrique'),
  FlCountry('libye', 'ly', 'Libya', 'Libye', 'Afrique'),
  FlCountry('liechtenstein', 'li', 'Liechtenstein', 'Liechtenstein', 'Europe'),
  FlCountry('madagascar', 'mg', 'Madagascar', 'Madagascar', 'Afrique'),
  FlCountry('malawi', 'mw', 'Malawi', 'Malawi', 'Afrique'),
  FlCountry('maldives', 'mv', 'Maldives', 'Maldives', 'Asie'),
  FlCountry('martinique', 'mq', 'Martinique', 'Martinique', 'Amérique du Nord et centrale'),
  FlCountry('maurice', 'mu', 'Mauritius', 'Maurice', 'Afrique'),
  FlCountry('mauritanie', 'mr', 'Mauritania', 'Mauritanie', 'Afrique'),
  FlCountry('micronesie', 'fm', 'Micronesia', 'Micronésie', 'Océanie'),
  FlCountry('monaco', 'mc', 'Monaco', 'Monaco', 'Europe'),
  FlCountry('mongolie', 'mn', 'Mongolia', 'Mongolie', 'Asie'),
  FlCountry('montserrat', 'ms', 'Montserrat', 'Montserrat', 'Amérique du Nord et centrale'),
  FlCountry('mozambique', 'mz', 'Mozambique', 'Mozambique', 'Afrique'),
  FlCountry('myanmar-birmanie', 'mm', 'Myanmar (Burma)', 'Myanmar (Birmanie)', 'Asie'),
  FlCountry('namibie', 'na', 'Namibia', 'Namibie', 'Afrique'),
  FlCountry('nauru', 'nr', 'Nauru', 'Nauru', 'Océanie'),
  FlCountry('nepal', 'np', 'Nepal', 'Népal', 'Asie'),
  FlCountry('nicaragua', 'ni', 'Nicaragua', 'Nicaragua', 'Amérique du Nord et centrale'),
  FlCountry('niue', 'nu', 'Niue', 'Niue', 'Océanie'),
  FlCountry('nouvelle-caledonie', 'nc', 'New Caledonia', 'Nouvelle-Calédonie', 'Océanie'),
  FlCountry('oman', 'om', 'Oman', 'Oman', 'Asie'),
  FlCountry('ouganda', 'ug', 'Uganda', 'Ouganda', 'Afrique'),
  FlCountry('pakistan', 'pk', 'Pakistan', 'Pakistan', 'Asie'),
  FlCountry('palaos', 'pw', 'Palau', 'Palaos', 'Océanie'),
  FlCountry('panama', 'pa', 'Panama', 'Panama', 'Amérique du Nord et centrale'),
  FlCountry('papouasie-nouvelle-guinee', 'pg', 'Papua New Guinea', 'Papouasie-Nouvelle-Guinée', 'Océanie'),
  FlCountry('philippines', 'ph', 'Philippines', 'Philippines', 'Asie'),
  FlCountry('polynesie-francaise', 'pf', 'French Polynesia', 'Polynésie française', 'Océanie'),
  FlCountry('porto-rico', 'pr', 'Puerto Rico', 'Porto Rico', 'Amérique du Nord et centrale'),
  FlCountry('r-a-s-chinoise-de-macao', 'mo', 'Macao SAR China', 'R.A.S. chinoise de Macao', 'Asie'),
  FlCountry('republique-dominicaine', 'do', 'Dominican Republic', 'République dominicaine', 'Amérique du Nord et centrale'),
  FlCountry('rwanda', 'rw', 'Rwanda', 'Rwanda', 'Afrique'),
  FlCountry('saint-christophe-et-nieves', 'kn', 'St. Kitts & Nevis', 'Saint-Christophe-et-Niévès', 'Amérique du Nord et centrale'),
  FlCountry('saint-martin-partie-neerlandaise', 'sx', 'Sint Maarten', 'Saint-Martin (partie néerlandaise)', 'Amérique du Nord et centrale'),
  FlCountry('saint-vincent-et-les-grenadines', 'vc', 'St. Vincent & Grenadines', 'Saint-Vincent-et-les Grenadines', 'Amérique du Nord et centrale'),
  FlCountry('sainte-lucie', 'lc', 'St. Lucia', 'Sainte-Lucie', 'Amérique du Nord et centrale'),
  FlCountry('salvador', 'sv', 'El Salvador', 'Salvador', 'Amérique du Nord et centrale'),
  FlCountry('samoa', 'ws', 'Samoa', 'Samoa', 'Océanie'),
  FlCountry('samoa-americaines', 'as', 'American Samoa', 'Samoa américaines', 'Océanie'),
  FlCountry('sao-tome-et-principe', 'st', 'São Tomé & Príncipe', 'Sao Tomé-et-Principe', 'Afrique'),
  FlCountry('seychelles', 'sc', 'Seychelles', 'Seychelles', 'Afrique'),
  FlCountry('sierra-leone', 'sl', 'Sierra Leone', 'Sierra Leone', 'Afrique'),
  FlCountry('somalie', 'so', 'Somalia', 'Somalie', 'Afrique'),
  FlCountry('soudan', 'sd', 'Sudan', 'Soudan', 'Afrique'),
  FlCountry('soudan-du-sud', 'ss', 'South Sudan', 'Soudan du Sud', 'Afrique'),
  FlCountry('sri-lanka', 'lk', 'Sri Lanka', 'Sri Lanka', 'Asie'),
  FlCountry('suriname', 'sr', 'Suriname', 'Suriname', 'Amérique du Sud'),
  FlCountry('tadjikistan', 'tj', 'Tajikistan', 'Tadjikistan', 'Asie'),
  FlCountry('taiwan', 'tw', 'Taiwan', 'Taïwan', 'Asie'),
  FlCountry('tanzanie', 'tz', 'Tanzania', 'Tanzanie', 'Afrique'),
  FlCountry('territoires-palestiniens', 'ps', 'Palestinian Territories', 'Territoires palestiniens', 'Asie'),
  FlCountry('timor-oriental', 'tl', 'Timor-Leste', 'Timor oriental', 'Asie'),
  FlCountry('tonga', 'to', 'Tonga', 'Tonga', 'Océanie'),
  FlCountry('trinite-et-tobago', 'tt', 'Trinidad & Tobago', 'Trinité-et-Tobago', 'Amérique du Nord et centrale'),
  FlCountry('turkmenistan', 'tm', 'Turkmenistan', 'Turkménistan', 'Asie'),
  FlCountry('tuvalu', 'tv', 'Tuvalu', 'Tuvalu', 'Océanie'),
  FlCountry('vanuatu', 'vu', 'Vanuatu', 'Vanuatu', 'Océanie'),
  FlCountry('viet-nam', 'vn', 'Vietnam', 'Viêt Nam', 'Asie'),
  FlCountry('yemen', 'ye', 'Yemen', 'Yémen', 'Asie'),
  FlCountry('zambie', 'zm', 'Zambia', 'Zambie', 'Afrique'),
  FlCountry('zimbabwe', 'zw', 'Zimbabwe', 'Zimbabwe', 'Afrique'),
];

/// Catalogue footlive (pays → compétitions → lien du classement), complété chaque jour par KOUNADIA.
class FlCatalog {
  static const _url = 'https://raw.githubusercontent.com/barroapk/kfeed/flcat/flcat.json';
  static Map<String, dynamic>? _mem;
  static DateTime? _at;

  static Future<Map<String, dynamic>> countries() async {
    if (_mem != null && _at != null && DateTime.now().difference(_at!) < const Duration(hours: 1)) return _mem!;
    SharedPreferences? p;
    try {
      p = await SharedPreferences.getInstance();
      final r = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final body = utf8.decode(r.bodyBytes);
        final c = (jsonDecode(body) as Map)['countries'];
        if (c is Map) {
          _mem = Map<String, dynamic>.from(c);
          _at = DateTime.now();
          await p.setString('kflcat', body);
          return _mem!;
        }
      }
    } catch (_) {}
    try {
      final c = (jsonDecode(p?.getString('kflcat') ?? '{}') as Map)['countries'];
      if (c is Map) return _mem = Map<String, dynamic>.from(c);
    } catch (_) {}
    return _mem ?? {};
  }

  /// Pays du catalogue absents de la liste fixe.
  static Future<List<FlCountry>> extraCountries() async {
    final fixed = {for (final c in kFlCountries) c.slug};
    final out = <FlCountry>[];
    (await countries()).forEach((slug, v) {
      if (fixed.contains(slug) || v is! Map) return;
      final c = FlCountry(slug, '${v['flag'] ?? ''}', '${v['en'] ?? ''}', '${v['fr'] ?? ''}', '${v['sec'] ?? 'Europe'}');
      if (c.en.isNotEmpty && c.fr.isNotEmpty) _flFr.putIfAbsent(c.en, () => c.fr);
      out.add(c);
    });
    return out.where((c) => c.en.isNotEmpty).toList();
  }

  /// Compétitions connues d'un pays (titre → lien du classement).
  static Future<List<FlComp>> comps(String slug) async {
    final v = (await countries())[slug];
    final c = v is Map ? v['comps'] : null;
    if (c is! Map) return [];
    return [for (final e in c.entries) FlComp('${e.key}', e.value is Map && e.value['st'] != null ? '${e.value['st']}' : null)];
  }
}

/// Nom français d'un pays footlive (« Ivory Coast » → « Côte d'Ivoire »).
final _flFr = <String, String>{for (final c in [...kFlCountries, ...kFlMore]) c.en: c.fr};
String? flFrName(String en) => _flFr[en];

FlCountry? flCountryOf(String en) {
  final k = en.trim().toLowerCase();
  for (final c in [...kFlCountries, ...kFlMore]) {
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

  /// Compétitions d'un pays (jeunes et réserves exclues) : page du pays + catalogue KOUNADIA.
  static Future<List<FlComp>> competitions(FlCountry c) async {
    final out = <FlComp>[];
    final seen = <String>{};
    String h = '';
    try {
      h = await _get('/${c.slug}/');
    } catch (e) {
      // Page du pays indisponible : le catalogue suffit (sinon on remonte l'erreur).
      final cat = await FlCatalog.comps(c.slug);
      if (cat.isEmpty) rethrow;
      return cat;
    }
    final youth = RegExp(r'\bU-?1[3-9]\b|\bU-?2[0-3]\b|youth|reserve|primavera|moins de \d+ ans|jeunes|espoirs', caseSensitive: false);
    for (final m in RegExp(r"id='compName_\d+'([\s\S]*?)</table>").allMatches(h)) {
      final b = m[1]!;
      var title = _txt(RegExp(r'<h2>([\s\S]*?)</h2>').firstMatch(b)?[1] ?? '');
      if (title.toLowerCase().startsWith('${c.fr.toLowerCase()} ')) title = title.substring(c.fr.length + 1).trim();
      if (title.isEmpty || youth.hasMatch(title) || !seen.add(title)) continue;
      final st = RegExp(r"href='(/classement/[^']+)'").firstMatch(b)?[1];
      out.add(FlComp(title, st));
    }
    for (final x in await FlCatalog.comps(c.slug)) {
      if (seen.add(x.title)) out.add(x);
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
