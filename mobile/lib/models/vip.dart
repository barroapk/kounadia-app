import 'coupon.dart';
import '../services/primatips_service.dart' show frLeague;

class VipLeg {
  final int id;
  final String url, home, away, league, flag, pick;
  final String? hl, al, score;
  final DateTime? date;
  final double odd, conf;
  final List<String> reasons;
  String result;

  VipLeg.fromJson(Map<String, dynamic> j)
      : id = (j['id'] as num).toInt(),
        url = (j['url'] ?? '').toString(),
        home = (j['home'] ?? '').toString(),
        away = (j['away'] ?? '').toString(),
        league = frLeague((j['league'] ?? '').toString()),
        flag = (j['flag'] ?? '').toString(),
        pick = (j['pick'] ?? '').toString(),
        hl = j['hl']?.toString(),
        al = j['al']?.toString(),
        score = j['score']?.toString(),
        date = DateTime.tryParse((j['date'] ?? '').toString())?.toLocal(),
        odd = (j['odd'] as num).toDouble(),
        conf = (j['conf'] as num).toDouble(),
        reasons = ((j['reasons'] as List?) ?? const []).map((e) => e.toString()).toList(),
        result = (j['result'] ?? 'pending').toString();

  Leg toLeg() => Leg(
        matchId: id,
        home: home,
        away: away,
        league: league,
        flag: flag,
        pick: pick,
        odd: odd,
        prob: conf.round(),
        date: date,
        result: result,
      );

  String get label => toLeg().label;
}

class VipCoupon {
  final int tier;
  final double total, prob;
  final List<VipLeg> legs;

  VipCoupon.fromJson(Map<String, dynamic> j)
      : tier = (j['tier'] as num).toInt(),
        total = (j['total'] as num).toDouble(),
        prob = ((j['prob'] ?? 0) as num).toDouble(),
        legs = ((j['legs'] as List?) ?? const [])
            .map((e) => VipLeg.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

  String get status {
    final r = legs.map((l) => l.result).toList();
    if (r.contains('lost')) return 'lost';
    if (r.every((x) => x == 'won' || x == 'void')) return 'won';
    if (r.any((x) => x == 'live' || x == 'won')) return 'live';
    return 'pending';
  }

  double get avgConf => legs.isEmpty ? 0 : legs.map((l) => l.conf).reduce((a, b) => a + b) / legs.length;

  Coupon toCoupon() => Coupon(DateTime.now(), legs.map((l) => l.toLeg()).toList());
}

class VipDay {
  final String date;
  final int analyzed;
  final List<VipCoupon> coupons;

  VipDay.fromJson(Map<String, dynamic> j)
      : date = (j['date'] ?? '').toString(),
        analyzed = ((j['analyzed'] ?? 0) as num).toInt(),
        coupons = ((j['coupons'] as List?) ?? const [])
            .map((e) => VipCoupon.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

  int get won => coupons.where((c) => c.status == 'won').length;
}
