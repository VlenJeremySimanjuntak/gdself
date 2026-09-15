import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gdself/features/home/ui/tambah_obat_screen.dart';
import 'package:gdself/features/home/ui/wearable_summary_screen.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../../../models/hasil_ai_harian_model.dart';
import '../../../models/lab_data_model.dart';
import '../../../models/obat_model.dart';
import '../../../models/wearable_model.dart';
import '../../monitoring/ui/widgets/ai_kepatuhan_dialog.dart';
import '../../riwayat/ui/riwayat_screen.dart';
import '../../education/ui/education_screen.dart';
import '../../home/providers/home_provider.dart';
import '../../home/providers/user_provider.dart';
import '../../monitoring/ui/monitoring_screen.dart';
import '../../../utils/design_system.dart';
import '../../profil/ui/profile_screen.dart';
import '../providers/wearable_provider.dart';
import 'detail_obat_screen.dart';
import 'jadwal_obat_screen.dart';
import 'edit_obat_screen.dart';
import 'wearable_sync_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../services/notification_service.dart';
import '../providers/obat_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isDisconnected = true;
  bool _isSyncing = false;
  bool _sudahCekAI = false;
  final _healthChannel = const MethodChannel('com.example.gdself/health_connect');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 100));

      final userId = ref.read(userProvider).user?.idUser;
      if (userId != null && mounted) {
        ref.read(homeProvider.notifier).fetchAll(userId);

        if (!_sudahCekAI) {
          await _jalankanPengecekanAI(userId);
        }
      }

      await _cekStatusKoneksi();
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await NotificationService().requestPermissions();
      } catch (e) {
        debugPrint('⚠️ Permission notifikasi gagal: $e');
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      _cekStatusKoneksi();
    }
  }

  Future<void> _jalankanPengecekanAI(int userId) async {
    _sudahCekAI = true;

    try {
      final dynamic response = await ref.read(obatProvider.notifier).cekNotifikasiKepatuhanUser(userId);

      if (!mounted) return;

      if (response is Map<String, dynamic>) {
        final perluPerhatian = response['perlu_perhatian'] ?? false;
        final List<dynamic> dataObat = response['obat'] ?? [];

        if (perluPerhatian == true && dataObat.isNotEmpty) {
          _showAIKepatuhanDialog(dataObat);
        }
      }
      else if (response is List) {
        if (response.isNotEmpty) {
          _showAIKepatuhanDialog(response);
        }
      }
    } catch (e) {
      debugPrint('Gagal cek kepatuhan AI: $e');
    }
  }

  void _showAIKepatuhanDialog(List<dynamic> dataObat) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: PeringatanKepatuhanDialog(dataObat: dataObat.cast<Map<String, dynamic>>()),
        );
      },
    );
  }

  Future<void> _cekStatusKoneksi() async {
    try {
      final Health health = Health();
      final prefs = await SharedPreferences.getInstance();

      bool skipSdkCheck = false;
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        if (androidInfo.version.sdkInt >= 34) {
          skipSdkCheck = true;
          debugPrint("🤖 Android 14+ terdeteksi (SDK ${androidInfo.version.sdkInt}). Melewati pengecekan SDK.");
        }
      }

      if (!skipSdkCheck) {
        HealthConnectSdkStatus? sdkStatus;
        try {
          sdkStatus = await health.getHealthConnectSdkStatus();
        } catch (e) {
          if (!mounted) return;
          setState(() => _isDisconnected = true);
          return;
        }

        if (sdkStatus == null || sdkStatus != HealthConnectSdkStatus.sdkAvailable) {
          if (!mounted) return;
          setState(() => _isDisconnected = true);
          await prefs.setBool('is_wearable_disconnected', true);
          return;
        }
      }

      final types = [
        HealthDataType.HEART_RATE,
        HealthDataType.SLEEP_SESSION,
        HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
        HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
      ];
      final permissions = [
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
        HealthDataAccess.READ,
      ];

      bool hasPermissions = false;
      try {
        hasPermissions = await health.hasPermissions(types, permissions: permissions) ?? false;
      } catch (e) {
        hasPermissions = false;
      }

      await prefs.setBool('is_wearable_disconnected', !hasPermissions);

      if (!mounted) return;
      setState(() {
        _isDisconnected = !hasPermissions;
      });

      if (hasPermissions && !_isSyncing) {
        _isSyncing = true;
        try {
          final userId = ref.read(userProvider).user?.idUser;
          if (userId != null) {
            bool syncStatus = await ref.read(wearableProvider.notifier).syncRealWearableData(userId);
            if (mounted && syncStatus) {
              await ref.read(homeProvider.notifier).fetchAll(userId);
            }
          }
        } finally {
          _isSyncing = false;
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDisconnected = true);
    }
  }

  Future<void> _setDisconnectState(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_wearable_disconnected', value);
    if (!mounted) return;
    setState(() {
      _isDisconnected = value;
    });
  }

  Future<void> _refresh() async {
    await _cekStatusKoneksi();
    if (!mounted) return;

    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      await ref.read(homeProvider.notifier).fetchAll(userId);
    }
  }

  void _showLepasAksesDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Lepaskan Akses', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text(
            'Anda akan diarahkan ke halaman izin Health Connect. Silakan nonaktifkan izin untuk GdSelf di sana.',
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD9534F),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _bukaHealthConnectSettings();
              },
              child: const Text('Buka Pengaturan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _bukaHealthConnectSettings() async {
    try {
      await _healthChannel.invokeMethod('openHealthConnectSettings');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka Health Connect. Buka manual dari Pengaturan > Aplikasi > Health Connect.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // =========================================================
  // FUNGSI HELPER UNTUK MENDAPATKAN STATUS TIAP PARAMETER LAB
  // =========================================================
  String _getMetricStatus(String paramName, double value) {
    if (value == 0.0) return '-';
    if (paramName.toUpperCase().contains('TSH')) {
      return value < 0.35 ? 'Rendah' : (value > 4.94 ? 'Tinggi' : 'Normal');
    } else if (paramName.toUpperCase().contains('FT4')) {
      return value < 0.70 ? 'Rendah' : (value > 1.48 ? 'Tinggi' : 'Normal');
    } else if (paramName.toUpperCase().contains('FT3')) {
      return value < 1.71 ? 'Rendah' : (value > 3.71 ? 'Tinggi' : 'Normal');
    }
    return 'Normal';
  }

  // =========================================================
  // REDESAIN HCAI EXPLAINABILITY MODAL (PREMIUM & MODERN UX)
  // =========================================================
  void _showHCAIExplainabilitySheet(BuildContext context, String statusDisplay, LaporanLabModel? laporan) {
    String statusTSH = '-';
    String statusFT4 = '-';
    String statusFT3 = '-';
    double valTSH = 0.0;
    double valFT4 = 0.0;
    double valFT3 = 0.0;
    String stringTanggal = 'Belum ada riwayat';

    if (laporan != null && laporan.tglPeriksa != null) {
      stringTanggal = DateFormat('dd MMMM yyyy', 'id_ID').format(laporan.tglPeriksa!);
    }

    if (laporan != null && laporan.hasilLab.isNotEmpty) {
      for (var hasil in laporan.hasilLab) {
        if (hasil.parameters.isNotEmpty) {
          final param = hasil.parameters.first;
          final val = param.nilaiHasil;
          if (param.namaParameter.toUpperCase().contains('TSH')) {
            statusTSH = _getMetricStatus('TSH', val);
            valTSH = val;
          }
          if (param.namaParameter.toUpperCase().contains('FT4')) {
            statusFT4 = _getMetricStatus('FT4', val);
            valFT4 = val;
          }
          if (param.namaParameter.toUpperCase().contains('FT3')) {
            statusFT3 = _getMetricStatus('FT3', val);
            valFT3 = val;
          }
        }
      }
    }

    // =========================================================
    // ATURAN PENENTUAN KONDISI LAB (ETA 2018) — RULE-BASED AI
    // Fact Base -> Inference Engine -> Explanation Facility
    // =========================================================
    String statusLabHasil;
    String alasanPenetapan;

    if (statusTSH == 'Normal' && statusFT3 == 'Normal' && statusFT4 == 'Normal') {
      statusLabHasil = 'Normal';
      alasanPenetapan = "Berdasarkan interpretasi yang mengacu pada pedoman klinis European Thyroid Association (ETA, 2018), evaluasi kombinasi status TSHs normal, FT3 normal, dan FT4 normal menghasilkan kategori hasil pemeriksaan normal.";
    } else if (statusTSH == 'Rendah' && statusFT3 == 'Tinggi' && statusFT4 == 'Tinggi') {
      statusLabHasil = 'Belum Normal';
      alasanPenetapan = "Berdasarkan interpretasi yang mengacu pada pedoman klinis European Thyroid Association (ETA, 2018), evaluasi kombinasi status TSHs rendah, FT3 tinggi, dan FT4 tinggi menghasilkan kategori hasil pemeriksaan belum normal.";
    } else if (statusTSH == 'Rendah' && statusFT3 == 'Tinggi' && statusFT4 == 'Normal') {
      statusLabHasil = 'Belum Normal';
      alasanPenetapan = "Berdasarkan interpretasi yang mengacu pada pedoman klinis European Thyroid Association (ETA, 2018), evaluasi kombinasi status TSHs rendah, FT3 tinggi, dan FT4 normal menghasilkan kategori hasil pemeriksaan belum normal.";
    } else if (statusTSH == 'Rendah' && statusFT3 == 'Normal' && statusFT4 == 'Tinggi') {
      statusLabHasil = 'Belum Normal';
      alasanPenetapan = "Berdasarkan interpretasi yang mengacu pada pedoman klinis European Thyroid Association (ETA, 2018), evaluasi kombinasi status TSHs rendah, FT3 normal, dan FT4 tinggi menghasilkan kategori hasil pemeriksaan belum normal.";
    } else if (statusTSH == 'Rendah' && statusFT3 == 'Normal' && statusFT4 == 'Normal') {
      statusLabHasil = 'Belum Normal';
      alasanPenetapan = "Berdasarkan interpretasi yang mengacu pada pedoman klinis European Thyroid Association (ETA, 2018), evaluasi kombinasi status TSHs rendah, FT3 normal, dan FT4 normal menghasilkan kategori hasil pemeriksaan belum normal.";
    } else {
      statusLabHasil = 'Pola Belum Teridentifikasi';
      alasanPenetapan = "Berdasarkan interpretasi yang mengacu pada pedoman klinis European Thyroid Association (ETA, 2018), evaluasi kombinasi status TSHs, FT3, dan FT4 saat ini belum sesuai dengan pola-pola yang ditetapkan, sehingga hasil pemeriksaan belum dapat dikategorikan sebagai normal maupun belum normal.";
    }

    String statusUpper = statusLabHasil.toUpperCase();
    bool isNormalCase = statusUpper == 'NORMAL';

    String fmtVal(double v, int decimal) => v == 0.0 ? '-' : v.toStringAsFixed(decimal);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Section 1: KESIMPULAN BANNER HERO (Hasil Evaluasi)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isNormalCase ? Colors.white : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: isNormalCase
                          ? [BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))]
                          : [],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Status Hormon",
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isNormalCase ? const Color(0xFF1E293B) : const Color(0xFFB91C1C),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Data terakhir:\n$stringTanggal',
                              style: TextStyle(
                                color: isNormalCase
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF7F1D1D).withOpacity(0.8),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                        Flexible(
                          child: Text(
                            statusUpper,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: isNormalCase ? const Color(0xFF1B9E5A) : const Color(0xFFDC2626),
                              fontSize: 18,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Section 2: RINCIAN PARAMETER — Nilai Masukan & Nilai Acuan (Explanation Facility)
                  const Text("Rincian Parameter", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildExplainabilityRow("TSH", statusTSH, fmtVal(valTSH, 3), "0.35 - 4.94 mIU/L"),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                        _buildExplainabilityRow("FT4", statusFT4, fmtVal(valFT4, 2), "0.70 - 1.48 pmol/L"),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
                        _buildExplainabilityRow("FT3", statusFT3, fmtVal(valFT3, 2), "1.71 - 3.71 pmol/L"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(PhosphorIcons.bookOpenText(PhosphorIconsStyle.fill), color: const Color(0xFF0074A3), size: 20),
                            const SizedBox(width: 8),
                            const Text("Analisis Data Laboratorium", style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0074A3), fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          alasanPenetapan,
                          style: const TextStyle(color: Color(0xFF334155), fontSize: 13, height: 1.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // UI HELPER: RINCIAN BARIS DENGAN PILL BADGE MODERN
  // =========================================================
  Widget _buildExplainabilityRow(String param, String status, String nilaiMasukan, String nilaiAcuan) {
    bool isNormal = status == 'Normal';
    bool isNoData = status == '-';

    Color statusColor = isNormal ? const Color(0xFF059669) : (isNoData ? const Color(0xFF64748B) : const Color(0xFFD97706));
    Color bgColor = isNormal ? const Color(0xFFD1FAE5) : (isNoData ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(param, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155), fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  'Hasil: $nilaiMasukan  •  Rujukan: $nilaiAcuan',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: TextStyle(fontWeight: FontWeight.w700, color: statusColor, fontSize: 12)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeState = ref.watch(homeProvider);
    final user = ref.watch(userProvider).user;

    final List<Widget> screens = [
      _buildHomeView(context, homeState, user),
      const MonitoringScreen(),
      const RiwayatScreen(),
      const EducationScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FF),
      body: screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeView(BuildContext context, HomeState state, dynamic user) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.errorMessage != null
          ? Center(child: Text('Error: ${state.errorMessage}'))
          : _buildContent(context, state, user),
    );
  }

  Widget _buildContent(BuildContext context, HomeState state, dynamic user) {
    final laporan = state.laporanTerbaru;
    final wearable = state.wearableTerbaru;
    final String namaUser = user?.nama ?? '-';
    final int userId = user?.idUser ?? user?.id ?? 0;

    final now = DateTime.now();
    final formattedDay = DateFormat('EEEE', 'id_ID').format(now);
    final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);

    final semuaJadwalObat = state.jadwalObat;

    final Map<String, String> dayToDbFormat = {
      'senin': 'sen', 'selasa': 'sel', 'rabu': 'rab',
      'kamis': 'kam', 'jumat': 'jum', 'sabtu': 'sab', 'minggu': 'min',
    };
    final hariIniDbStr = dayToDbFormat[formattedDay.toLowerCase()] ?? '';
    final todayOnlyDate = DateTime(now.year, now.month, now.day);

    final jadwalObatHariIni = semuaJadwalObat.where((jadwal) {
      final hariKonsumsi = jadwal.hari?.toLowerCase() ?? '';
      bool isHariSesuai = hariKonsumsi.contains(hariIniDbStr) ||
          hariKonsumsi.contains(formattedDay.toLowerCase());

      if (!isHariSesuai) return false;

      final obat = jadwal.obat;
      if (obat.tglMulai != null) {
        final startDate = DateTime(obat.tglMulai!.year, obat.tglMulai!.month, obat.tglMulai!.day);
        if (todayOnlyDate.isBefore(startDate)) return false;
      }
      if (obat.tglSelesai != null) {
        final endDate = DateTime(obat.tglSelesai!.year, obat.tglSelesai!.month, obat.tglSelesai!.day);
        if (todayOnlyDate.isAfter(endDate)) return false;
      }
      return true;
    }).toList();

    final Map<String, List<JadwalObatModel>> groupedJadwalMap = {};
    for (var jadwal in jadwalObatHariIni) {
      final namaObat = jadwal.obat.namaObat;
      if (!groupedJadwalMap.containsKey(namaObat)) {
        groupedJadwalMap[namaObat] = [];
      }
      groupedJadwalMap[namaObat]!.add(jadwal);
    }

    void onAturJadwalObat() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JadwalObatScreen()),
      ).then((_) => _refresh());
    }

    Future<void> onHubungkanPerangkat() async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WearableSyncScreen()),
      );

      if (!mounted) return;

      if (result == true) {
        await _setDisconnectState(false);
        final userId = ref.read(userProvider).user?.idUser;
        if (userId != null) {
          await ref.read(homeProvider.notifier).fetchAll(userId);
        }
      }
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FAFF), Color(0xFFF4F8FF), Color(0xFFF8FBFF)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: -90,
              top: 250,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8AD7FF).withOpacity(0.24),
                      const Color(0xFF8AD7FF).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -120,
              top: 60,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFB5F0DA).withOpacity(0.34),
                      const Color(0xFFB5F0DA).withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 120),
              clipBehavior: Clip.none,
              children: [
                _buildTopHeader(ref),
                const SizedBox(height: 34),
                Text(
                  '${formattedDay.toUpperCase()}, $formattedDate | $formattedTime',
                  style: const TextStyle(
                    color: Color(0xFF0B70C9),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Halo, $namaUser',
                  style: const TextStyle(
                    fontSize: 34,
                    height: 1.05,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF263238),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Bagaimana perasaan Anda hari ini? Mari kita lihat perkembangan kesehatan Anda.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280), height: 1.5),
                ),
                const SizedBox(height: 28),

                _buildStatusHormonCard(laporan),

                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Jadwal Obat',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (jadwalObatHariIni.isEmpty ||
                    jadwalObatHariIni.every((jadwal) =>
                    jadwal.obat.namaObat.trim().isEmpty ||
                        jadwal.obat.namaObat == '-'))

                  _emptyMedicationCard(
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TambahObatScreen()),
                      ).then((_) => _refresh());
                    },
                        () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const JadwalObatScreen()),
                      ).then((_) => _refresh());
                    },
                  )

                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ...groupedJadwalMap.values.map((listJadwalGroup) {
                        return _buildMedicationCard(listJadwalGroup);
                      }),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: onAturJadwalObat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF006699),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Atur Jadwal Obat',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 34),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Aktivitas',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFF263238)),
                    ),
                    if (!_isDisconnected)
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: Colors.white,
                        onSelected: (value) {
                          if (value == 'lepaskan') {
                            _showLepasAksesDialog(context);
                          }
                        },
                        itemBuilder: (BuildContext context) => [
                          const PopupMenuItem<String>(
                            value: 'lepaskan',
                            child: Text(
                              'Lepaskan Akses',
                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                if (_isDisconnected)
                  _emptyWearableCard(onHubungkanPerangkat)
                else
                  _buildWearablesSection(
                    wearable ?? WearableModel(
                      idWearable: 0,
                      idRiwayat: null,
                      idUser: userId,
                      tglData: null,
                      waktuData: null,
                      heartRateRHR: 0,
                      sleepDuration: 0,
                      sistolik: 0,
                      diastolik: 0,
                      hasilAI: const [],
                    ),
                    userId,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(WidgetRef ref) {
    final authState = ref.watch(userProvider);
    final user = authState.user;

    final String nama = user?.nama ?? '';
    final String initial = nama.isNotEmpty ? nama[0].toUpperCase() : '?';
    final String? avatarUrl = authState.avatarUrl;
    final bool hasFoto = (user?.fotoProfil ?? '').isNotEmpty && avatarUrl != null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Image.asset('assets/images/graves-logo.png', width: 28, height: 28),
            const SizedBox(width: 10),
            const Text(
              "Graves disease",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
                fontSize: 18,
              ),
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = 4; // Pindah ke tab Profil
            });
          },
          child: CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE3ECF7),
            backgroundImage: hasFoto
                ? CachedNetworkImageProvider(
              avatarUrl,
              headers: authState.authHeaders,
              cacheKey: authState.avatarCacheKey,
            )
                : null,
            onBackgroundImageError:
            hasFoto ? (exception, stackTrace) {} : null,
            child: !hasFoto
                ? Text(
              initial,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            )
                : null,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // HERO CARD HORMON (SUDAH DIKEMBALIKAN SESUAI GAMBAR)
  // =========================================================
  Widget _buildStatusHormonCard(LaporanLabModel? laporan) {
    const colorTopLeft = Color(0xFF0074A3);
    const colorBottomRight = Color(0xFF36B89E);

    HasilLabModel? getHasilLab(String nama) {
      if (laporan == null || laporan.hasilLab.isEmpty) return null;
      try {
        return laporan.hasilLab.firstWhere((h) =>
        h.parameters.isNotEmpty &&
            h.parameters.first.namaParameter.toUpperCase().contains(nama.toUpperCase()));
      } catch (e) {
        return null;
      }
    }

    final tshLab = getHasilLab('TSH');
    final ft3Lab = getHasilLab('FT3');
    final ft4Lab = getHasilLab('FT4');

    ParameterLabModel getParamOrDefault(HasilLabModel? hasil, String name, String defaultSatuan) {
      if (hasil != null && hasil.parameters.isNotEmpty) {
        return hasil.parameters.first;
      }
      return ParameterLabModel(
        idParameter: 0,
        idHasilLab: 0,
        namaParameter: name,
        nilaiHasil: 0.0,
        satuan: defaultSatuan,
        kategori: null,
      );
    }

    final metrics = [
      getParamOrDefault(tshLab, 'TSH', 'mIU/L'),
      getParamOrDefault(ft4Lab, 'FT4', 'pmol/L'),
      getParamOrDefault(ft3Lab, 'FT3', 'pmol/L'),
    ];

    String displayStatus = 'Status';
    if (laporan != null && laporan.hasilLab.isNotEmpty) {
      if (laporan.kesimpulanLab != null &&
          laporan.kesimpulanLab!.interpretasi != null &&
          laporan.kesimpulanLab!.interpretasi!.trim().isNotEmpty) {
        displayStatus = laporan.kesimpulanLab!.interpretasi!.trim();
      } else {
        displayStatus = 'Diproses';
      }
    }

    String stringTanggal = 'Belum ada riwayat';
    if (laporan != null && laporan.tglPeriksa != null) {
      stringTanggal = DateFormat('dd MMMM yyyy', 'id_ID').format(laporan.tglPeriksa!);
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [colorTopLeft, colorBottomRight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: colorTopLeft.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Status Hormon',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19),
              ),
              Flexible(
                child: Text(
                  displayStatus,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 26,
                    height: 1.0,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Data terakhir:\n$stringTanggal',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (laporan != null && laporan.hasilLab.isNotEmpty)
            GestureDetector(
              onTap: () => _showHCAIExplainabilitySheet(context, displayStatus, laporan),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), color: const Color(0xFFFDE047), size: 14),
                    const SizedBox(width: 6),
                    const Text('Lihat Analisis AI', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: List.generate(metrics.length, (index) {
              final param = metrics[index];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index == metrics.length - 1 ? 0 : 8),
                  child: _buildStatusMetricCard(param),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusMetricCard(ParameterLabModel param) {
    double val = param.nilaiHasil;

    String displayValue;
    if (val == 0.0) {
      displayValue = '0';
    } else {
      final int decimalPlaces = (param.namaParameter.toUpperCase().contains("TSH")) ? 3 : 2;
      displayValue = val.toStringAsFixed(decimalPlaces);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            param.namaParameter,
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            displayValue,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1),
          ),
          const SizedBox(height: 4),
          Text(
            param.satuan ?? '',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _emptyMedicationCard(VoidCallback onCardPressed, VoidCallback onButtonPressed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onCardPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFF0F2F5),
                      radius: 40,
                      child: Icon(
                        PhosphorIcons.pill(PhosphorIconsStyle.regular),
                        color: Colors.grey.shade400,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Belum Ada Obat',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Anda belum menambahkan\njadwal konsumsi obat untuk hari ini.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onButtonPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006699),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 0,
          ),
          child: const Text(
            'Atur Jadwal Obat',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMedicationCard(List<JadwalObatModel> groupedJadwal) {
    final jadwalUtama = groupedJadwal.first;
    final Set<String> uniqueTimes = {};
    final Set<String> uniqueDays = {};

    for (var j in groupedJadwal) {
      if (j.waktuMinumObat != null && j.waktuMinumObat!.isNotEmpty) {
        uniqueTimes.addAll(j.waktuMinumObat!.split(',').map((t) => t.trim()));
      }
      if (j.hari != null && j.hari!.isNotEmpty) {
        uniqueDays.addAll(j.hari!.split(',').map((d) => d.trim()));
      }
    }

    final sortedTimes = uniqueTimes.toList()..sort();
    final sortedDays = uniqueDays.toList();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetailObatScreen(
              jadwal: jadwalUtama,
              times: sortedTimes,
              days: sortedDays,
            ),
          ),
        ).then((_) => _refresh());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00695C).withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: Color(0xFFE9F4F1),
                  shape: BoxShape.circle
              ),
              child: Center(
                child: Icon(
                  PhosphorIcons.pill(PhosphorIconsStyle.regular),
                  color: const Color(0xFF00695C),
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    jadwalUtama.obat.namaObat,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Colors.black,
                        letterSpacing: -0.5
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        jadwalUtama.obat.dosis ?? '-',
                        style: const TextStyle(color: Color(0xFF7B838A), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        jadwalUtama.obat.frekuensi ?? '-',
                        style: const TextStyle(color: Color(0xFF7B838A), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (sortedTimes.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sortedTimes.map((time) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEAEFF2),
                            borderRadius: BorderRadius.circular(20)
                        ),
                        child: Text(
                          (time.length >= 5) ? time.substring(0, 5) : time,
                          style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                              fontSize: 13
                          ),
                        ),
                      )).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyWearableCard(VoidCallback onHubungkanPressed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildPhoneIllustration(),
              const SizedBox(width: 16),
              Icon(Icons.swap_horiz, color: Colors.grey.shade400, size: 36),
              const SizedBox(width: 16),
              _buildPhoneIllustration(),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            '-Hubungkan\nPerangkat',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                height: 1.4,
                color: Color(0xFF101828)),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pastikan kedua perangkat aktif\ndan berada dalam jangkauan untuk\nmulai memantau aktivitas harian.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, height: 1.5, color: Color(0xFF667085)),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: onHubungkanPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF005680),
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
              elevation: 0,
            ),
            child: const Text('Hubungkan',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneIllustration() {
    return Container(
      width: 75,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 14),
            width: 24,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD9DCE2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 32,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFD9DCE2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                margin: const EdgeInsets.all(4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Color(0xFFD9DCE2),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIInsightCard(HasilAIHarianModel? aiData) {
    List<String> kumpulanReminder = [];

    if (aiData != null) {
      if (aiData.reminderHr != null &&
          aiData.reminderHr!.isNotEmpty &&
          aiData.reminderHr != '-') {
        kumpulanReminder.add(aiData.reminderHr!);
      }

      if (aiData.reminderTd != null &&
          aiData.reminderTd!.isNotEmpty &&
          aiData.reminderTd != '-') {
        kumpulanReminder.add(aiData.reminderTd!);
      }

      if (aiData.reminderTidur != null &&
          aiData.reminderTidur!.isNotEmpty &&
          aiData.reminderTidur != '-') {
        kumpulanReminder.add(aiData.reminderTidur!);
      }
    }

    final String pesanFinal = kumpulanReminder.isNotEmpty
        ? kumpulanReminder.join(" ")
        : "Sedang menganalisis pola aktivitas harian Anda. Menunggu data sinkronisasi lebih lanjut.";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD0E2FF), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0B70C9).withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Color(0xFF0B70C9), size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Informasi Aktivitas Fisiologis",
                    style: TextStyle(
                        color: Color(0xFF0B70C9),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F0FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, size: 6, color: Color(0xFF0B70C9)),
                    SizedBox(width: 4),
                    Text(
                      "Data Real-Time",
                      style: TextStyle(
                          color: Color(0xFF0B70C9),
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            pesanFinal,
            style: const TextStyle(
                color: Color(0xFF4B5563), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildWearablesSection(WearableModel wearable, int userId) {
    int sleepPercentInt = 0;
    String sleepTime = '-';
    String sleepStatus;
    Color sleepBadgeBg;
    Color sleepBadgeText;

    if (wearable.sleepDuration == 0) {
      sleepStatus = 'Tidak Ada Data';
      sleepBadgeBg = const Color(0xFFF3F4F6);
      sleepBadgeText = const Color(0xFF6B7280);
    } else {
      final double goalInMinutes = 8 * 60;
      final percent = (wearable.sleepDuration / goalInMinutes).clamp(0.0, 1.0);
      sleepPercentInt = (percent * 100).toInt();

      final hours = wearable.sleepDuration ~/ 60;
      final minutes = wearable.sleepDuration % 60;
      sleepTime = '${hours}j ${minutes}m Tidur';

      if (wearable.sleepDuration < 420) {
        sleepStatus = 'Kurang';
        sleepBadgeBg = const Color(0xFFFEF3C7);
        sleepBadgeText = const Color(0xFF92400E);
      } else if (wearable.sleepDuration <= 540) {
        sleepStatus = 'Normal';
        sleepBadgeBg = const Color(0xFF8DF0A8);
        sleepBadgeText = const Color(0xFF064E3B);
      } else {
        sleepStatus = 'Berlebih';
        sleepBadgeBg = const Color(0xFFFADBD8);
        sleepBadgeText = const Color(0xFFC0392B);
      }
    }

    final int hr = wearable.heartRateRHR;
    final String hrStatus;
    final Color hrBadgeBg;
    final Color hrBadgeText;

    if (hr == 0) {
      hrStatus = 'Tidak Ada Data';
      hrBadgeBg = const Color(0xFFF3F4F6);
      hrBadgeText = const Color(0xFF6B7280);
    } else if (hr < 60) {
      hrStatus = 'Rendah';
      hrBadgeBg = const Color(0xFFFEF3C7);
      hrBadgeText = const Color(0xFF92400E);
    } else if (hr <= 100) {
      hrStatus = 'Normal';
      hrBadgeBg = const Color(0xFF8DF0A8);
      hrBadgeText = const Color(0xFF064E3B);
    } else {
      hrStatus = 'Tinggi';
      hrBadgeBg = const Color(0xFFFADBD8);
      hrBadgeText = const Color(0xFFC0392B);
    }

    final int sistolik = wearable.sistolik;
    final int diastolik = wearable.diastolik;

    final String bpStatus;
    final Color bpBadgeBg;
    final Color bpBadgeText;
    final String bpValue;

    if (sistolik == 0 || diastolik == 0) {
      bpStatus = 'Tidak Ada Data';
      bpBadgeBg = const Color(0xFFF3F4F6);
      bpBadgeText = const Color(0xFF6B7280);
      bpValue = '-/-';
    } else if (sistolik >= 130 || diastolik > 80) {
      bpStatus = 'Tinggi';
      bpBadgeBg = const Color(0xFFFADBD8);
      bpBadgeText = const Color(0xFFC0392B);
      bpValue = '$sistolik/$diastolik';
    } else if (sistolik < 90 || diastolik < 60) {
      bpStatus = 'Rendah';
      bpBadgeBg = const Color(0xFFFEF3C7);
      bpBadgeText = const Color(0xFF92400E);
      bpValue = '$sistolik/$diastolik';
    } else {
      bpStatus = 'Normal';
      bpBadgeBg = const Color(0xFF8DF0A8);
      bpBadgeText = const Color(0xFF064E3B);
      bpValue = '$sistolik/$diastolik';
    }

    final aiData = wearable.hasilAI.isNotEmpty ? wearable.hasilAI.last : null;

    return Column(
      children: [
        _buildAIInsightCard(aiData),

        _buildActivityBaseCard(
          title: 'Detak Jantung',
          icon: PhosphorIcons.heart(PhosphorIconsStyle.regular),
          iconBgColor: const Color(0xFFFCF3F2),
          iconColor: const Color(0xFFD9534F),
          statusTag: _statusBadge(hrStatus, hrBadgeBg, hrBadgeText),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => WearableSummaryScreen(
                    metricType: 'detak jantung',
                    userId: userId,
                  )
              )
          ),
          bottomContent: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(hr == 0 ? '-' : '$hr', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              const SizedBox(width: 6),
              const Text('BPM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildActivityBaseCard(
          title: 'Waktu Tidur',
          icon: PhosphorIcons.moon(PhosphorIconsStyle.regular),
          iconBgColor: const Color(0xFFEDF4FC),
          iconColor: const Color(0xFF2C5282),
          statusTag: _statusBadge(sleepStatus, sleepBadgeBg, sleepBadgeText),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => WearableSummaryScreen(
                    metricType: 'tidur',
                    userId: userId,
                  )
              )
          ),
          bottomContent: Row(
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: sleepPercentInt / 100,
                      strokeWidth: 6.5,
                      backgroundColor: const Color(0xFFF3F4F6),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0B70C9)),
                    ),
                    Center(child: Text('$sleepPercentInt%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1F2937)))),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Text(sleepTime, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF4B5563))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildActivityBaseCard(
          title: 'Tekanan Darah',
          icon: Icons.bloodtype_outlined,
          iconBgColor: const Color(0xFFEAF5EF),
          iconColor: const Color(0xFF2E7D32),
          statusTag: _statusBadge(bpStatus, bpBadgeBg, bpBadgeText),
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => WearableSummaryScreen(
                    metricType: 'tekanan darah',
                    userId: userId,
                  )
              )
          ),
          bottomContent: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(bpValue, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              const SizedBox(width: 6),
              const Text('mmHg', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActivityBaseCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required Widget statusTag,
    required Widget bottomContent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                ),
                statusTag,
              ],
            ),
            const SizedBox(height: 20),
            bottomContent,
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, -2))
        ],
      ),
      child: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem("home", "Beranda", 0),
              _navItem("monitor", "Monitor", 1),
              _navItem("riwayat", "Riwayat", 2),
              _navItem("edukasi", "Edukasi", 3),
              _navItem("profil", "Profil", 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(String assetName, String label, int index) {
    final bool isSelected = _selectedIndex == index;
    final String finalAssetName =
    isSelected ? "$assetName-on.png" : "$assetName-off.png";

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE5F0FA) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Image.asset(
                "assets/images/navbar/$finalAssetName",
                key: ValueKey(finalAssetName),
                width: 24,
                height: 24,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.circle,
                  size: 24,
                  color: isSelected ? const Color(0xFF0B70C9) : Colors.grey.shade300,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected
                  ? const Color(0xFF0B70C9)
                  : const Color(0xFF9CA3AF).withOpacity(0.5),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}