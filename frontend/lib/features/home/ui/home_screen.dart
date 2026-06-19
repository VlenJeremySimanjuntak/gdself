import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gdself/features/home/ui/tambah_obat_screen.dart';
import 'package:gdself/features/home/ui/wearable_summary_screen.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/hasil_ai_harian_model.dart';
import '../../../models/lab_data_model.dart';
import '../../../models/obat_model.dart';
import '../../../models/wearable_model.dart';
import '../../../models/hasil_ai_gabungan_model.dart';
import '../../riwayat/ui/riwayat_screen.dart';
import '../../education/ui/education_screen.dart';
import '../../home/providers/home_provider.dart';
import '../../home/providers/user_provider.dart';
import '../../monitoring/ui/monitoring_screen.dart';
import '../../../utils/design_system.dart';
import '../../profil/ui/profile_screen.dart';
import 'jadwal_obat_screen.dart';
import 'edit_obat_screen.dart';
import 'wearable_sync_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isDisconnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cekStatusKoneksi();
    final userId = ref.read(userProvider).user?.idUser;
    if (userId != null) {
      Future.microtask(() => ref.read(homeProvider.notifier).fetchAll(userId));
    }
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

  Future<void> _cekStatusKoneksi() async {
    final Health health = Health();
    health.configure();

    final types = [HealthDataType.HEART_RATE, HealthDataType.SLEEP_SESSION];
    final permissions = [HealthDataAccess.READ, HealthDataAccess.READ];

    bool hasRealPermissions = false;
    try {
      hasRealPermissions =
          await health.hasPermissions(types, permissions: permissions) ?? false;
    } catch (_) {
      hasRealPermissions = false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_wearable_disconnected', !hasRealPermissions);

    if (!mounted) return;
    setState(() {
      _isDisconnected = !hasRealPermissions;
    });
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        bool isVerifying = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Lepaskan Akses Perangkat', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Untuk keamanan, Anda perlu mencabut izin akses GdSelf di pengaturan sistem.',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  _buildStep("1. Buka Pengaturan > Privasi > Health Connect."),
                  _buildStep("2. Pilih aplikasi GdSelf."),
                  _buildStep("3. Matikan izin Akses Data."),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005680)),
                  onPressed: isVerifying ? null : () async {
                    setDialogState(() => isVerifying = true);

                    final Health health = Health();
                    health.configure();
                    await health.requestAuthorization([HealthDataType.HEART_RATE, HealthDataType.SLEEP_SESSION]);

                    await Future.delayed(const Duration(seconds: 2));

                    bool masihAdaIzin = await health.hasPermissions(
                      [HealthDataType.HEART_RATE, HealthDataType.SLEEP_SESSION],
                      permissions: [HealthDataAccess.READ, HealthDataAccess.READ],
                    ) ?? false;

                    if (!masihAdaIzin) {
                      await _setDisconnectState(true);
                      if (context.mounted) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Akses berhasil dilepaskan!')));
                    } else {
                      setDialogState(() => isVerifying = false);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin masih aktif, silakan matikan manual.')));
                    }
                  },
                  child: isVerifying
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Saya Sudah Matikan', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStep(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final formattedDay = DateFormat('EEEE', 'id_ID').format(now);
    final formattedDate = DateFormat('dd MMMM yyyy', 'id_ID').format(now);
    final formattedTime = DateFormat('HH:mm').format(now);

    final semuaJadwalObat = state.jadwalObat;

    final Map<String, String> dayToDbFormat = {
      'senin': 'sen', 'selasa': 'sel', 'rabu': 'rab',
      'kamis': 'kam', 'jumat': 'jum', 'sabtu': 'sab', 'minggu': 'min',
    };
    final hariIniDbStr = dayToDbFormat[formattedDay.toLowerCase()] ?? '';

    final jadwalObatHariIni = semuaJadwalObat.where((jadwal) {
      final hariKonsumsi = jadwal.hari?.toLowerCase() ?? '';

      bool isHariIni = hariKonsumsi.contains(hariIniDbStr) ||
          hariKonsumsi.contains(formattedDay.toLowerCase());

      bool isAktif = true;
      if (jadwal.obat.tglSelesai != null) {
        final batasSelesai = DateTime(
            jadwal.obat.tglSelesai!.year,
            jadwal.obat.tglSelesai!.month,
            jadwal.obat.tglSelesai!.day
        );
        isAktif = batasSelesai.isAfter(today) || batasSelesai.isAtSameMomentAs(today);
      }

      return isHariIni && isAktif;
    }).toList();

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
        _refresh();
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
                _buildTopHeader(user),
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
                      ...jadwalObatHariIni.map((jadwal) {
                        return _buildMedicationCard(jadwal);
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
                    if (wearable != null && !_isDisconnected)
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

                _buildWearablesSection(
                    wearable ?? WearableModel(
                      idWearable: 0,
                      idUser: 0,
                      heartRateRHR: 78,
                      sleepDuration: 26500,
                      hasilAI: [],
                    )
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(dynamic user) {
    final String initial =
    (user?.nama != null && (user!.nama as String).isNotEmpty)
        ? (user.nama as String)[0].toUpperCase()
        : '?';

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
                  fontSize: 18),
            ),
          ],
        ),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFFE3ECF7),
          child: Text(
            initial,
            style: const TextStyle(
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
                fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusHormonCard(LaporanLabModel? laporan) {
    const colorTopLeft = Color(0xFF0074A3);
    const colorBottomRight = Color(0xFF36B89E);

    HasilLabModel? getHasilLab(String nama) {
      if (laporan == null || laporan.hasilLab.isEmpty) return null;
      try {
        return laporan.hasilLab.firstWhere((h) =>
        h.parameters.isNotEmpty &&
            h.parameters.first.namaParameter.toUpperCase().contains(nama.toUpperCase())
        );
      } catch (e) {
        return null;
      }
    }

    final tshLab = getHasilLab('TSH');
    final ft3Lab = getHasilLab('FT3');
    final ft4Lab = getHasilLab('FT4');

    int getStatusLevel(HasilLabModel? hasil) {
      if (hasil == null) return -2;
      if (hasil.nilaiHasil < hasil.rujukanMin) return -1;
      if (hasil.nilaiHasil > hasil.rujukanMax) return 1;
      return 0;
    }

    int tshStatus = getStatusLevel(tshLab);
    int ft3Status = getStatusLevel(ft3Lab);
    int ft4Status = getStatusLevel(ft4Lab);

    String displayStatus = 'Tidak Diketahui';

    if (laporan == null || laporan.hasilLab.isEmpty) {
      displayStatus = 'Belum Ada';
    } else {
      if (tshStatus == 0 && ft3Status == 0 && ft4Status == 0) {
        displayStatus = 'Normal';
      } else if (tshStatus == -1 && ft3Status == 1 && ft4Status == 1) {
        displayStatus = 'Belum normal';
      } else if (tshStatus == -1 && ft3Status == 1 && ft4Status == 0) {
        displayStatus = 'Belum normal';
      } else if (tshStatus == -1 && ft3Status == 0 && ft4Status == 1) {
        displayStatus = 'Belum normal';
      }
    }

    ParameterLabModel getParamOrDefault(HasilLabModel? hasil, String name, String defaultSatuan) {
      if (hasil != null && hasil.parameters.isNotEmpty) {
        return hasil.parameters.first;
      }
      return ParameterLabModel(
        idParameter: 0,
        idHasilLab: 0,
        namaParameter: name,
        nilaiHasil: 0.0, // PERBAIKAN: nilai → nilaiHasil
        satuan: defaultSatuan,
        kategori: null,
      );
    }

    final metrics = [
      getParamOrDefault(tshLab, 'TSH', 'mIU/L'),
      getParamOrDefault(ft3Lab, 'FT3', 'pmol/L'),
      getParamOrDefault(ft4Lab, 'FT4', 'pmol/L'),
    ];

    final lastDate = laporan?.tglPeriksa ?? DateTime.now();

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 1),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [colorTopLeft, colorBottomRight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
                color: colorTopLeft.withOpacity(0.3),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Hormon',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Data terakhir:\n${DateFormat('dd MMMM yyyy', 'id_ID').format(lastDate)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                Text(
                  displayStatus.replaceAll(' ', '\n'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: List.generate(metrics.length, (index) {
                final param = metrics[index];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: index == metrics.length - 1 ? 0 : 12),
                    child: _buildStatusMetricCard(param),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusMetricCard(ParameterLabModel param) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(param.namaParameter,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(param.nilaiHasil.toStringAsFixed(1), // PERBAIKAN: nilai → nilaiHasil
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1)),
          const SizedBox(height: 4),
          Text(param.satuan ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }

  // --- Sisa widget (emptyMedicationCard, buildMedicationCard, wearable cards, dll.) sama persis seperti sebelumnya ---
  // Karena tidak ada perubahan, saya singkat dengan placeholder agar tidak terlalu panjang.
  // Namun untuk kode lengkap, saya tetap sertakan di bawah ini.

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

  Widget _buildMedicationCard(JadwalObatModel jadwal) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => EditObatScreen(jadwal: jadwal)),
        ).then((_) => _refresh());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(40),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF00695C).withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle),
              child: Center(
                child: Icon(
                    PhosphorIcons.pill(PhosphorIconsStyle.regular),
                    color: const Color(0xFF00695C),
                    size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    jadwal.obat.namaObat,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: -0.3,
                        color: Colors.black),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    jadwal.obat.dosis ?? '-',
                    style: const TextStyle(
                        color: Color(0xFF757575),
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  if (jadwal.waktuMinumObat != null)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: jadwal.waktuMinumObat!
                          .split(',')
                          .map((time) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF0F2F5),
                            borderRadius:
                            BorderRadius.circular(12)),
                        child: Text(
                          time.trim().substring(0, 5),
                          style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 11),
                        ),
                      ))
                          .toList(),
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
            'Hubungkan\nPerangkat',
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
    final String pesan = aiData?.pesanHarian ??
        "Sedang menganalisis pola aktivitas harian Anda. Menunggu data sinkronisasi lebih lanjut.";

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
                    "AI INSIGHT",
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
            pesan,
            style: const TextStyle(
                color: Color(0xFF4B5563), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildWearablesSection(WearableModel wearable) {
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
      final double goalInMinutes = 8 * 60; // 480 menit
      final percent = (wearable.sleepDuration / goalInMinutes).clamp(0.0, 1.0);
      final hours = wearable.sleepDuration ~/ 60;
      final minutes = wearable.sleepDuration % 60;
      sleepTime = '${hours}j ${minutes}m Deep Sleep';

      if (sleepPercentInt >= 85) {
        sleepStatus = 'Cukup';
        sleepBadgeBg = const Color(0xFF8DF0A8);
        sleepBadgeText = const Color(0xFF064E3B);
      } else if (sleepPercentInt >= 60) {
        sleepStatus = 'Kurang';
        sleepBadgeBg = const Color(0xFFFEF3C7);
        sleepBadgeText = const Color(0xFF92400E);
      } else {
        sleepStatus = 'Sangat Kurang';
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

    final String bpStatus = 'Normal';
    final Color bpBadgeBg = const Color(0xFF8DF0A8);
    final Color bpBadgeText = const Color(0xFF064E3B);
    final String bpValue = "120/80";

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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WearableSummaryScreen(metricType: 'Detak Jantung'))),
          bottomContent: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$hr', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
              const SizedBox(width: 6),
              const Text('BPM', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _buildActivityBaseCard(
          title: 'Tidur',
          icon: PhosphorIcons.moon(PhosphorIconsStyle.regular),
          iconBgColor: const Color(0xFFEDF4FC),
          iconColor: const Color(0xFF2C5282),
          statusTag: _statusBadge(sleepStatus, sleepBadgeBg, sleepBadgeText),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WearableSummaryScreen(metricType: 'Tidur'))),
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
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WearableSummaryScreen(metricType: 'Tekanan Darah'))),
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
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
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