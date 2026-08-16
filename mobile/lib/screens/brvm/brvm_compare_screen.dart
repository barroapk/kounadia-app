import "package:flutter/material.dart";
import "../../models/brvm.dart";
import "../../services/api_service.dart";

class BrvmCompareScreen extends StatefulWidget {
  const BrvmCompareScreen({super.key});

  @override
  State<BrvmCompareScreen> createState() => _BrvmCompareScreenState();
}

class _BrvmCompareScreenState extends State<BrvmCompareScreen> {
  final ApiService _apiService = ApiService();
  static const int _maxTickers = 3;

  Future<BrvmCatalog>? _catalogFuture;
  final List<String> _selectedTickers = [];

  Future<Map<String, _CompareData>>? _compareDataFuture;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _apiService.getBrvmCatalog();
  }

  Future<Map<String, _CompareData>> _loadCompareData(List<String> tickers) async {
    // Chargement en parallele pour les 2-3 actions : evite l'effet de
    // lenteur d'un chargement sequentiel (quote+indicators x N tickers).
    final results = await Future.wait(tickers.map((ticker) async {
      final quote = await _apiService.getBrvmQuote(ticker);
      final indicators = await _apiService.getBrvmIndicators(ticker);
      return MapEntry(ticker, _CompareData(quote: quote, indicators: indicators));
    }));

    return Map<String, _CompareData>.fromEntries(results);
  }

  void _addTicker(String ticker) {
    if (_selectedTickers.contains(ticker) || _selectedTickers.length >= _maxTickers) return;
    setState(() {
      _selectedTickers.add(ticker);
      if (_selectedTickers.length >= 2) {
        _compareDataFuture = _loadCompareData(_selectedTickers);
      }
    });
  }

  void _removeTicker(String ticker) {
    setState(() {
      _selectedTickers.remove(ticker);
      if (_selectedTickers.length >= 2) {
        _compareDataFuture = _loadCompareData(_selectedTickers);
      } else {
        _compareDataFuture = null;
      }
    });
  }

  Future<void> _openSearch() async {
    final catalog = await (_catalogFuture ?? Future.value(null));
    if (catalog == null || !mounted) return;

    final available = catalog.companies.where((c) => !_selectedTickers.contains(c.ticker)).toList();

    final selected = await showModalBottomSheet<BrvmCompany>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TickerSearchSheet(companies: available),
    );

    if (selected != null) {
      _addTicker(selected.ticker);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(title: const Text("Comparer des actions")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ..._selectedTickers.map((t) => Chip(
                      label: Text(t),
                      onDeleted: () => _removeTicker(t),
                    )),
                if (_selectedTickers.length < _maxTickers)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text("Ajouter"),
                    onPressed: _openSearch,
                  ),
              ],
            ),
          ),
          Expanded(
            child: _selectedTickers.length < 2
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Sélectionnez au moins 2 actions pour les comparer.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                  )
                : FutureBuilder<Map<String, _CompareData>>(
                    future: _compareDataFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        return const Center(child: Text("Impossible de charger la comparaison."));
                      }
                      return _CompareGrid(tickers: _selectedTickers, data: snapshot.data!);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CompareData {
  final BrvmQuote? quote;
  final BrvmIndicators? indicators;
  _CompareData({this.quote, this.indicators});
}

class _TickerSearchSheet extends StatefulWidget {
  final List<BrvmCompany> companies;
  const _TickerSearchSheet({required this.companies});

  @override
  State<_TickerSearchSheet> createState() => _TickerSearchSheetState();
}

class _TickerSearchSheetState extends State<_TickerSearchSheet> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final filtered = widget.companies.where((c) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return c.displayName.toLowerCase().contains(q) || c.ticker.toLowerCase().contains(q);
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Rechercher une société...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final c = filtered[index];
                    return ListTile(
                      title: Text(c.displayName),
                      subtitle: Text(c.ticker),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


class _CompareGrid extends StatelessWidget {
  final List<String> tickers;
  final Map<String, _CompareData> data;

  const _CompareGrid({
    required this.tickers,
    required this.data,
  });

  Color _scoreColor(double score) {
    if (score >= 70) return const Color(0xFF16A34A);
    if (score >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  String _scoreLabel(double score) {
    if (score >= 70) return "Configuration solide";
    if (score >= 50) return "Configuration modérée";
    if (score >= 30) return "Configuration limitée";
    return "Configuration faible";
  }

  String _directionLabel(String direction) {
    switch (direction) {
      case "haussiere":
        return "Haussière";
      case "baissiere":
        return "Baissière";
      default:
        return "Neutre";
    }
  }

  Color _directionColor(String direction) {
    switch (direction) {
      case "haussiere":
        return const Color(0xFF16A34A);
      case "baissiere":
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _directionIcon(String direction) {
    switch (direction) {
      case "haussiere":
        return Icons.north_east;
      case "baissiere":
        return Icons.south_east;
      default:
        return Icons.east;
    }
  }

  String _level(double value) {
    if (value >= 70) return "Fort";
    if (value >= 50) return "Modéré";
    if (value >= 30) return "Limité";
    return "Faible";
  }

  String _stabilityLevel(double value) {
    if (value >= 70) return "Très stable";
    if (value >= 50) return "Stable";
    if (value >= 30) return "Variations élevées";
    return "Très variable";
  }

  String _pressureLevel(double value) {
    if (value >= 70) return "Très forte";
    if (value >= 50) return "Forte";
    if (value >= 30) return "Modérée";
    return "Faible";
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _indicatorLabel(String title, String subtitle) {
    return SizedBox(
      width: 125,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            const SizedBox(height: 3),
            Text(subtitle, style: const TextStyle(fontSize: 9, height: 1.25, color: Color(0xFF9CA3AF))),
          ],
        ),
      ),
    );
  }

  Widget _scoreCell(BrvmKounadiaScore? ks) {
    if (ks == null) return const _EmptyCell();
    final color = _scoreColor(ks.score);

    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          children: [
            Text(ks.score.toStringAsFixed(1), style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900, color: color)),
            const Text("/100", style: TextStyle(fontSize: 9, color: Color(0xFF9CA3AF))),
            const SizedBox(height: 5),
            Text(_scoreLabel(ks.score), textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _directionCell(BrvmKounadiaScore? ks) {
    if (ks == null) return const _EmptyCell();
    final color = _directionColor(ks.direction);

    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_directionIcon(ks.direction), size: 18, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _directionLabel(ks.direction),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberCell(double? value, {String suffix = "", bool percent = false}) {
    if (value == null) return const _EmptyCell();
    return SizedBox(
      width: 150,
      child: Center(
        child: Text(
          "${value.toStringAsFixed(1)}${percent ? "%" : suffix}",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
      ),
    );
  }

  Widget _scoreComponentCell(double? value, {required String Function(double) label}) {
    if (value == null) return const _EmptyCell();
    final color = _scoreColor(value);

    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          children: [
            Text(value.toStringAsFixed(1), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: value.clamp(0, 100) / 100,
                minHeight: 5,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(label(value), textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  Widget _row({required Widget label, required List<Widget> cells, bool highlighted = false}) {
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFFFFF7ED) : Colors.white,
        border: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.7)),
      ),
      child: Row(children: [label, ...cells]),
    );
  }

  Widget _companyHeader(String ticker) {
    final item = data[ticker];
    final quote = item?.quote;

    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
        child: Column(
          children: [
            Text(ticker, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
            const SizedBox(height: 5),
            if (quote != null)
              Text(
                "${quote.close.toStringAsFixed(0)} FCFA",
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _strengths(BrvmScoreComponents c) {
    final result = <String>[];
    if (c.trend >= 65) result.add("Tendance favorable");
    if (c.momentum >= 65) result.add("Momentum positif");
    if (c.stability >= 65) result.add("Variations contenues");
    if (c.pressure <= 35) result.add("Intensité modérée");
    return result;
  }

  List<String> _warnings(BrvmScoreComponents c) {
    final result = <String>[];
    if (c.trend <= 35) result.add("Tendance défavorable");
    if (c.momentum <= 35) result.add("Momentum négatif");
    if (c.stability <= 40) result.add("Variations importantes");
    if (c.pressure >= 65) result.add("Intensité élevée");
    return result;
  }

  Widget _readingCell(BrvmKounadiaScore? ks) {
    if (ks == null) return const _EmptyCell();
    final strengths = _strengths(ks.components);
    final warnings = _warnings(ks.components);

    return SizedBox(
      width: 150,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...strengths.take(2).map((text) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle, size: 13, color: Color(0xFF16A34A)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(text, style: const TextStyle(fontSize: 9, height: 1.3, color: Color(0xFF4B5563)))),
                    ],
                  ),
                )),
            ...warnings.take(2).map((text) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 13, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Expanded(child: Text(text, style: const TextStyle(fontSize: 9, height: 1.3, color: Color(0xFF4B5563)))),
                    ],
                  ),
                )),
            if (strengths.isEmpty && warnings.isEmpty)
              const Text("Configuration neutre", style: TextStyle(fontSize: 9, color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final columns = <Widget>[
      SizedBox(
        width: 125,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 14),
          child: Text(
            "INDICATEUR",
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: Colors.grey[500]),
          ),
        ),
      ),
      ...tickers.map(_companyHeader),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("SYNTHÈSE"),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Row(children: columns),
                  _row(
                    label: _indicatorLabel("Score KOUNADIA", "Configuration actuelle"),
                    cells: tickers.map((t) => _scoreCell(data[t]?.indicators?.kounadiaScore)).toList(),
                    highlighted: true,
                  ),
                  _row(
                    label: _indicatorLabel("Direction", "Observation actuelle"),
                    cells: tickers.map((t) => _directionCell(data[t]?.indicators?.kounadiaScore)).toList(),
                  ),
                ],
              ),
            ),
          ),
          _sectionTitle("INDICATEURS"),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _row(
                    label: _indicatorLabel("Tendance", "SMA20 vs SMA50"),
                    cells: tickers.map((t) => _scoreComponentCell(data[t]?.indicators?.kounadiaScore?.components.trend, label: _level)).toList(),
                  ),
                  _row(
                    label: _indicatorLabel("Momentum", "20 séances"),
                    cells: tickers.map((t) => _scoreComponentCell(data[t]?.indicators?.kounadiaScore?.components.momentum, label: _level)).toList(),
                  ),
                  _row(
                    label: _indicatorLabel("Stabilité", "Variations récentes"),
                    cells: tickers.map((t) => _scoreComponentCell(data[t]?.indicators?.kounadiaScore?.components.stability, label: _stabilityLevel)).toList(),
                  ),
                  _row(
                    label: _indicatorLabel("Intensité", "Écart RSI / neutre"),
                    cells: tickers.map((t) => _scoreComponentCell(data[t]?.indicators?.kounadiaScore?.components.pressure, label: _pressureLevel)).toList(),
                  ),
                  _row(
                    label: _indicatorLabel("Momentum réel", "Variation 20 séances"),
                    cells: tickers.map((t) => _numberCell(data[t]?.indicators?.kounadiaScore?.momentum20Percent, percent: true)).toList(),
                  ),
                  _row(
                    label: _indicatorLabel("Fiabilité", "Historique disponible"),
                    cells: tickers.map((t) => _scoreComponentCell(
                          data[t]?.indicators?.kounadiaScore?.dataReliability,
                          label: (v) {
                            if (v >= 100) return "Très bonne";
                            if (v >= 60) return "Bonne";
                            if (v >= 30) return "Limitée";
                            return "Faible";
                          },
                        )).toList(),
                  ),
                ],
              ),
            ),
          ),
          _sectionTitle("LECTURE DES CHIFFRES"),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Row(
                children: [
                  _indicatorLabel("Lecture", "Forces et vigilances"),
                  ...tickers.map((t) => _readingCell(data[t]?.indicators?.kounadiaScore)),
                ],
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 16, 12, 24),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    "Le comparateur présente les configurations observées à partir des mêmes indicateurs. Il ne prédit pas l'évolution future des cours et ne constitue pas une recommandation d'achat ou de vente.",
                    style: TextStyle(fontSize: 11, height: 1.45, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCell extends StatelessWidget {
  const _EmptyCell();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 150,
      height: 60,
      child: Center(
        child: Text("—", style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
      ),
    );
  }
}

