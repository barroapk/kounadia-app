class BrvmCompany {
  final String ticker;
  final String? name;
  final String? country;

  BrvmCompany({required this.ticker, this.name, this.country});

  /// Nom à afficher : celui du catalogue si connu, sinon le ticker seul.
  String get displayName => name ?? ticker;

  factory BrvmCompany.fromJson(Map<String, dynamic> json) {
    return BrvmCompany(
      ticker: json['ticker'] as String? ?? '',
      name: json['name'] as String?,
      country: json['country'] as String?,
    );
  }
}

class BrvmCatalog {
  final List<BrvmCompany> companies;
  final List<String> indexes;
  final String? lastUpdated;

  BrvmCatalog({required this.companies, required this.indexes, this.lastUpdated});

  factory BrvmCatalog.fromJson(Map<String, dynamic> json) {
    return BrvmCatalog(
      companies: (json['companies'] as List<dynamic>? ?? [])
          .map((e) => BrvmCompany.fromJson(e as Map<String, dynamic>))
          .toList(),
      indexes: (json['indexes'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      lastUpdated: json['lastUpdated'] as String?,
    );
  }
}

class BrvmQuote {
  final String ticker;
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final double? previousClose;
  final double? change;
  final double? changePercent;

  BrvmQuote({
    required this.ticker,
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.previousClose,
    this.change,
    this.changePercent,
  });

  factory BrvmQuote.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return BrvmQuote(
      ticker: json['ticker'] as String? ?? '',
      date: json['date'] as String? ?? '',
      open: toDouble(json['open']),
      high: toDouble(json['high']),
      low: toDouble(json['low']),
      close: toDouble(json['close']),
      volume: toDouble(json['volume']),
      previousClose: json['previousClose'] != null ? toDouble(json['previousClose']) : null,
      change: json['change'] != null ? toDouble(json['change']) : null,
      changePercent: json['changePercent'] != null ? toDouble(json['changePercent']) : null,
    );
  }
}

class BrvmCandle {
  final String date;
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  BrvmCandle({
    required this.date,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
  });

  factory BrvmCandle.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return BrvmCandle(
      date: json['date'] as String? ?? '',
      open: toDouble(json['open']),
      high: toDouble(json['high']),
      low: toDouble(json['low']),
      close: toDouble(json['close']),
      volume: toDouble(json['volume']),
    );
  }
}

class BrvmSmaPoint {
  final String date;
  final double value;

  BrvmSmaPoint({required this.date, required this.value});

  factory BrvmSmaPoint.fromJson(Map<String, dynamic> json) {
    return BrvmSmaPoint(
      date: json['date'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BrvmIndicators {
  final String ticker;
  final String? lastDataDate;
  final List<BrvmSmaPoint> sma20;
  final List<BrvmSmaPoint> sma50;
  final List<BrvmSmaPoint> rsi14;
  final double? volatility20;
  final double? maxDrawdown;

  BrvmIndicators({
    required this.ticker,
    this.lastDataDate,
    required this.sma20,
    required this.sma50,
    this.rsi14 = const [],
    this.volatility20,
    this.maxDrawdown,
  });

  factory BrvmIndicators.fromJson(Map<String, dynamic> json) {
    return BrvmIndicators(
      ticker: json['ticker'] as String? ?? '',
      lastDataDate: json['lastDataDate'] as String?,
      sma20: (json['sma20'] as List<dynamic>? ?? [])
          .map((e) => BrvmSmaPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      sma50: (json['sma50'] as List<dynamic>? ?? [])
          .map((e) => BrvmSmaPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      rsi14: (json['rsi14'] as List<dynamic>? ?? [])
          .map((e) => BrvmSmaPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
      volatility20: (json['volatility20'] as num?)?.toDouble(),
      maxDrawdown: (json['maxDrawdown'] as num?)?.toDouble(),
    );
  }
}
