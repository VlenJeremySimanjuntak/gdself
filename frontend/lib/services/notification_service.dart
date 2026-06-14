import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;

import '../main.dart'; // Mengambil navigatorKey
import '../features/home/ui/notifikasi_obat_dialog.dart'; // Mengambil desain Pop-up

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isLaunchHandled = false;

  // ========================================================
  // 👇 FUNGSI SAKTI: MENUNGGU FLUTTER SIAP SEBELUM MUNCULKAN POP-UP
  // ========================================================
  void _tampilkanPopUpCantik(String payload) async {
    // Looping aman: Tunggu sampai mesin Flutter selesai me-render layar (Context tidak null)
    while (navigatorKey.currentContext == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Jika layar sudah siap, langsung HAJAR munculkan pop-up!
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false, // Wajib klik tombol, tidak bisa klik luar
      builder: (BuildContext context) {
        return NotifikasiObatDialog(namaObat: payload);
      },
    );
  }
  // ========================================================

  // 1. Fungsi Inisialisasi
  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Jika notifikasi ditekan saat HP menyala
        final payload = response.payload ?? "Obat";
        debugPrint("🔔 Notifikasi ditekan! Menyiapkan UI untuk: $payload");
        _tampilkanPopUpCantik(payload);
      },
    );

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    // Deteksi jika aplikasi dibuka PAKSA oleh alarm saat layar mati
    final NotificationAppLaunchDetails? launchDetails =
    await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (launchDetails != null && launchDetails.didNotificationLaunchApp && !_isLaunchHandled) {
      _isLaunchHandled = true;
      final payload = launchDetails.notificationResponse?.payload ?? "Obat";
      debugPrint("🚀 Layar didobrak Alarm! Menyiapkan UI untuk: $payload");
      _tampilkanPopUpCantik(payload);
    }
  }

  // 2. Fungsi Utama: Menjadwalkan Alarm Mingguan
  Future<void> jadwalkanAlarmObat({
    required int idObat,
    required String namaObat,
    required List<String> hariKonsumsi,
    required List<TimeOfDay> waktuKonsumsi,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    for (String hari in hariKonsumsi) {
      int weekday = _ubahHariKeAngka(hari);

      for (int i = 0; i < waktuKonsumsi.length; i++) {
        final waktu = waktuKonsumsi[i];

        int alarmId = (idObat * 1000) + (weekday * 100) + i;

        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: alarmId,
          title: 'Waktunya Minum $namaObat!',
          body: 'Jam ${waktu.hour.toString().padLeft(2, '0')}:${waktu.minute.toString().padLeft(2, '0')}. Jangan lupa minum obat Anda.',
          scheduledDate: _nextInstanceOfDayAndTime(weekday, waktu.hour, waktu.minute),
          payload: namaObat, // 👈 Nama obat dikirim ke Pop-up
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_obat_rutin',
              'Alarm Obat',
              channelDescription: 'Alarm prioritas tinggi untuk jadwal minum obat',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              audioAttributesUsage: AudioAttributesUsage.alarm,
              playSound: true,
              // 👇 TOMBOL SYSTEM DIHAPUS agar user dipaksa masuk ke Pop-up Custom 👇
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );

        debugPrint("✅ Alarm diset: $namaObat, Hari: $hari, Jam: ${waktu.hour}:${waktu.minute} (ID: $alarmId)");
      }
    }
  }

  // 3. Fungsi Utama: Membatalkan/Menghapus Alarm
  Future<void> batalkanAlarmObat({
    required int idObat,
    required List<String> hariKonsumsi,
    required int jumlahWaktu,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    for (String hari in hariKonsumsi) {
      int weekday = _ubahHariKeAngka(hari);
      for (int i = 0; i < jumlahWaktu; i++) {
        int alarmId = (idObat * 1000) + (weekday * 100) + i;
        await flutterLocalNotificationsPlugin.cancel(id: alarmId);
      }
    }
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  int _ubahHariKeAngka(String day) {
    switch (day.toLowerCase().trim()) {
      case 'senin': return DateTime.monday;
      case 'selasa': return DateTime.tuesday;
      case 'rabu': return DateTime.wednesday;
      case 'kamis': return DateTime.thursday;
      case 'jumat': return DateTime.friday;
      case 'sabtu': return DateTime.saturday;
      case 'minggu': return DateTime.sunday;
      default: return DateTime.monday;
    }
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int weekday, int hour, int minute) {
    tz.TZDateTime scheduledDate = _nextInstanceOfTime(hour, minute);
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}