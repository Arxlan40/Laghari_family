import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}
  print('''

=======================================================
[FCM BACKGROUND NOTIFICATION RECEIVED]:
Title: ${message.notification?.title ?? message.data['title']}
Body:  ${message.notification?.body ?? message.data['body']}
Data:  ${message.data}
=======================================================

''');

  // If this is a data payload without a notification payload, show local notification
  final title = message.notification?.title ?? message.data['title'];
  final body = message.notification?.body ?? message.data['body'];
  if (message.notification == null && title != null) {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important family updates and notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      final androidPlugin = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(channel);
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      );
      await plugin.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title: title.toString(),
        body: (body ?? '').toString(),
        notificationDetails: details,
        payload: message.data.toString(),
      );
    } catch (e) {
      print('[FCM BG NOTIFICATION ERROR]: $e');
    }
  }
}

class FcmService {
  static String? currentToken;

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important family tree updates and notifications.',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void _printTokenBanner(String token) {
    print('''

================================================================================
🔥🔥🔥 [FCM DEVICE TOKEN FOR TESTING NOTIFICATIONS] 🔥🔥🔥
$token
================================================================================
👉 Copy the above token and test in Firebase Console -> Cloud Messaging!
================================================================================

''');
  }

  static Future<void> initialize({Function(String token)? onTokenReceived}) async {
    // FCM push notification integration is strictly for Android only per requirements
    if (!isAndroid) {
      debugPrint('FCM push notifications skipped: not running on Android platform.');
      return;
    }

    try {
      // 1. Initialize local notifications and create Android Notification Channel
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Request notification permissions explicitly on Android 13+
      await androidPlugin?.requestNotificationsPermission();

      // Create the High Importance Notification Channel on the Android OS
      await androidPlugin?.createNotificationChannel(channel);

      const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInitSettings);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          print('[LOCAL NOTIFICATION TAPPED]: ${response.payload}');
        },
      );

      print('[LOCAL NOTIFICATIONS]: Channel & Plugin initialized successfully.');

      // 2. Initialize Firebase Messaging
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('[FCM PERMISSION STATUS]: ${settings.authorizationStatus}');

      // Configure foreground presentation options
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 3. Set background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 4. Retrieve device registration token
      try {
        final token = await messaging.getToken();
        if (token != null && token.isNotEmpty) {
          currentToken = token;
          _printTokenBanner(token);
          onTokenReceived?.call(token);
        } else {
          print('\n[FCM WARNING]: messaging.getToken() returned null or empty.\n');
        }
      } catch (tokenError) {
        print('\n[FCM TOKEN ERROR]: Could not retrieve token: $tokenError\n');
      }

      // 5. Listen for token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        currentToken = newToken;
        print('\n[FCM TOKEN REFRESHED]:\n$newToken\n');
        _printTokenBanner(newToken);
        onTokenReceived?.call(newToken);
      });

      // 6. Handle foreground notification messages & show native Android notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? message.data['title'] ?? 'Laghari Family Notification';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        print('''

=======================================================
[FCM FOREGROUND NOTIFICATION RECEIVED]:
Title: $title
Body:  $body
Data:  ${message.data}
=======================================================

''');

        // On Android, FCM does NOT show a heads-up banner in the foreground by default.
        // We must display it via FlutterLocalNotificationsPlugin!
        showLocalNotification(
          title: title,
          body: body,
          payload: message.data.toString(),
        );
      });

      // 7. Handle notification click when opening app
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('[FCM NOTIFICATION OPENED APP]: ${message.data}');
      });
    } catch (e) {
      print('[FCM INITIALIZATION ERROR]: $e');
    }
  }

  /// Displays an instant native Android system notification with heads-up banner and sound
  static Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!isAndroid) return;
    try {
      final androidDetails = AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
      );
      final details = NotificationDetails(android: androidDetails);
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
      await _localNotifications.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );
      print('[LOCAL NOTIFICATION DISPLAYED]: "$title" - "$body"');
    } catch (e) {
      print('[LOCAL NOTIFICATION ERROR]: $e');
    }
  }

  /// Manually retrieves or forces refresh of device FCM token
  static Future<String?> getOrRefreshToken() async {
    if (!isAndroid) return null;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        currentToken = token;
        _printTokenBanner(token);
      }
      return token;
    } catch (e) {
      print('[FCM REFRESH ERROR]: $e');
      return null;
    }
  }
}
