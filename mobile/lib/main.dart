import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'widgets/forecast_card.dart' show K;

void main() => runApp(const KounadiaApp());

class KounadiaApp extends StatelessWidget {
  const KounadiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOUNADIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: K.indigo,
          brightness: Brightness.dark,
          surface: K.card,
        ),
        scaffoldBackgroundColor: K.bg,
        appBarTheme: const AppBarTheme(
          backgroundColor: K.bg,
          foregroundColor: K.text,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: K.card,
          contentTextStyle: TextStyle(color: K.text),
          behavior: SnackBarBehavior.floating,
        ),
        bottomSheetTheme: const BottomSheetThemeData(backgroundColor: K.card),
      ),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.1)),
          child: child!,
        );
      },
      home: const MainScreen(),
    );
  }
}
