import 'package:adhan/adhan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class PrayerService {
  // 1. دالة حساب أوقات الصلاة بناءً على رابطة العالم الإسلامي بدمشق
  static PrayerTimes getSyriaPrayerTimes() {
    final coordinates = Coordinates(33.5138, 36.2765);
    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.shafi;

    return PrayerTimes.today(coordinates, params);
  }

  // 2. دالة جدولة الإشعارات للمغرب والعشاء
  static Future<void> schedulePrayerAlerts(FlutterLocalNotificationsPlugin plugin) async {
    tz_data.initializeTimeZones();
    final prayerTimes = getSyriaPrayerTimes();
    final now = DateTime.now();

    List<Map<String, dynamic>> alerts = [
      {
        'id': 101,
        'title': 'اقترب أذان المغرب 🕌',
        'body': 'باقي 10 دقائق على أذان المغرب',
        'time': prayerTimes.maghrib.subtract(const Duration(minutes: 10)),
      },
      {
        'id': 102,
        'title': 'اقترب أذان المغرب 🕌',
        'body': 'باقي 5 دقائق فقط على أذان المغرب',
        'time': prayerTimes.maghrib.subtract(const Duration(minutes: 5)),
      },
      {
        'id': 201,
        'title': 'اقترب أذان العشاء 🌙',
        'body': 'باقي 10 دقائق على أذان العشاء',
        'time': prayerTimes.isha.subtract(const Duration(minutes: 10)),
      },
      {
        'id': 202,
        'title': 'اقترب أذان العشاء 🌙',
        'body': 'باقي 5 دقائق فقط على أذان العشاء',
        'time': prayerTimes.isha.subtract(const Duration(minutes: 5)),
      },
    ];

    for (var alert in alerts) {
      DateTime alertTime = alert['time'];
      if (alertTime.isAfter(now)) {
        await plugin.zonedSchedule(
          alert['id'],
          alert['title'],
          alert['body'],
          tz.TZDateTime.from(alertTime, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'prayer_alerts_channel',
              'تنبيهات أوقات الصلاة',
              channelDescription: 'إشعارات تذكير قبل أذان المغرب والعشاء',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }
}