import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/knd_banner.dart' show BannerService;
import '../widgets/forecast_card.dart' show K;
import '../services/analytics.dart';
import '../services/user_prefs.dart';
import 'knd/deposit_screen.dart';
import 'knd/withdrawal_screen.dart';
import 'predictions_screen.dart';
import 'scores_screen.dart';
import 'settings_screen.dart';
import 'tip_history_screen.dart';
import 'coupon_tab.dart';
import '../widgets/premium_gate.dart';
import '../widgets/welcome_card.dart';
import '../widgets/setup_card.dart';
import 'account_screen.dart';
import '../l10n/tr.dart';
import '../services/app_update.dart';
import '../services/notif.dart';
import '../services/live_socket.dart';
import '../config/store.dart';
import 'alerts_screen.dart';
import 'v2/coupon_day_screen.dart';
import 'v2/selection_screen.dart';

final k1xBet = Color(0xFF1A5BA6);

class MainScreen extends StatefulWidget {
  MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _i = 0;

  String _adLang = UserPrefs.lang;

  void _prefsChanged() {
    if (_adLang != UserPrefs.lang) {
      _adLang = UserPrefs.lang;
      BannerService.reload(); // pubs dans la nouvelle langue tout de suite
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    UserPrefs.changed.removeListener(_prefsChanged);
    WidgetsBinding.instance.removeObserver(this);
    _adTimer?.cancel();
    super.dispose();
  }

  bool _ready = false;
  Timer? _adTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      LiveSocket.start();
    _adTimer = Timer.periodic(Duration(minutes: 3), (_) => BannerService.reload());
      BannerService.reload();
    }
    if (s == AppLifecycleState.paused) LiveSocket.stop();
    if (s == AppLifecycleState.resumed && _ready && mounted) AppUpdate.checkOnStart(context);
  }

  @override
  void initState() {
    super.initState();
    UserPrefs.changed.addListener(_prefsChanged);
    WidgetsBinding.instance.addObserver(this);
    LiveSocket.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _start();
    });
  }

  Future<void> _start() async {
    final auth = await maybeShowSetup(context);
    if (!mounted) return;
    await maybeShowWelcome(context);
    Notif.start();
    if (auth != null && mounted) {
      _ready = true;
      Navigator.push(context, MaterialPageRoute(builder: (_) => AccountScreen(signup: auth)));
      return;
    }
    await Future<void>.delayed(Duration(seconds: 3));
    _ready = true;
    if (mounted) await AppUpdate.checkOnStart(context);
  }
  static final List<Widget> _screensV1 = [
    ScoresScreen(),
    PremiumGate(
                    title: "Prédictions KOUNADIA",
                    pitch: "Chaque jour, nos pronostics analysés : Kounadia IA, avis Expert et la sélection Coup sûr, avec les résultats en direct.",
                    perks: ["Kounadia IA : score prédit et tendance de chaque match","Expert : les pronostics de nos analystes","Coup sûr : les sélections les plus fiables du jour","Scores et minutes en direct sur chaque carte"],
                    icon: Icons.insights_rounded,
                    child: PredictionsScreen()),
    PremiumGate(
                    title: "Créer un coupon",
                    pitch: "Choisis ta cote et ton nombre de matchs : KOUNADIA compose ton coupon à partir de ses analyses.",
                    perks: ["Coupon composé selon ta cote cible","Sélection fondée sur nos analyses et les statistiques","Partage du coupon en image en un clic","Suivi automatique : gagné ou perdu"],
                    icon: Icons.confirmation_number_rounded,
                    child: CouponTab()),
    TipHistoryScreen(),
  ];
  // KOUNADIA V2 : Matchs · Coupon du jour · Sélection du jour · Créer coupon (les historiques sont dans chaque rubrique).
  static final List<Widget> _screensV2 = [
    ScoresScreen(),
    CouponDayScreen(),
    PremiumGate(
        title: "Coups sûrs",
        pitch: "Les paris du jour les plus sûrs : KOUNADIA, PrimaTips et nos analystes Expert doivent être d'accord.",
        perks: [
          "Coups sûrs : un pari par match, de types variés",
          "Double chance, buts, mi-temps, corners, fautes, tirs…",
          "Pourquoi ce choix, en bref, pour chaque pari",
          "Coupons cote 2+, 5+ et 10+",
          "Historique de la semaine : gagnés et perdus",
        ],
        icon: Icons.checklist_rounded,
        child: SelectionScreen()),
    PremiumGate(
        title: "Créer un coupon",
        pitch: "Choisis ta cote et ton nombre de matchs : KOUNADIA compose ton coupon à partir de ses analyses.",
        perks: ["Coupon composé selon ta cote cible","Sélection fondée sur nos analyses et les statistiques","Partage du coupon en image en un clic","Suivi automatique : gagné ou perdu"],
        icon: Icons.confirmation_number_rounded,
        child: CouponTab()),
  ];
  static List<Widget> get _screens => kV2 ? _screensV2 : _screensV1;
  static final _titles = kV2
      ? ['Matchs', 'Coupon du jour', 'Coups sûrs', 'Créer coupon']
      : ['Matchs', 'Prédictions', 'Créer coupon', 'Historique'];

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
                T(t, style: TextStyle(color: K.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                T(s, style: TextStyle(color: K.muted, fontSize: 12.5)),
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
              T('1xBet · KOUNADIA SERVICE',
                  style: TextStyle(color: K.text, fontSize: 17, fontWeight: FontWeight.w800)),
              SizedBox(height: 4),
              T('Traitement rapide par un agent sur WhatsApp',
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
          T('KOUNADIA',
              style: TextStyle(color: K.text, fontSize: 19, fontWeight: FontWeight.w900, letterSpacing: 1)),
          SizedBox(width: 8),
          Flexible(
            child: T('· ${tr(_titles[_i])}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: K.muted, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ]),
        actions: [
          IconButton(
            tooltip: tr('Alertes'),
            icon: Icon(Icons.notifications_rounded, color: K.muted),
            onPressed: () => _push(AlertsScreen()),
          ),
          IconButton(
            tooltip: tr('Paramètres'),
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
      body: Column(children: [UpdateBanner(), Expanded(child: IndexedStack(index: _i, children: _screens))]),
      // Dépôt / Retrait : service disponible uniquement au Burkina Faso.
      floatingActionButton: kPlay || UserPrefs.iso != 'BF' ? null : Material(
        color: k1xBet,
        shape: StadiumBorder(),
        elevation: 6,
        child: InkWell(
          customBorder: StadiumBorder(),
          onTap: () {
            Analytics.log('knd_menu');
            _openKnd();
          },
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 9, 10, 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.swap_vert_rounded, color: Colors.white, size: 18),
              SizedBox(width: 6),
              T('Dépôt · Retrait',
                  style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              SizedBox(width: 7),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                child: T('1xBet',
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
            onDestinationSelected: (i) {
              setState(() => _i = i);
              Analytics.log('tab_view', {'tab': _titles[i]});
            },
            destinations: kV2
                ? [
                    NavigationDestination(
                        icon: Icon(Icons.sports_soccer_outlined), selectedIcon: Icon(Icons.sports_soccer), label: tr('Matchs')),
                    NavigationDestination(
                        icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: tr('Coupon du jour')),
                    NavigationDestination(
                        icon: Icon(Icons.checklist_outlined), selectedIcon: Icon(Icons.checklist), label: tr('Coups sûrs')),
                    NavigationDestination(
                        icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: tr('Créer coupon')),
                  ]
                : [
              NavigationDestination(
                  icon: Icon(Icons.sports_soccer_outlined), selectedIcon: Icon(Icons.sports_soccer), label: tr('Matchs')),
              NavigationDestination(
                  icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: tr('Prédictions')),
              NavigationDestination(
                  icon: Icon(Icons.confirmation_number_outlined), selectedIcon: Icon(Icons.confirmation_number), label: tr('Coupon')),
              NavigationDestination(
                  icon: Icon(Icons.history_rounded), selectedIcon: Icon(Icons.history), label: tr('Historique')),
            ],
          ),
        ),
      ),
    );
  }
}
