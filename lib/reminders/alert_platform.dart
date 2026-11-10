import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'plan.dart';

/// The system's notification service, behind an interface so tests can use
/// a fake.
abstract class AlertPlatform {
  /// [onTap] runs when the user taps one of our notifications while the app
  /// is running.
  Future<void> init(void Function(AlertPayload payload) onTap);

  /// The notification that launched the app, if any.
  Future<AlertPayload?> launchPayload();

  /// Asks for notification (and on Android, exact alarm) permission.
  /// Returns whether notifications may be shown at all.
  Future<bool> requestPermissions();

  Future<List<({int id, AlertPayload? payload})>> pending();

  Future<void> schedule(PlannedAlert alert, {required bool sound});

  Future<void> cancel(int id);
}

/// Does nothing. Used in tests and wherever notifications are unavailable.
class NoAlertPlatform implements AlertPlatform {
  @override
  Future<void> init(void Function(AlertPayload payload) onTap) async {}

  @override
  Future<AlertPayload?> launchPayload() async => null;

  @override
  Future<bool> requestPermissions() async => false;

  @override
  Future<List<({int id, AlertPayload? payload})>> pending() async => const [];

  @override
  Future<void> schedule(PlannedAlert alert, {required bool sound}) async {}

  @override
  Future<void> cancel(int id) async {}
}

/// Real notifications via flutter_local_notifications. Works when the app is
/// closed: Android alarms, macOS UNUserNotificationCenter.
class LocalAlertPlatform implements AlertPlatform {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _exact = false;

  /// Android channel. Sound on and off need separate channels, since a
  /// channel's sound cannot change after it is created.
  static const _channelSound = (id: 'reminders', name: 'Reminders');
  static const _channelQuiet = (id: 'reminders_quiet', name: 'Quiet reminders');

  @override
  Future<void> init(void Function(AlertPayload payload) onTap) async {
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } on Object {
      tz.setLocalLocation(tz.UTC);
    }
    const darwin = DarwinInitializationSettings(
      // Asked for when the first reminder is set, not at launch.
      requestAlertPermission: false,
      requestSoundPermission: false,
      requestBadgePermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        macOS: darwin,
        iOS: darwin,
      ),
      onDidReceiveNotificationResponse: (r) {
        final p = AlertPayload.decode(r.payload);
        if (p != null) onTap(p);
      },
    );
    _exact = await _android?.canScheduleExactNotifications() ?? false;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => Platform.isAndroid
      ? _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
      : null;

  @override
  Future<AlertPayload?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return AlertPayload.decode(details.notificationResponse?.payload);
  }

  @override
  Future<bool> requestPermissions() async {
    final android = _android;
    if (android != null) {
      final shown = await android.requestNotificationsPermission() ?? true;
      if (!(await android.canScheduleExactNotifications() ?? false)) {
        await android.requestExactAlarmsPermission();
      }
      _exact = await android.canScheduleExactNotifications() ?? false;
      return shown;
    }
    final mac = _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    if (mac != null) {
      return await mac.requestPermissions(
            alert: true,
            sound: true,
            badge: true,
          ) ??
          false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<List<({int id, AlertPayload? payload})>> pending() async {
    final list = await _plugin.pendingNotificationRequests();
    return [
      for (final r in list) (id: r.id, payload: AlertPayload.decode(r.payload)),
    ];
  }

  @override
  Future<void> schedule(PlannedAlert alert, {required bool sound}) {
    final channel = sound ? _channelSound : _channelQuiet;
    return _plugin.zonedSchedule(
      id: alert.id,
      scheduledDate: tz.TZDateTime.from(alert.at, tz.local),
      title: alert.title,
      body: alert.body,
      payload: alert.payload.encode(),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          importance: Importance.high,
          priority: Priority.high,
          playSound: sound,
          category: AndroidNotificationCategory.reminder,
        ),
        macOS: DarwinNotificationDetails(presentSound: sound),
        iOS: DarwinNotificationDetails(presentSound: sound),
      ),
      androidScheduleMode: _exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: switch (alert.recurrence) {
        Recurrence.none => null,
        Recurrence.daily => DateTimeComponents.time,
        Recurrence.weekly => DateTimeComponents.dayOfWeekAndTime,
      },
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}
