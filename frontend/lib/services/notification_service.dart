import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io' show Platform;

import 'package:gdself/main.dart';
import 'package:gdself/models/obat_model.dart';
import 'package:gdself/features/home/ui/notifikasi_obat_dialog.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isLaunchHandled = false;

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    } else if (Platform.isIOS || Platform.isMacOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  void _tampilkanPopUpCantik(String payload) async {
    int retries = 0;
    while (navigatorKey.currentContext == null && retries < 50) {
      await Future.delayed(const Duration(milliseconds: 200));
      retries++;
    }
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => NotifikasiObatDialog(payload: payload),
    );
  }

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));

    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@drawable/launcher_icon');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid, iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        _tampilkanPopUpCantik(response.payload ?? "");
      },
    );

    final NotificationAppLaunchDetails? launchDetails = await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp && !_isLaunchHandled) {
      _isLaunchHandled = true;
      _tampilkanPopUpCantik(launchDetails.notificationResponse?.payload ?? "");
    }
  }

  // ✅ Helper internal untuk menjadwalkan alarm dengan fallback aman Android 14+
  Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required String payload,
    required NotificationDetails notificationDetails,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    } catch (e) {
      debugPrint('⚠️ Exact alarm ditolak/gagal (id: $id), beralih ke inexact alarm: $e');
      // Fallback aman untuk Android 14+ jika exact alarm dibatasi oleh pengguna/sistem
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
      );
    }
  }

  // ✅ FUNGSI SNOOZE KHUSUS
  Future<void> buatSnoozeKhusus(List<JadwalObatModel> obatSisa, String waktuAsli) async {
    if (obatSisa.isEmpty) return;

    String idObatSisa = obatSisa.map((o) => o.idJadwalObat.toString()).join(',');
    int idSnoozeBaru = (obatSisa.first.idJadwalObat ?? 0) + 99999;

    String payloadSnoozeKhusus = 'snooze_parsial|$waktuAsli|$idSnoozeBaru|$idObatSisa';
    tz.TZDateTime jadwalSnoozeBaru = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 10));

    String title = obatSisa.length == 1
        ? 'Peringatan Susulan: ${obatSisa.first.obat.namaObat}'
        : 'Peringatan Susulan Obat!';

    await _safeZonedSchedule(
      id: idSnoozeBaru,
      title: title,
      body: 'Anda belum meminum obat ini, ketuk untuk mencatat.',
      scheduledDate: jadwalSnoozeBaru,
      payload: payloadSnoozeKhusus,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
            'channel_obat_rutin', 'Alarm Obat',
            importance: Importance.max, priority: Priority.high, fullScreenIntent: true, category: AndroidNotificationCategory.alarm
        ),
      ),
    );
  }

  Future<void> syncSemuaAlarm(List<JadwalObatModel> semuaJadwal) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    await flutterLocalNotificationsPlugin.cancelAll();

    final Map<String, List<JadwalObatModel>> kelompokAlarm = {};

    for (var jadwal in semuaJadwal) {
      final hariRaw = jadwal.hari ?? "";
      final waktuRaw = jadwal.waktuMinumObat ?? "";
      if (hariRaw.isEmpty || waktuRaw.isEmpty) continue;

      final listHari = hariRaw.split(',');
      final listWaktu = waktuRaw.split(',');

      for (var h in listHari) {
        for (var w in listWaktu) {
          String hariBersih = h.trim();
          String waktuBersih = w.trim();

          if (hariBersih.isEmpty || waktuBersih.isEmpty) continue;
          if (waktuBersih.length >= 5) waktuBersih = waktuBersih.substring(0, 5);

          List<int> weekdays = _ubahHariKeListAngka(hariBersih);

          for (int weekday in weekdays) {
            String key = "${weekday}_$waktuBersih";
            if (!kelompokAlarm.containsKey(key)) kelompokAlarm[key] = [];
            if (!kelompokAlarm[key]!.any((j) => j.idJadwalObat == jadwal.idJadwalObat)) {
              kelompokAlarm[key]!.add(jadwal);
            }
          }
        }
      }
    }

    for (String key in kelompokAlarm.keys) {
      final listJadwal = kelompokAlarm[key]!;
      final parts = key.split('_');
      int weekday = int.parse(parts[0]);
      String waktuStr = parts[1];

      List<String> timeParts = waktuStr.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      int alarmIdUtama = (weekday * 10000) + (hour * 100) + minute;
      int alarmIdSnooze = alarmIdUtama + 50000;

      tz.TZDateTime jadwalUtama = _nextInstanceOfDayAndTime(weekday, hour, minute);
      tz.TZDateTime jadwalSnooze = jadwalUtama.add(const Duration(minutes: 10));

      String hariNama = _ubahAngkaKeHari(weekday).toLowerCase();
      String payloadUtama = '$hariNama|$waktuStr|$alarmIdSnooze|utama';
      String payloadSnooze = '$hariNama|$waktuStr|$alarmIdSnooze|snooze';

      String titleUtama = listJadwal.length == 1
          ? 'Waktunya Minum ${listJadwal.first.obat.namaObat}'
          : 'Waktunya Minum Obat!';
      String bodyUtama = listJadwal.length == 1
          ? 'Dosis: ${listJadwal.first.obat.dosis ?? "-"}'
          : 'Terdapat ${listJadwal.length} obat yang perlu diminum sekarang.';

      // Alarm Utama
      await _safeZonedSchedule(
        id: alarmIdUtama,
        title: titleUtama,
        body: bodyUtama,
        scheduledDate: jadwalUtama,
        payload: payloadUtama,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('channel_obat_rutin', 'Alarm Obat', importance: Importance.max, priority: Priority.high, fullScreenIntent: true, category: AndroidNotificationCategory.alarm),
        ),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );

      // Alarm Snooze
      await _safeZonedSchedule(
        id: alarmIdSnooze,
        title: listJadwal.length == 1 ? 'Peringatan Susulan: ${listJadwal.first.obat.namaObat}' : 'Peringatan Susulan Obat!',
        body: 'Jangan lewatkan jadwal obat Anda, ketuk untuk mencatat log.',
        scheduledDate: jadwalSnooze,
        payload: payloadSnooze,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails('channel_obat_rutin', 'Alarm Obat', importance: Importance.max, priority: Priority.high, fullScreenIntent: true, category: AndroidNotificationCategory.alarm),
        ),
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  List<int> _ubahHariKeListAngka(String day) {
    String d = day.toLowerCase().trim();
    if (d.contains('setiap hari') || d.contains('tiap hari') || d.contains('semua hari')) return [1, 2, 3, 4, 5, 6, 7];
    switch (d) {
      case 'senin': case 'sen': return [1];
      case 'selasa': case 'sel': return [2];
      case 'rabu': case 'rab': return [3];
      case 'kamis': case 'kam': return [4];
      case 'jumat': case 'jum': return [5];
      case 'sabtu': case 'sab': return [6];
      case 'minggu': case 'min': return [7];
      default: return [1];
    }
  }

  String _ubahAngkaKeHari(int weekday) {
    switch (weekday) {
      case 1: return 'SEN'; case 2: return 'SEL'; case 3: return 'RAB';
      case 4: return 'KAM'; case 5: return 'JUM'; case 6: return 'SAB';
      case 7: return 'MIN'; default: return 'SEN';
    }
  }

  tz.TZDateTime _nextInstanceOfDayAndTime(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    int daysUntilTarget = (weekday - now.weekday + 7) % 7;
    scheduledDate = scheduledDate.add(Duration(days: daysUntilTarget));
    if (daysUntilTarget == 0 && scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 7));
    return scheduledDate;
  }
}