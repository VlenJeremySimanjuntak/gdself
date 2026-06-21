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

  void _tampilkanPopUpCantik(String payload) async {
    while (navigatorKey.currentContext == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return NotifikasiObatDialog(namaObat: payload);
      },
    );
  }

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Sesuaikan icon bawaan

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
        final payload = response.payload ?? "Obat";
        debugPrint("🔔 Notifikasi ditekan! Payload: $payload");
        _tampilkanPopUpCantik(payload);
      },
    );

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    final NotificationAppLaunchDetails? launchDetails =
    await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();

    if (launchDetails != null && launchDetails.didNotificationLaunchApp && !_isLaunchHandled) {
      _isLaunchHandled = true;
      final payload = launchDetails.notificationResponse?.payload ?? "Obat";
      debugPrint("🚀 Dibuka dari background! Payload: $payload");
      _tampilkanPopUpCantik(payload);
    }
  }

  Future<void> testNotifikasiSekarang() async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 999,
      title: 'Test Minum Obat!',
      body: 'Ini adalah uji coba notifikasi.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
      payload: 'Obat Test|0|0', // Dummy payload
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'channel_obat_rutin',
          'Alarm Obat',
          channelDescription: 'Alarm prioritas tinggi',
          importance: Importance.max,
          priority: Priority.high,
          fullScreenIntent: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

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

        int alarmIdUtama = (idObat * 1000) + (weekday * 100) + i;
        int alarmIdSnooze = alarmIdUtama + 50;

        tz.TZDateTime jadwalUtama = _nextInstanceOfDayAndTime(weekday, waktu.hour, waktu.minute);
        tz.TZDateTime jadwalSnooze = jadwalUtama.add(const Duration(minutes: 2));

        // ✅ PERBAIKAN PAYLOAD: "NamaObat | ID_Snooze | ID_Obat"
        String gabunganPayload = '$namaObat|$alarmIdSnooze|$idObat';

        // 1. ALARM UTAMA
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: alarmIdUtama,
          title: 'Waktunya Minum $namaObat!',
          body: 'Jam ${waktu.hour.toString().padLeft(2, '0')}:${waktu.minute.toString().padLeft(2, '0')}.',
          scheduledDate: jadwalUtama,
          payload: gabunganPayload,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_obat_rutin',
              'Alarm Obat',
              channelDescription: 'Alarm prioritas tinggi',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );

        // 2. ALARM SNOOZE (+10 Menit)
        await flutterLocalNotificationsPlugin.zonedSchedule(
          id: alarmIdSnooze,
          title: 'Peringatan Terakhir: $namaObat!',
          body: 'Sudah lewat 2 menit! Segera minum obat Anda.',
          scheduledDate: jadwalSnooze,
          payload: gabunganPayload,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'channel_obat_rutin',
              'Alarm Obat',
              channelDescription: 'Alarm prioritas tinggi',
              importance: Importance.max,
              priority: Priority.high,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  Future<void> batalkanAlarmObat({
    required int idObat,
    required List<String> hariKonsumsi,
    required int jumlahWaktu,
  }) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;

    for (String hari in hariKonsumsi) {
      int weekday = _ubahHariKeAngka(hari);
      for (int i = 0; i < jumlahWaktu; i++) {
        int alarmIdUtama = (idObat * 1000) + (weekday * 100) + i;
        int alarmIdSnooze = alarmIdUtama + 50;

        await flutterLocalNotificationsPlugin.cancel(id: alarmIdUtama);
        await flutterLocalNotificationsPlugin.cancel(id: alarmIdSnooze);
      }
    }
  }

  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  int _ubahHariKeAngka(String day) {
    switch (day.toLowerCase().trim()) {
      case 'senin': case 'sen': return DateTime.monday;
      case 'selasa': case 'sel': return DateTime.tuesday;
      case 'rabu': case 'rab': return DateTime.wednesday;
      case 'kamis': case 'kam': return DateTime.thursday;
      case 'jumat': case 'jum': return DateTime.friday;
      case 'sabtu': case 'sab': return DateTime.saturday;
      case 'minggu': case 'min': return DateTime.sunday;
      default: return DateTime.monday;
    }
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    int daysUntilTarget = (weekday - now.weekday + 7) % 7;
    scheduledDate = scheduledDate.add(Duration(days: daysUntilTarget));
    if (daysUntilTarget == 0 && scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 7));
    }
    return scheduledDate;
  }
}