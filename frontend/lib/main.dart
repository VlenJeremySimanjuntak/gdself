import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:gdself/features/onboarding/ui/onboarding.dart';
import 'package:gdself/features/login/ui/login_screen.dart';
import 'package:gdself/features/login/ui/register_screen.dart';
import 'package:gdself/features/home/ui/home_screen.dart';
import 'package:gdself/services/notification_service.dart';
import 'package:gdself/services/api_service.dart';
import 'package:gdself/models/user_model.dart';
import 'package:gdself/features/home/providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');
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
      navigatorKey: navigatorKey,
      home: const _AppRouter(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login':      (context) => const LoginScreen(),
        '/register':   (context) => const RegisterScreen(),
        '/home':       (context) => const HomeScreen(),
      },
    );
  }
}

class _AppRouter extends ConsumerWidget {
  const _AppRouter();

  Future<_AppState> _checkAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final user = await ApiService().restoreSession();
    return _AppState(hasSeenOnboarding: hasSeenOnboarding, user: user);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<_AppState>(
      future: _checkAppState(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final appState = snapshot.data!;

        if (!appState.hasSeenOnboarding) {
          return const OnboardingScreen();
        } else if (appState.user != null) {
          Future.microtask(() {
            ref.read(userProvider.notifier).setUser(appState.user!);
          });
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

class _AppState {
  final bool hasSeenOnboarding;
  final UserModel? user;
  const _AppState({required this.hasSeenOnboarding, required this.user});
}