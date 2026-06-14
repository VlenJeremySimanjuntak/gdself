import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gdself/features/onboarding/ui/onboarding.dart';
import 'package:gdself/features/login/ui/login_screen.dart';
import 'package:gdself/features/login/ui/register_screen.dart';
import 'package:gdself/features/home/ui/home_screen.dart';
import 'package:gdself/services/notification_service.dart';

// ========================================================
// 👇 1. BUAT KUNCI NAVIGASI GLOBAL DI SINI 👇
// ========================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');

  // Nyalakan mesin alarm
  await NotificationService().init();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Graves Disease App',
      // ========================================================
      // 👇 2. PASANG KUNCINYA KE DALAM MATERIAL APP 👇
      // ========================================================
      navigatorKey: navigatorKey,
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}