import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const GitManagerApp());
}

class GitManagerApp extends StatefulWidget {
  const GitManagerApp({super.key});

  @override
  State<GitManagerApp> createState() => GitManagerAppState();

  static GitManagerAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<GitManagerAppState>();
}

class GitManagerAppState extends State<GitManagerApp> {
  Locale _locale = const Locale('pt');

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Git Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt'), Locale('en'), Locale('es')],
      locale: _locale,
      home: DashboardScreen(
        locale: _locale,
        onLocaleChange: setLocale,
      ),
    );
  }
}
