import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification plugin
  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    // Android Settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Settings (Darwin)
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked: ${response.payload}");
        // Handle navigation if needed
      },
    );

    _isInitialized = true;
    _requestPermissions();
  }

  /// Request Notification Permissions (Android 13+)
  Future<void> _requestPermissions() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Update/Schedule notifications for a specific class slot
  /// [startTime]: Class start time (Today)
  /// [endTime]: Class end time (Today)
  Future<void> scheduleClassNotifications({
    required DateTime startTime,
    required DateTime endTime,
    required String className,
  }) async {
    if (!_isInitialized) await init();

    // 1. "Get Ready" Notification - 10 Minutes Before
    final getReadyTime = startTime.subtract(const Duration(minutes: 10));
    if (getReadyTime.isAfter(DateTime.now())) {
      await _scheduleNotification(
        id: 100 + startTime.hour, // Unique ID based on time
        title: "Upcoming Class: $className",
        body: "Your class starts in 10 minutes. Get ready for attendance!",
        scheduledTime: getReadyTime,
      );
    }

    // 2. "Take Attendance" Notification - Random Time During Class
    // Calculate random minute offset
    final durationMins = endTime.difference(startTime).inMinutes;
    if (durationMins > 0) {
      // Avoid very start or very end: pick between 5 mins after start and 5 mins before end
      final safeMins = max(0, durationMins - 10); 
      final randomOffset = Random().nextInt(safeMins + 1) + 5; 
      
      final randomAttendanceTime = startTime.add(Duration(minutes: randomOffset));
      
      if (randomAttendanceTime.isAfter(DateTime.now()) && 
          randomAttendanceTime.isBefore(endTime)) {
        
        await _scheduleNotification(
          id: 200 + startTime.hour,
          title: "Attendance Required",
          body: "Please verify your attendance now for $className!",
          scheduledTime: randomAttendanceTime,
        );
        
        debugPrint("Scheduled Random Attendance at: $randomAttendanceTime");
      }
    }
  }

  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'class_alerts_channel',
            'Class Alerts',
            channelDescription: 'Notifications for class schedule and attendance',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("Scheduled '$title' for $scheduledTime");
    } catch (e) {
      debugPrint("Error scheduling notification: $e");
    }
  }

  /// Cancel all pending notifications
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
