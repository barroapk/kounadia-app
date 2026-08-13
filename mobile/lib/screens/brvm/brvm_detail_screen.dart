import "package:flutter/material.dart";
import "../../models/brvm.dart";
import "../../services/api_service.dart";

class BrvmDetailScreen extends StatefulWidget {
  final String ticker;

  const BrvmDetailScreen({super.key, required this.ticker});

  @override
  State<BrvmDetailScreen> createState() => _BrvmDetailScreenState();
}

class _BrvmDetailScreenState extends State<BrvmDetailScreen> {
  final ApiService _apiService = ApiService();
  Future<_BrvmDetailData>? _dataFuture;

  static const _weekdays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"];
  static const _months = [
    "janvier", "février", "mars", "avril", "mai", "juin",
    "juillet", "août", "septembre", "octobre", "novembre", "décembre",
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  Future<_BrvmDetailData> _loadData() async {
    final quote = await _apiService.getBrvmQuote(widget.ticker);
    final history = await _apiService.getBrvmHistory(widget.ticker);
    return _BrvmDetailData(quote: quote, history: history ?? []);
  }

  String _formatFcfa(double value) {
    final rounded = value.round();
    final str = rounded.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write(" ");
      buffer.write(str[i]);
    }
    return "${buffer.toString()} FCFA";
  }

  String _formatDate(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    final weekday = _weekdays[date.weekday - 1];
    final month = _months[date.month - 1];
    return "${weekday[0].toUpperCase()}${weekday.substring(1)} ${date.day} $month ${date.year}";
  }

  String _formatDateShort(String isoDate) {
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(title: Text(widget.ticker)),
      body: FutureBuilder<_BrvmDetailData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || snapshot.data?.quote == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Impossible de charger cette action."),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text("Réessayer")),
                  ],
                ),
              ),
            );
          }

          final quote = snapshot.data!.quote!;
          final history = snapshot.data!.history;
          final change = quote.change ?? 0;
          final isUp = change > 0;
          final isDown = change < 0;
          final changeColor = isUp
              ? const Color(0xFF16A34A)
              : isDown
                  ? const Color(0xFFDC2626)
                  : Colors.grey;

          // Les 30 dernières séances, les plus récentes en premier.
          final recentHistory = history.reversed.take(30).toList();

          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(quote.ticker, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text(
                      _formatFcfa(quote.close),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 30, color: Color(0xFF16A34A)),
                    ),
                    const SizedBox(height: 6),
                    if (quote.change != null && quote.changePercent != null)
                      Row(
                        children: [
                          Icon(
                            isUp ? Icons.arrow_upward : (isDown ? Icons.arrow_downward : Icons.remove),
                            size: 16,
                            color: changeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${isUp ? '+' : ''}${quote.change!.round()} FCFA  (${isUp ? '+' : ''}${quote.changePercent!.toStringAsFixed(2)}%)",
                            style: TextStyle(color: changeColor, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),
                    Text(_formatDate(quote.date), style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("DERNIÈRE SÉANCE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                    const Divider(height: 20),
                    _statRow("Ouverture", _formatFcfa(quote.open)),
                    _statRow("Plus haut", _formatFcfa(quote.high)),
                    _statRow("Plus bas", _formatFcfa(quote.low)),
                    _statRow("Clôture", _formatFcfa(quote.close)),
                    _statRow("Volume", quote.volume.round().toString()),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (recentHistory.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("HISTORIQUE RÉCENT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                      const SizedBox(height: 8),
                      ...recentHistory.map((c) {
                        final dayChange = c.close - c.open;
                        final dayColor = dayChange > 0
                            ? const Color(0xFF16A34A)
                            : dayChange < 0
                                ? const Color(0xFFDC2626)
                                : Colors.grey;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              SizedBox(width: 80, child: Text(_formatDateShort(c.date), style: const TextStyle(fontSize: 12))),
                              Expanded(
                                child: Text(
                                  "${_formatFcfa(c.open)} → ${_formatFcfa(c.close)}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Icon(
                                dayChange > 0 ? Icons.arrow_upward : (dayChange < 0 ? Icons.arrow_downward : Icons.remove),
                                size: 14,
                                color: dayColor,
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BrvmDetailData {
  final BrvmQuote? quote;
  final List<BrvmCandle> history;

  _BrvmDetailData({required this.quote, required this.history});
}
