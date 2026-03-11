import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase (Uncomment when google-services.json is added)
  // await Firebase.initializeApp();
  // await FirebaseMessaging.instance.requestPermission();
  // final fcmToken = await FirebaseMessaging.instance.getToken();
  // print('FCM Token: $fcmToken');

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
