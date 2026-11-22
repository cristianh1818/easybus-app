import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/splash_screen.dart';
import 'screens/home_shell.dart';
import 'theme/eb_theme.dart';

class EasyBusApp extends StatelessWidget {
  const EasyBusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EASYBUS',
      debugShowCheckedModeBanner: false,
      theme: EbTheme.light(),
      // La app está solo en español (Colombia)
      locale: const Locale('es', 'CO'),
      supportedLocales: const [Locale('es', 'CO'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: SplashScreen(next: (_) => const HomeShell()),
    );
  }
}
