class BrvmCompany {
  final String ticker;

  BrvmCompany({required this.ticker});

  factory BrvmCompany.fromJson(Map<String, dynamic> json) {
    return BrvmCompany(ticker: json['ticker'] as String? ?? '');
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
