import "package:flutter/material.dart";
import "../../models/brvm.dart";
import "../../services/api_service.dart";
import "brvm_detail_screen.dart";

class _BrvmRow {
  final BrvmCompany company;
  final BrvmQuote? quote;

  _BrvmRow({required this.company, this.quote});
}

class BrvmScreen extends StatefulWidget {
  const BrvmScreen({super.key});

  @override
  State<BrvmScreen> createState() => _BrvmScreenState();
}

class _BrvmScreenState extends State<BrvmScreen> {
  final ApiService _apiService = ApiService();
  Future<List<_BrvmRow>>? _rowsFuture;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _rowsFuture = _loadRows();
    });
  }

  Future<List<_BrvmRow>> _loadRows() async {
    final catalog = await _apiService.getBrvmCatalog();
    final quotes = await _apiService.getBrvmQuotes();
    final quoteByTicker = {for (final q in quotes) q.ticker: q};

    final rows = catalog.companies
        .map((c) => _BrvmRow(company: c, quote: quoteByTicker[c.ticker]))
        .toList();

    rows.sort((a, b) => a.company.displayName.toUpperCase().compareTo(b.company.displayName.toUpperCase()));
    return rows;
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

  List<_BrvmRow> _filter(List<_BrvmRow> rows) {
    if (_searchQuery.trim().isEmpty) return rows;
    final query = _searchQuery.trim().toLowerCase();
    return rows.where((r) {
      return r.company.displayName.toLowerCase().contains(query) ||
          r.company.ticker.toLowerCase().contains(query) ||
          (r.company.country?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Rechercher une société...",
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _load(),
            child: FutureBuilder<List<_BrvmRow>>(
              future: _rowsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const Text("Impossible de charger les cotations BRVM."),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _load, child: const Text("Réessayer")),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final rows = _filter(snapshot.data ?? []);
                if (rows.isEmpty) {
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text("Aucun résultat.")),
                      ),
                    ],
                  );
                }

                return ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final q = row.quote;
                    final change = q?.change ?? 0;
                    final isUp = change > 0;
                    final isDown = change < 0;
                    final changeColor = isUp
                        ? const Color(0xFF16A34A)
                        : isDown
                            ? const Color(0xFFDC2626)
                            : Colors.grey;

                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BrvmDetailScreen(ticker: row.company.ticker)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.company.displayName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    [row.company.ticker, if (row.company.country != null) row.company.country].join(" · "),
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                  ),
                                  if (q != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatFcfa(q.close),
                                      style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (q?.changePercent != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: changeColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isUp ? Icons.arrow_upward : (isDown ? Icons.arrow_downward : Icons.remove),
                                      size: 14,
                                      color: changeColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${q!.changePercent!.abs().toStringAsFixed(2)}%",
                                      style: TextStyle(color: changeColor, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
