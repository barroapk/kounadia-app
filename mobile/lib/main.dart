import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/main_screen.dart';
import 'services/theme_controller.dart';
import 'services/analytics.dart';
import 'services/account.dart';
import 'services/user_prefs.dart';
import 'services/currency.dart';
import 'services/sync.dart';
import 'widgets/forecast_card.dart' show K;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeCtl.init();
  await UserPrefs.init();
  Fx.init();
  Analytics.init();
  Account.init();
  Sync.start();
  K.dark = ThemeCtl.isDark;
  runApp(KounadiaApp());
}

class KounadiaApp extends StatefulWidget {
  KounadiaApp({super.key});

  @override
  State<KounadiaApp> createState() => _KounadiaAppState();
}

class _KounadiaAppState extends State<KounadiaApp> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ThemeCtl.mode.addListener(_check);
    _timer = Timer.periodic(Duration(minutes: 1), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    ThemeCtl.mode.removeListener(_check);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
    if (state == AppLifecycleState.paused) {
      Analytics.flush();
      Sync.push();
    }
  }

  void _check() {
    final d = ThemeCtl.isDark;
    if (d == K.dark) return;
    K.dark = d;
    setState(() {});
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }
    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    final dark = K.dark;
    return MaterialApp(
      title: 'KOUNADIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: K.indigo,
          brightness: dark ? Brightness.dark : Brightness.light,
          surface: K.card,
        ),
        scaffoldBackgroundColor: K.bg,
        appBarTheme: AppBarTheme(
          backgroundColor: K.bg,
          foregroundColor: K.text,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: dark ? K.card : Color(0xFF1F2937),
          contentTextStyle: TextStyle(color: dark ? K.text : Colors.white),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: BottomSheetThemeData(backgroundColor: K.card),
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.1)),
          child: child!,
        );
      },
      home: MainScreen(),
    );
  }
}
