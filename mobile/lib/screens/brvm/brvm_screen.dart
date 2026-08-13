import "package:flutter/material.dart";
import "../../models/brvm.dart";
import "../../services/api_service.dart";
import "brvm_detail_screen.dart";

class BrvmScreen extends StatefulWidget {
  const BrvmScreen({super.key});

  @override
  State<BrvmScreen> createState() => _BrvmScreenState();
}

class _BrvmScreenState extends State<BrvmScreen> {
  final ApiService _apiService = ApiService();
  Future<List<BrvmQuote>>? _quotesFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _quotesFuture = _apiService.getBrvmQuotes();
    });
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _load(),
      child: FutureBuilder<List<BrvmQuote>>(
        future: _quotesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Impossible de charger les cotations BRVM."),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text("Réessayer")),
                  ],
                ),
              ),
            );
          }

          final quotes = snapshot.data ?? [];
          if (quotes.isEmpty) {
            return ListView(
              children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text("Aucune cotation disponible pour le moment.")),
                ),
              ],
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: quotes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final q = quotes[index];
              final isUp = (q.change ?? 0) >= 0;
              final changeColor = isUp ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BrvmDetailScreen(ticker: q.ticker)),
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
                          Text(q.ticker, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(height: 4),
                          Text(
                            _formatFcfa(q.close),
                            style: TextStyle(color: Colors.grey[700], fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (q.changePercent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: changeColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(isUp ? Icons.arrow_upward : Icons.arrow_downward, size: 14, color: changeColor),
                            const SizedBox(width: 4),
                            Text(
                              "${q.changePercent!.abs().toStringAsFixed(2)}%",
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
    );
  }
}
