import 'dart:async';
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

  /// Whether the system repeats daily and weekly notifications by itself.
  /// Where it cannot, the planner books the next few instead.
  bool get repeatsNatively;
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

  @override
  bool get repeatsNatively => true;
}

/// Shows notifications from timers inside the running app. Used on Linux,
/// where the system has no way to schedule them: reminders there fire only
/// while Mapex is open.
class InAppAlerts {
  InAppAlerts({required this.show, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final Future<void> Function(PlannedAlert alert, bool sound) show;
  final DateTime Function() _clock;

  /// Runs after each notification is shown, so repeats can be topped up.
  void Function()? onFired;

  final _booked = <int, ({PlannedAlert alert, Timer timer})>{};

  List<({int id, AlertPayload? payload})> pending() => [
    for (final b in _booked.values) (id: b.alert.id, payload: b.alert.payload),
  ];

  void schedule(PlannedAlert alert, {required bool sound}) {
    cancel(alert.id);
    final wait = alert.at.difference(_clock());
    if (wait.isNegative) return;
    final timer = Timer(wait, () async {
      _booked.remove(alert.id);
      await show(alert, sound);
      onFired?.call();
    });
    _booked[alert.id] = (alert: alert, timer: timer);
  }

  void cancel(int id) => _booked.remove(id)?.timer.cancel();
}

/// Real notifications via flutter_local_notifications. Works when the app is
/// closed on Android (alarms), macOS (UNUserNotificationCenter) and Windows
/// (scheduled toasts). On Linux they come from [InAppAlerts].
class LocalAlertPlatform implements AlertPlatform {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _exact = false;

  /// Only on Linux.
  late final InAppAlerts? inApp = Platform.isLinux
      ? InAppAlerts(show: _showNow)
      : null;

  /// Identifies the app to Windows' notification centre. Fixed for good:
  /// changing it orphans notifications already booked.
  static const _windowsGuid = '6f0c3b2e-8f4a-4d6b-9a51-2c7e3d9b1a40';

  @override
  bool get repeatsNatively => !Platform.isWindows && !Platform.isLinux;

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
        linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        windows: WindowsInitializationSettings(
          appName: 'Mapex',
          appUserModelId: 'com.apeaxis.mapex',
          guid: _windowsGuid,
        ),
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
    // Not available there; a tap while the app runs still works.
    if (Platform.isLinux) return null;
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
    if (Platform.isLinux || Platform.isWindows) return true;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<List<({int id, AlertPayload? payload})>> pending() async {
    if (inApp case final timers?) return timers.pending();
    final list = await _plugin.pendingNotificationRequests();
    return [
      for (final r in list) (id: r.id, payload: AlertPayload.decode(r.payload)),
    ];
  }

  @override
  Future<void> schedule(PlannedAlert alert, {required bool sound}) async {
    if (inApp case final timers?) {
      return timers.schedule(alert, sound: sound);
    }
    return _plugin.zonedSchedule(
      id: alert.id,
      scheduledDate: tz.TZDateTime.from(alert.at, tz.local),
      title: alert.title,
      body: alert.body,
      payload: alert.payload.encode(),
      notificationDetails: _details(sound),
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

  Future<void> _showNow(PlannedAlert alert, bool sound) => _plugin.show(
    id: alert.id,
    title: alert.title,
    body: alert.body,
    payload: alert.payload.encode(),
    notificationDetails: _details(sound),
  );

  NotificationDetails _details(bool sound) {
    final channel = sound ? _channelSound : _channelQuiet;
    return NotificationDetails(
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
      linux: LinuxNotificationDetails(suppressSound: !sound),
      windows: WindowsNotificationDetails(
        audio: sound ? null : WindowsNotificationAudio.silent(),
      ),
    );
  }

  @override
  Future<void> cancel(int id) async {
    if (inApp case final timers?) return timers.cancel(id);
    await _plugin.cancel(id: id);
  }
}
