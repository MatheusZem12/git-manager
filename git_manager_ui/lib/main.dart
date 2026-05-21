import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const GitManagerApp());
}

class GitManagerApp extends StatelessWidget {
  const GitManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Git Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const DashboardScreen(),
    );
  }
}
