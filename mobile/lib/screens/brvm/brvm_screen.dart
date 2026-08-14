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
  Future<List<BrvmQuote>>? _indicesFuture;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _rowsFuture = _loadRows();
      _indicesFuture = _apiService.getBrvmIndices();
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

  String _formatIndex(double value) {
    return value.toStringAsFixed(2).replaceAll(".", ",");
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

  void _showIndexInfo(String ticker) {
    final isComposite = ticker == "BRVMC";

    final title = isComposite ? "BRVM Composite" : "BRVM30";

    final description = isComposite
        ? "Le BRVM Composite donne une vision globale de l'evolution du marche de la BRVM."
        : "Le BRVM30 est un indice compose de 30 valeurs selectionnees selon les criteres definis par la BRVM, notamment leur representativite et leur liquidite.";

    final takeaway = isComposite
        ? "A retenir : il permet de suivre la tendance generale du marche. Une hausse de l'indice ne signifie pas que toutes les actions montent."
        : "A retenir : il permet de suivre l'evolution d'un panier de valeurs representatives du marche. Il ne reflete pas necessairement la performance de toutes les societes cotees.";

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
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A).withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.info_outline, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Qu'est-ce que c'est ?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description, style: TextStyle(color: Colors.grey[700], height: 1.5, fontSize: 14)),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline, size: 20, color: Color(0xFF16A34A)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            takeaway,
                            style: TextStyle(color: Colors.grey[800], height: 1.45, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text("Comment lire la variation ?", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    "La variation affichee correspond a l'evolution de l'indice par rapport a sa cloture precedente. "
                    "Par exemple, +1,20 % signifie que l'indice a progresse de 1,20 % par rapport a la seance precedente.",
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
                          "Important : un indice mesure l'evolution d'un ensemble de valeurs. "
                          "Il ne constitue pas, a lui seul, une recommandation d'achat ou de vente.",
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

  Widget _indicesRow() {
    return FutureBuilder<List<BrvmQuote>>(
      future: _indicesFuture,
      builder: (context, snapshot) {
        final indices = snapshot.data;
        if (indices == null || indices.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: indices.map((q) {
              final change = q.change ?? 0;
              final isUp = change > 0;
              final isDown = change < 0;
              final changeColor = isUp
                  ? const Color(0xFF16A34A)
                  : isDown
                      ? const Color(0xFFDC2626)
                      : Colors.grey;
              final label = q.ticker == "BRVMC" ? "BRVM Composite" : q.ticker;

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
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
                            child: Text(
                              label,
                              style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          InkWell(
                            onTap: () => _showIndexInfo(q.ticker),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.info_outline, size: 16, color: Color(0xFF16A34A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(_formatIndex(q.close), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 2),
                      if (q.changePercent != null)
                        Row(
                          children: [
                            Icon(
                              isUp ? Icons.arrow_upward : (isDown ? Icons.arrow_downward : Icons.remove),
                              size: 12,
                              color: changeColor,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              "${q.changePercent! >= 0 ? '+' : ''}${q.changePercent!.toStringAsFixed(2)}%",
                              style: TextStyle(color: changeColor, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _indicesRow(),
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
