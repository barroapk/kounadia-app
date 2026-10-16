import 'package:flutter/material.dart';
import '../widgets/forecast_card.dart' show K;
import 'knd/deposit_screen.dart';
import 'knd/withdrawal_screen.dart';
import 'predictions_screen.dart';
import 'scores_screen.dart';
import 'settings_screen.dart';
import 'tip_history_screen.dart';
import '../widgets/welcome_card.dart';

final k1xBet = Color(0xFF1A5BA6);

class MainScreen extends StatefulWidget {
  MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowWelcome(context);
    });
  }
  static List<Widget> _screens = [ScoresScreen(), PredictionsScreen(), TipHistoryScreen()];
  static final _titles = ['Matchs', 'Prédictions', 'Historique'];

  void _push(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  Widget _action(BuildContext ctx, IconData icon, Color c, String t, String s, Widget page) {
    return Material(
      color: K.bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.pop(ctx);
          _push(page);
        },
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: c.withAlpha(40), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: c),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: TextStyle(color: K.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text(s, style: TextStyle(color: K.muted, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: K.muted),
          ]),
        ),
      ),
    );
  }

  void _openKnd() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: K.card,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1xBet · KOUNADIA SERVICE',
                  style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              Text('Traitement rapide par un agent sur WhatsApp',
                  style: TextStyle(color: K.muted, fontSize: 13)),
              SizedBox(height: 14),
              _action(ctx, Icons.south_west_rounded, K.green, 'Dépôt 1xBet', 'Recharger mon compte 1xBet',
                  DepositScreen()),
              SizedBox(height: 10),
              _action(ctx, Icons.north_east_rounded, K.amber, 'Retrait 1xBet', 'Retirer de mon compte 1xBet',
                  WithdrawalScreen()),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      appBar: AppBar(
        backgroundColor: K.bg,
        titleSpacing: 16,
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 19),
          ),
          SizedBox(width: 10),
          Text('KOUNADIA',
              style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1)),
          SizedBox(width: 8),
          Flexible(
            child: Text('· ${_titles[_i]}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: K.muted, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: 'Paramètres',
            icon: Icon(Icons.settings_rounded, color: K.muted),
            onPressed: () => _push(SettingsScreen()),
          ),
          SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(height: 1, color: K.border),
        ),
      ),
      body: IndexedStack(index: _i, children: _screens),
      floatingActionButton: Material(
        color: k1xBet,
        shape: StadiumBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: StadiumBorder(),
          onTap: _openKnd,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 9, 10, 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.swap_vert_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Dépôt · Retrait',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              SizedBox(width: 7),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: Text('1xBet',
                    style: TextStyle(color: k1xBet, fontSize: 11.5, fontWeight: FontWeight.w900)),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: K.border))),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: K.card,
            indicatorColor: K.indigoSoft,
            height: 64,
            labelTextStyle: WidgetStateProperty.resolveWith((s) {
              final on = s.contains(WidgetState.selected);
              return TextStyle(
                  fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w600, color: on ? K.text : K.muted);
            }),
            iconTheme: WidgetStateProperty.resolveWith(
                (s) => IconThemeData(color: s.contains(WidgetState.selected) ? K.indigoText : K.muted, size: 24)),
          ),
          child: NavigationBar(
            selectedIndex: _i,
            onDestinationSelected: (i) => setState(() => _i = i),
            destinations: [
              NavigationDestination(
                  icon: Icon(Icons.sports_soccer_outlined), selectedIcon: Icon(Icons.sports_soccer), label: 'Matchs'),
              NavigationDestination(
                  icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Prédictions'),
              NavigationDestination(
                  icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history), label: 'Historique'),
            ],
          ),
        ),
      ),
    );
  }
}
