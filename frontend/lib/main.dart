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

  try {
    await initializeDateFormatting('id');
  } catch (e) {
    debugPrint("⚠️ Gagal inisialisasi format tanggal: $e");
  }

  try {
    await NotificationService().init();
    debugPrint("✅ NotificationService berhasil diinisialisasi (plugin setup).");
  } catch (e) {
    debugPrint("🔥 FATAL ERROR NotificationService: $e");
  }

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

// 🔧 PERBAIKAN 1: Diubah jadi ConsumerStatefulWidget agar Future tidak terpanggil berulang kali
class _AppRouter extends ConsumerStatefulWidget {
  const _AppRouter();

  @override
  ConsumerState<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends ConsumerState<_AppRouter> {
  late Future<_AppState> _appStateFuture;

  @override
  void initState() {
    super.initState();
    // Panggil fungsi cek state SEKALI SAJA saat aplikasi baru dibuka
    _appStateFuture = _checkAppState();
  }

  Future<_AppState> _checkAppState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    // 🔧 PERBAIKAN 2: Kita cek apakah ada Token tersimpan secara lokal.
    // Sesuaikan kata 'token' dengan key yang Mas gunakan saat menyimpan JWT waktu Login
    final String? token = prefs.getString('token');
    final bool hasTokenLokal = token != null && token.isNotEmpty;

    UserModel? user;
    if (hasTokenLokal) {
      try {
        user = await ApiService().restoreSession();
      } catch (e) {
        // Jika gagal karena internet putus saat HP baru bangun dari layar kunci,
        // KITA BIARKAN SAJA! Jangan buat aplikasi mengira user belum login.
        debugPrint('🔥 Gagal restoreSession (Mungkin internet putus saat Wake-up): $e');
        user = null;
      }
    }

    return _AppState(
        hasSeenOnboarding: hasSeenOnboarding,
        hasTokenLokal: hasTokenLokal, // <- Info penting yang akan kita pakai
        user: user
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AppState>(
      future: _appStateFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator(color: Color(0xFF006699))),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          debugPrint('🔥 FutureBuilder error: ${snapshot.error}');
          return const LoginScreen();
        }

        final appState = snapshot.data!;

        if (!appState.hasSeenOnboarding) {
          return const OnboardingScreen();
        }
        // 🔧 PERBAIKAN 3: Jika token LOKAL ada, PAKSA masuk ke HomeScreen!
        // Jangan pedulikan apakah API restoreSession tadi sukses atau kena TimeOut.
        else if (appState.hasTokenLokal) {
          if (appState.user != null) {
            Future.microtask(() {
              ref.read(userProvider.notifier).setUser(appState.user!);
            });
          }
          return const HomeScreen();
        }
        else {
          return const LoginScreen();
        }
      },
    );
  }
}

class _AppState {
  final bool hasSeenOnboarding;
  final bool hasTokenLokal; // Parameter tambahan penolong
  final UserModel? user;

  const _AppState({
    required this.hasSeenOnboarding,
    required this.hasTokenLokal,
    required this.user
  });
}