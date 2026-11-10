import 'package:flutter/material.dart';
import 'core/theme/nexus_guard_theme.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  runApp(const KomplekGuardApp());
}

class KomplekGuardApp extends StatelessWidget {
  const KomplekGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KomplekGuard AI',
      debugShowCheckedModeBanner: false,
      theme: NexusGuard.theme,
      home: const SplashScreen(),
    );
  }
}
