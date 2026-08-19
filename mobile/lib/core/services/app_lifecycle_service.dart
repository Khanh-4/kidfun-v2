import 'package:flutter/material.dart';
import '../network/socket_service.dart';
import 'location_service.dart';

class AppLifecycleService extends WidgetsBindingObserver {
  static AppLifecycleService? _instance;

  static AppLifecycleService get instance {
    _instance ??= AppLifecycleService._();
    return _instance!;
  }

  AppLifecycleService._();

  void init() {
    print('📱 [Lifecycle] Initializing AppLifecycleService');
    WidgetsBinding.instance.addObserver(this);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('📱 [Lifecycle] App State: $state');
    
    final isForeground = state == AppLifecycleState.resumed;
    LocationService.instance.setForeground(isForeground);

    switch (state) {
      case AppLifecycleState.paused:
        // App goes to background
        SocketService.instance.onAppPaused();
        break;
      case AppLifecycleState.resumed:
        // App comes back to foreground
        SocketService.instance.onAppResumed();
        break;
      case AppLifecycleState.detached:
        // App is killed
        SocketService.instance.disconnect();
        break;
      default:
        break;
    }
  }
}
