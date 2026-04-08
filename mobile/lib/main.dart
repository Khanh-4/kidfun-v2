import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:convert';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Mapbox access token
  MapboxOptions.setAccessToken(const String.fromEnvironment('MAPBOX_PUBLIC_TOKEN', defaultValue: 'pk.xxxxxxxxxxxxx'));
  
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

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
