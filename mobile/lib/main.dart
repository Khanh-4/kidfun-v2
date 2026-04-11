import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/storage/secure_storage.dart';
import 'core/services/app_lifecycle_service.dart';
import 'core/services/native_service.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[FCM] Received background message: ${message.messageId}');

  final type = message.data['type'];

  // Handle blocked apps update from parent — works even when Flutter is in background
  if (type == 'blocked_apps_update') {
    final packageNamesJson = message.data['packageNames'];
    if (packageNamesJson != null) {
      try {
        final List<dynamic> packages = jsonDecode(packageNamesJson);
        final packageNames = packages.cast<String>();
        await NativeService.setBlockedApps(packageNames);
        await NativeService.checkAndBlockCurrentApp();
        print('[FCM] 🚫 Updated blocked apps in background: ${packageNames.length} packages');
      } catch (e) {
        print('[FCM] ❌ Failed to update blocked apps: $e');
      }
    }
  }

  // TC-21: data-only SOS message — show local notification since Android won't auto-show
  if (type == 'SOS_ALERT') {
    await NotificationService.instance.init();
    final profileName = message.data['profileName'] ?? 'Bé';
    await NotificationService.instance.showSOSNotification(
      profileName: profileName,
      payload: 'SOS_ALERT',
    );
  }

  // TC-09/10: data-only Geofence message — show local notification
  if (type == 'GEOFENCE_EVENT') {
    await NotificationService.instance.init();
    final profileName = message.data['profileName'] ?? 'Bé';
    final geofenceName = message.data['geofenceName'] ?? 'Khu vực';
    final isEnter = message.data['eventType'] == 'ENTER';
    await NotificationService.instance.showGeofenceNotification(
      profileName: profileName,
      geofenceName: geofenceName,
      isEnter: isEnter,
    );
  }
}

void safelyNavigate(String location, Object? extra) {
  void tryPush(int attempts) {
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      try {
        final currentPath = GoRouter.of(ctx).routerDelegate.currentConfiguration.uri.path;
        // Do not push yet if we are still on the splash loader
        if (currentPath == '/splash') {
          print('[FCM] ⏳ Still on splash, waiting...');
        } else {
          ctx.push(location, extra: extra);
          return;
        }
      } catch (e) {
        print('[FCM] ⚠️ Navigation failed, retrying... $e');
      }
    }
    
    if (attempts > 0) {
      Future.delayed(const Duration(milliseconds: 300), () => tryPush(attempts - 1));
    } else {
      print('[FCM] ❌ Cannot navigate, context not available or timeout after retries');
    }
  }
  tryPush(25); // Try for up to 7.5 seconds
}

/// TC-13 B5 + TC-21 B4: Navigate to /sos-alert screen from an FCM RemoteMessage.
/// Used by onMessageOpenedApp (background) and getInitialMessage (killed) handlers.
void navigateToSOSFromFCM(RemoteMessage message) {
  final type = message.data['type'];
  if (type != 'SOS_ALERT') return;

  final lat = double.tryParse(message.data['latitude'] ?? '') ?? 0.0;
  final lng = double.tryParse(message.data['longitude'] ?? '') ?? 0.0;
  // TC-14: Use timestamp from FCM payload if present, otherwise approximate with now()
  final sosTime = message.data['timestamp'] ?? message.sentTime?.toIso8601String() ?? DateTime.now().toIso8601String();

  print('[FCM] 🆘 Navigating to SOS alert screen. lat=$lat, lng=$lng, time=$sosTime');

  safelyNavigate('/sos-alert', {
    'profileName': 'Bé', // FCM payload doesn't carry profileName — show generic label
    'latitude': lat,
    'longitude': lng,
    'audioUrl': message.data['audioUrl'],
    'phone': null,
    'sosTime': sosTime, // TC-14: show timestamp on SOS alert screen
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables for Mapbox token
  await dotenv.load(fileName: ".env");
  
  // Mapbox access token
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_PUBLIC_TOKEN'] ?? '');
  
  // Initialize Lifecycle observer
  AppLifecycleService.instance.init();

   //=== Firebase Setup ===
   //Uncomment khi đã có google-services.json trong mobile/android/app/
  
   await Firebase.initializeApp();
   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
   await FirebaseMessaging.instance.requestPermission(
     alert: true,
     badge: true,
     sound: true,
   );
   final fcmToken = await FirebaseMessaging.instance.getToken();
   if (fcmToken != null) {
     // Lưu tạm vào storage — sẽ được gửi lên server sau khi auth thành công
     await SecureStorage.saveFcmToken(fcmToken);
     print('[FCM] Device token: $fcmToken');
   }

   // Tự động cập nhật khi Firebase xoay vòng token (tránh stale tokens trên server)
   FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
     await SecureStorage.saveFcmToken(newToken);
     print('[FCM] Token refreshed, saved to storage: $newToken');
   });

   // === Init local notifications (foreground + data-only background) ===
   // Passed onNotificationTap directly to init() to handle cold-start taps
   await NotificationService.instance.init(
     onNotificationTap: (payload) {
       if (payload == null) return;
       
       if (payload == 'SOS_ALERT') {
         // Navigate to SOS alert with minimal data — full data loaded via REST
         safelyNavigate('/sos-alert', {
           'profileName': 'Bé',
           'latitude': 0.0,
           'longitude': 0.0,
           'audioUrl': null,
           'phone': null,
           'sosTime': DateTime.now().toIso8601String(),
         });
       }

       if (payload == 'TIME_EXTENSION') {
          safelyNavigate('/home', null);
       }
     }
   );

   // === Handle foreground notifications ===
   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     print('[FCM] Received foreground message: ${message.notification?.title}');
     
     final type = message.data['type'];

     // Blocked apps update
     if (type == 'blocked_apps_update') {
       final packageNamesJson = message.data['packageNames'];
       if (packageNamesJson != null) {
         try {
           final List<dynamic> packages = jsonDecode(packageNamesJson);
           final packageNames = packages.cast<String>();
           NativeService.setBlockedApps(packageNames);
           NativeService.checkAndBlockCurrentApp();
           print('[FCM] 🚫 Updated blocked apps in foreground: ${packageNames.length} packages');
         } catch (e) {
           print('[FCM] ❌ Failed to update blocked apps: $e');
         }
       }
     }

     // TC-21: SOS foreground — Android suppresses FCM notification when app is open,
     // so we must manually show a local notification to alert the parent.
     if (type == 'SOS_ALERT') {
       final profileName = message.data['profileName'] ?? message.notification?.title ?? 'Bé';
       NotificationService.instance.showSOSNotification(
         profileName: profileName,
         payload: 'SOS_ALERT',
       );
     }

     // TC-09/10: Geofence foreground notification
     if (type == 'GEOFENCE_EVENT') {
       final profileName = message.data['profileName'] ?? 'Bé';
       final geofenceName = message.data['geofenceName'] ?? 'Khu vực';
       final isEnter = message.data['eventType'] == 'ENTER';
       NotificationService.instance.showGeofenceNotification(
         profileName: profileName,
         geofenceName: geofenceName,
         isEnter: isEnter,
         payload: 'GEOFENCE_EVENT',
       );
     }

      // Time Extension foreground
      if (type == 'time_extension') {
        final title = message.notification?.title ?? 'Xin thêm thời gian';
        final body = message.notification?.body ?? 'Trẻ vừa gửi yêu cầu xin thêm thời gian sử dụng';
        NotificationService.instance.showTimeExtensionNotification(
          title: title,
          body: body,
          payload: 'TIME_EXTENSION',
        );
      }
   });

   // === TC-13 B5 + TC-21 B4: Handle notification tap when app is in background ===
   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     print('[FCM] 🔔 Opened from background notification: ${message.data}');
     navigateToSOSFromFCM(message);
   });

   // === Handle notification tap when app was killed (cold start) ===
   final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
   if (initialMessage != null) {
     print('[FCM] 🔔 Cold start via notification: ${initialMessage.data}');
     navigateToSOSFromFCM(initialMessage);
   }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
