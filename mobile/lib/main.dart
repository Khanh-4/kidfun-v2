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
import 'app.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('[FCM] Received background message: ${message.messageId}');
  
  // Handle blocked apps update from parent — works even when Flutter is in background
  final type = message.data['type'];
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
}

/// TC-13 B5 + TC-21 B4: Navigate to /sos-alert screen from an FCM RemoteMessage.
/// Used by onMessageOpenedApp (background) and getInitialMessage (killed) handlers.
void _navigateToSOSFromFCM(RemoteMessage message) {
  final type = message.data['type'];
  if (type != 'SOS_ALERT') return;

  final lat = double.tryParse(message.data['latitude'] ?? '') ?? 0.0;
  final lng = double.tryParse(message.data['longitude'] ?? '') ?? 0.0;

  print('[FCM] 🆘 Navigating to SOS alert screen. lat=$lat, lng=$lng');

  final ctx = navigatorKey.currentContext;
  if (ctx == null) {
    print('[FCM] ⚠️ navigatorKey context not ready, skipping navigation');
    return;
  }

  ctx.push('/sos-alert', extra: {
    'profileName': 'Bé', // FCM payload doesn't carry profileName — show generic label
    'latitude': lat,
    'longitude': lng,
    'audioUrl': null,
    'phone': null,
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

   // === Handle foreground notifications ===
   FirebaseMessaging.onMessage.listen((RemoteMessage message) {
     print('[FCM] Received foreground message: ${message.notification?.title}');
     
     // Handle blocked apps update in foreground too
     final type = message.data['type'];
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
   });

   // === TC-13 B5 + TC-21 B4: Handle notification tap when app is in background ===
   FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
     print('[FCM] 🔔 Opened from background notification: ${message.data}');
     _navigateToSOSFromFCM(message);
   });

   // === Handle notification tap when app was killed (cold start) ===
   final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
   if (initialMessage != null) {
     print('[FCM] 🔔 Cold start via notification: ${initialMessage.data}');
     // Delay to allow GoRouter to fully initialize before navigating
     Future.delayed(const Duration(milliseconds: 1200), () {
       _navigateToSOSFromFCM(initialMessage);
     });
   }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
