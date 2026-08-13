import "package:flutter/material.dart";
import "package:fl_chart/fl_chart.dart";
import "../../models/brvm.dart";
import "../../services/api_service.dart";

enum _Period { m1, m3, m6, y1, all }

class BrvmDetailScreen extends StatefulWidget {
  final String ticker;

  const BrvmDetailScreen({super.key, required this.ticker});

  @override
  State<BrvmDetailScreen> createState() => _BrvmDetailScreenState();
}

class _BrvmDetailScreenState extends State<BrvmDetailScreen> {
  final ApiService _apiService = ApiService();
  Future<_BrvmDetailData>? _dataFuture;
  _Period _selectedPeriod = _Period.m3;

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

  // Filtre l'historique selon la période sélectionnée. "all" ne filtre rien.
  // Toujours basé sur la dernière date DISPONIBLE dans les données (pas la
  // date système), pour rester cohérent même si la source a du retard.
  List<BrvmCandle> _filterByPeriod(List<BrvmCandle> history, _Period period) {
    if (history.isEmpty || period == _Period.all) return history;

    final lastDate = DateTime.tryParse(history.last.date);
    if (lastDate == null) return history;

    int days;
    switch (period) {
      case _Period.m1:
        days = 30;
        break;
      case _Period.m3:
        days = 90;
        break;
      case _Period.m6:
        days = 182;
        break;
      case _Period.y1:
        days = 365;
        break;
      case _Period.all:
        return history;
    }

    final cutoff = lastDate.subtract(Duration(days: days));
    return history.where((c) {
      final d = DateTime.tryParse(c.date);
      return d != null && !d.isBefore(cutoff);
    }).toList();
  }

  String _periodLabel(_Period p) {
    switch (p) {
      case _Period.m1:
        return "1M";
      case _Period.m3:
        return "3M";
      case _Period.m6:
        return "6M";
      case _Period.y1:
        return "1A";
      case _Period.all:
        return "Tout";
    }
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

  Widget _periodSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: _Period.values.map((p) {
        final isSelected = p == _selectedPeriod;
        return GestureDetector(
          onTap: () => setState(() => _selectedPeriod = p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF16A34A) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _periodLabel(p),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _chart(List<BrvmCandle> candles) {
    if (candles.length < 2) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("Historique insuffisant pour cette période.")),
      );
    }

    final spots = <FlSpot>[
      for (int i = 0; i < candles.length; i++) FlSpot(i.toDouble(), candles[i].close),
    ];

    final minY = candles.map((c) => c.close).reduce((a, b) => a < b ? a : b);
    final maxY = candles.map((c) => c.close).reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;
    final padding = range == 0 ? (maxY.abs() * 0.05).clamp(1.0, double.infinity) : range * 0.1;

    final firstClose = candles.first.close;
    final lastClose = candles.last.close;
    final periodUp = lastClose >= firstClose;
    final lineColor = periodUp ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return SizedBox(
      height: 220,
      child: LineChart(
        LineChartData(
          minY: minY - padding,
          maxY: maxY + padding,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (range == 0 ? maxY.abs() * 0.1 : range / 3).clamp(1.0, double.infinity),
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.15), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            show: true,
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.round().toString(),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                // 4 repères répartis sur la période, pour ne pas surcharger l'axe.
                interval: (candles.length / 4).clamp(1, double.infinity).floorToDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= candles.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _formatDateShort(candles[index].date),
                      style: TextStyle(color: Colors.grey[500], fontSize: 9),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) {
                return spots.map((spot) {
                  final index = spot.x.toInt();
                  if (index < 0 || index >= candles.length) return null;
                  final candle = candles[index];
                  return LineTooltipItem(
                    "${_formatDateShort(candle.date)}\n${_formatFcfa(candle.close)}",
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              color: lineColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: lineColor.withOpacity(0.1)),
            ),
          ],
        ),
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

          final periodCandles = _filterByPeriod(history, _selectedPeriod);
          final recentHistory = history.reversed.take(30).toList();

          // Statistiques sur la période sélectionnée, dérivées directement des
          // candles affichées (pas un indicateur "magique", juste haut/bas/variation).
          double? periodHigh, periodLow, periodChangePercent;
          if (periodCandles.isNotEmpty) {
            periodHigh = periodCandles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
            periodLow = periodCandles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
            final first = periodCandles.first.close;
            final last = periodCandles.last.close;
            if (first != 0) periodChangePercent = ((last - first) / first) * 100;
          }

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
                    Text(
                      "Dernière donnée disponible dans notre source. Peut différer de la séance en cours.",
                      style: TextStyle(color: Colors.grey[400], fontSize: 10, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    _periodSelector(),
                    const SizedBox(height: 12),
                    _chart(periodCandles),
                    if (periodHigh != null && periodLow != null) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _miniStat("Plus haut", _formatFcfa(periodHigh)),
                            _miniStat("Plus bas", _formatFcfa(periodLow)),
                            if (periodChangePercent != null)
                              _miniStat(
                                "Variation",
                                "${periodChangePercent >= 0 ? '+' : ''}${periodChangePercent.toStringAsFixed(2)}%",
                                color: periodChangePercent >= 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
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

  Widget _miniStat(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
      ],
    );
  }
}

class _BrvmDetailData {
  final BrvmQuote? quote;
  final List<BrvmCandle> history;

  _BrvmDetailData({required this.quote, required this.history});
}
