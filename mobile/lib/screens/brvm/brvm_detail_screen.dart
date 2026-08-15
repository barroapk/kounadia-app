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
    // Les indicateurs ne doivent jamais bloquer l'affichage du reste de la
    // fiche si leur calcul echoue : on les charge separement, en best-effort.
    BrvmIndicators? indicators;
    try {
      indicators = await _apiService.getBrvmIndicators(widget.ticker);
    } catch (_) {
      indicators = null;
    }
    return _BrvmDetailData(quote: quote, history: history ?? [], indicators: indicators);
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

  // Convertit une liste de points SMA en points de graphique alignes sur
  // l'index des candles affichees (par date), pas sur leur propre index :
  // la SMA peut avoir moins de points que les candles (periode de calcul).
  List<FlSpot> _smaSpots(List<BrvmCandle> candles, List<BrvmSmaPoint> sma) {
    if (sma.isEmpty) return [];

    final dateToIndex = <String, int>{
      for (int i = 0; i < candles.length; i++) candles[i].date: i,
    };

    final spots = <FlSpot>[];
    for (final point in sma) {
      final index = dateToIndex[point.date];
      if (index != null) {
        spots.add(FlSpot(index.toDouble(), point.value));
      }
    }
    return spots;
  }

  // Ne garde que les points SMA dont la date existe dans les candles de la
  // periode selectionnee (evite d'envoyer des points inutiles au graphique).
  List<BrvmSmaPoint> _filterSmaByPeriod(List<BrvmSmaPoint> sma, List<BrvmCandle> periodCandles) {
    if (sma.isEmpty || periodCandles.isEmpty) return [];
    final validDates = periodCandles.map((c) => c.date).toSet();
    return sma.where((p) => validDates.contains(p.date)).toList();
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 3, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }

  void _showTrendInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Comment ça marche ?", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(
                    "Une moyenne mobile calcule le cours moyen d'une action sur une periode recente, ce qui rend la tendance plus facile a lire qu'en regardant seulement le cours du jour.",
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Moyenne courte : moyenne des 20 dernieres seances.\nMoyenne longue : moyenne des 50 dernieres seances.",
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Quand la moyenne courte passe au-dessus de la moyenne longue, cela peut indiquer que la dynamique recente devient plus forte. L'inverse peut indiquer un ralentissement.",
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 19, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Important : ceci n'est pas une garantie que le cours va monter ou baisser. C'est une lecture de tendance passee, pas une prediction.",
                          style: TextStyle(color: Colors.grey[700], height: 1.45, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPressureInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Qu'est-ce que la pression du marché ?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(
                    "Cet indicateur mesure la force des mouvements du cours sur les 14 dernieres seances, sur une echelle de 0 a 100.",
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "En dessous de 30 : pression vendeuse forte.\nEntre 30 et 70 : zone normale.\nAu-dessus de 70 : pression acheteuse forte.",
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 19, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Important : un niveau eleve ne signifie pas automatiquement que le cours va baisser, ni un niveau bas qu'il va monter. C'est une mesure de la dynamique recente, pas une prediction.",
                          style: TextStyle(color: Colors.grey[700], height: 1.45, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVolatilityInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Qu'est-ce que les variations du cours ?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(
                    "Cet indicateur mesure l'amplitude des mouvements du cours sur les 20 dernieres seances. Plus il est eleve, plus le cours bouge fortement d'un jour a l'autre.",
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 19, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Important : des variations elevees ne signifient pas forcement un risque de perte. Elles signifient que le cours peut evoluer fortement, dans un sens comme dans l'autre.",
                          style: TextStyle(color: Colors.grey[700], height: 1.45, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDrawdownInfo() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Qu'est-ce que la plus forte baisse ?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text(
                    "C'est la plus grosse chute observee entre un sommet du cours et le creux le plus bas qui a suivi, sur toute la periode d'historique disponible.",
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Cela donne une idee du risque de perte que cette action a deja connu par le passe.",
                    style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded, size: 19, color: Colors.orange[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Important : ce chiffre decrit le passe. Il ne predit pas la prochaine baisse et ne garantit pas qu'elle sera du meme ordre.",
                          style: TextStyle(color: Colors.grey[700], height: 1.45, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _simpleIndicatorCard({
    required String title,
    required String badge,
    required Color badgeColor,
    required String explanation,
    required VoidCallback onInfoTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    Text(badge, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: badgeColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(explanation, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          InkWell(
            onTap: onInfoTap,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.info_outline, size: 18, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _volatilityCard(BrvmIndicators? indicators) {
    if (indicators?.volatility20 == null) return const SizedBox.shrink();
    final v = indicators!.volatility20!;

    String badge;
    Color color;
    if (v < 20) {
      badge = "Faibles";
      color = const Color(0xFF16A34A);
    } else if (v < 40) {
      badge = "Modérées";
      color = const Color(0xFFF59E0B);
    } else {
      badge = "Élevées";
      color = const Color(0xFFDC2626);
    }

    return _simpleIndicatorCard(
      title: "Variations du cours",
      badge: badge,
      badgeColor: color,
      explanation: "Cette action connaît des variations de prix ${badge.toLowerCase()} récemment.",
      onInfoTap: _showVolatilityInfo,
    );
  }

  Widget _drawdownCard(BrvmIndicators? indicators) {
    if (indicators?.maxDrawdown == null) return const SizedBox.shrink();
    final dd = indicators!.maxDrawdown!;

    return _simpleIndicatorCard(
      title: "Plus forte baisse historique",
      badge: "${dd.toStringAsFixed(1)}%",
      badgeColor: const Color(0xFFDC2626),
      explanation: "Plus grosse chute observée entre un sommet et le creux suivant sur l'historique disponible.",
      onInfoTap: _showDrawdownInfo,
    );
  }

  Widget _pressureCard(BrvmIndicators? indicators) {
    if (indicators == null || indicators.rsi14.isEmpty) return const SizedBox.shrink();

    final value = indicators.rsi14.last.value.clamp(0, 100);
    final lastDate = indicators.rsi14.last.date;

    String label;
    Color color;

    if (value < 30) {
      label = "Faible";
      color = const Color(0xFFDC2626);
    } else if (value > 70) {
      label = "Forte";
      color = const Color(0xFFF59E0B);
    } else {
      label = "Normale";
      color = const Color(0xFF16A34A);
    }

    return Container(
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
          Row(
            children: [
              Expanded(
                child: Text("Pression du marché", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
              const SizedBox(width: 4),
              InkWell(
                onTap: _showPressureInfo,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.info_outline, size: 18, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(height: 10, color: Colors.grey[200]),
                FractionallySizedBox(
                  widthFactor: value / 100,
                  child: Container(height: 10, color: color),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${value.toStringAsFixed(0)}/100", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              Text("Donnée du $lastDate", style: TextStyle(color: Colors.grey[400], fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trendCard(BrvmIndicators? indicators) {
    if (indicators == null || indicators.sma20.isEmpty || indicators.sma50.isEmpty) {
      return const SizedBox.shrink();
    }

    final lastSma20 = indicators.sma20.last.value;
    final lastSma50 = indicators.sma50.last.value;
    final diff = lastSma20 - lastSma50;
    // Seuil de 0.5% pour eviter d'afficher "positive/negative" sur un ecart
    // negligeable qui serait en realite un signal neutre.
    final threshold = lastSma50.abs() * 0.005;

    String label;
    Color color;
    IconData icon;
    String explanation;

    if (diff > threshold) {
      label = "Tendance positive";
      color = const Color(0xFF16A34A);
      icon = Icons.trending_up;
      explanation = "La tendance recente est plus forte que la tendance de fond.";
    } else if (diff < -threshold) {
      label = "Tendance negative";
      color = const Color(0xFFDC2626);
      icon = Icons.trending_down;
      explanation = "La tendance recente est plus faible que la tendance de fond.";
    } else {
      label = "Tendance neutre";
      color = Colors.grey[600]!;
      icon = Icons.trending_flat;
      explanation = "Le marche ne montre pas encore une direction clairement etablie.";
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                const SizedBox(height: 2),
                Text(explanation, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          InkWell(
            onTap: _showTrendInfo,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.info_outline, size: 18, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chart(List<BrvmCandle> candles, {List<BrvmSmaPoint> sma20 = const [], List<BrvmSmaPoint> sma50 = const []}) {
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
            if (_smaSpots(candles, sma20).isNotEmpty)
              LineChartBarData(
                spots: _smaSpots(candles, sma20),
                isCurved: false,
                color: const Color(0xFF2563EB),
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
            if (_smaSpots(candles, sma50).isNotEmpty)
              LineChartBarData(
                spots: _smaSpots(candles, sma50),
                isCurved: false,
                color: const Color(0xFFF59E0B),
                barWidth: 1.5,
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );
  }

  Widget _volumeChart(List<BrvmCandle> candles) {
    if (candles.length < 2) {
      return const SizedBox.shrink();
    }

    final maxVolume = candles.map((c) => c.volume).reduce((a, b) => a > b ? a : b);

    if (maxVolume <= 0) {
      return const SizedBox(
        height: 100,
        child: Center(
          child: Text(
            "Aucun volume disponible pour cette periode.",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "VOLUME",
            style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.7),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 100,
          child: BarChart(
            BarChartData(
              minY: 0,
              maxY: maxVolume * 1.1,
              alignment: BarChartAlignment.spaceBetween,
              groupsSpace: 0,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    if (groupIndex < 0 || groupIndex >= candles.length) return null;
                    final candle = candles[groupIndex];
                    return BarTooltipItem(
                      "${_formatDateShort(candle.date)}\nVolume : ${candle.volume.round()}",
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                    );
                  },
                ),
              ),
              barGroups: [
                for (int i = 0; i < candles.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: candles[i].volume,
                        width: candles.length > 100 ? 2 : 4,
                        borderRadius: BorderRadius.zero,
                        color: candles[i].close >= candles[i].open
                            ? const Color(0xFF16A34A).withOpacity(0.55)
                            : const Color(0xFFDC2626).withOpacity(0.55),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
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
                    _trendCard(snapshot.data!.indicators),
                    const SizedBox(height: 12),
                    _pressureCard(snapshot.data!.indicators),
                    const SizedBox(height: 12),
                    _volatilityCard(snapshot.data!.indicators),
                    const SizedBox(height: 12),
                    _drawdownCard(snapshot.data!.indicators),
                    const SizedBox(height: 12),
                    _chart(
                      periodCandles,
                      sma20: _filterSmaByPeriod(snapshot.data!.indicators?.sma20 ?? [], periodCandles),
                      sma50: _filterSmaByPeriod(snapshot.data!.indicators?.sma50 ?? [], periodCandles),
                    ),
                    if ((snapshot.data!.indicators?.sma20.isNotEmpty ?? false) ||
                        (snapshot.data!.indicators?.sma50.isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legendDot(const Color(0xFF16A34A), "Prix"),
                            const SizedBox(width: 12),
                            _legendDot(const Color(0xFF2563EB), "Moyenne courte"),
                            const SizedBox(width: 12),
                            _legendDot(const Color(0xFFF59E0B), "Moyenne longue"),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    _volumeChart(periodCandles),
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
  final BrvmIndicators? indicators;

  _BrvmDetailData({required this.quote, required this.history, this.indicators});
}
