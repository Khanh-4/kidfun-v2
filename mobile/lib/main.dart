import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
// Uncomment khi đã thêm google-services.json
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // === Firebase Setup ===
  // Uncomment khi đã có google-services.json trong mobile/android/app/
  //
  // await Firebase.initializeApp();
  // await FirebaseMessaging.instance.requestPermission(
  //   alert: true,
  //   badge: true,
  //   sound: true,
  // );
  // final fcmToken = await FirebaseMessaging.instance.getToken();
  // if (fcmToken != null) {
  //   // Lưu tạm vào storage — sẽ được gửi lên server sau khi auth thành công
  //   await SecureStorage.saveFcmToken(fcmToken);
  //   print('[FCM] Device token: $fcmToken');
  // }
  // === Handle foreground notifications ===
  // FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  //   print('[FCM] Received foreground message: ${message.notification?.title}');
  // });

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
