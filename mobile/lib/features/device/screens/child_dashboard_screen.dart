import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/role_provider.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/native_service.dart';
import '../../../core/services/policy_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/youtube_service.dart';
import '../../location/data/location_repository.dart';
import '../data/child_repository.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'child_locked_widget.dart';

class ChildDashboardScreen extends ConsumerStatefulWidget {
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _isLoading = true;
  bool _hasToken = false;
  bool _isSocketConnected = false;
  String? _deviceCode;
  Timer? _connectionCheckTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Task 2: Countdown & Session
  final _childRepo = ChildRepository();
  final _locationRepo = LocationRepository(DioClient.instance);
  int _remainingSeconds = 0;
  bool _isLimitEnabled = true;
  int _currentTotalLimitMinutes = 0; // Tracks baseLimit + extension minutes
  DateTime? _endTime; // BUG 2 FIX: anchor for drift-free countdown
  int? _pausedRemainingSeconds; // NEW
  int? _sessionId;
  Timer? _countdownTimer;
  Timer? _heartbeatTimer;
  bool _hasShown30m = false;
  bool _hasShown15m = false;
  bool _hasShown5m = false;
  bool _isTimeUpDialogShowing = false;
  bool _waitingForResponse = false;
  Timer? _usageSyncTimer;
  Timer? _screenPollTimer;
  bool _isScreenPaused = false; // true when screen is off and timer paused

  // SOS Task 7
  bool _isSOSing = false;
  int _sosCountdown = 15;
  Timer? _sosTimer;
  final _audioRecorder = AudioRecorder();

  @override
  void initState() {
    super.initState();

    // Pulse animation for the connection indicator
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addObserver(this);

    _initializeDashboard();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      print('📦 App paused/inactive: cancelling timer to prevent catch-up glitch');
      _countdownTimer?.cancel();
      // Sprint 5 fix: khi chạy ngầm, native service chịu trách nhiệm khoá màn hình
      if (_isLimitEnabled && _endTime != null && _endTime!.isAfter(DateTime.now())) {
        NativeService.scheduleLockAt(_endTime!).catchError(
          (e) => print('❌ [LOCK] scheduleLockAt error: $e'),
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      print('📦 App resumed: recalculating drift natively');
      // Huỷ lịch khoá native — Flutter timer tiếp quản
      NativeService.cancelScheduledLock().catchError(
        (e) => print('❌ [LOCK] cancelScheduledLock error: $e'),
      );
      // Re-check permissions after user returns from Settings
      if (!_isTimeUpDialogShowing) _checkAndRequestPermissions();
      if (!_isLimitEnabled) return;
      // If screen is paused, don't resume countdown — wait for _resumeFromScreenOn
      if (_isScreenPaused) return;
      if (_isLimitEnabled && _endTime != null) {
        // BUG 8 FIX: precise millisecond rounding to avoid fraction truncation lag
        final secs = (_endTime!.difference(DateTime.now()).inMilliseconds / 1000).round();
        setState(() {
          _remainingSeconds = secs > 0 ? secs : 0;
        });
        if (_remainingSeconds > 0) {
          _startCountdown();
        } else if (!_isTimeUpDialogShowing) {
          _onTimeUp();
        }
      }
    }
  }

  Future<void> _initializeDashboard() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('device_token');
    final deviceCode = prefs.getString('device_code');

    if (!mounted) return;

    if (token == null || token.isEmpty) {
      setState(() {
        _hasToken = false;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _hasToken = true;
      _deviceCode = deviceCode;
      _isLoading = false;
    });

    // Connect Socket.IO (idempotent — won't duplicate if already connected)
    if (deviceCode != null && deviceCode.isNotEmpty) {
      SocketService.instance.joinDevice(deviceCode);
      print('📡 Child Dashboard: called joinDevice for code $deviceCode');
    }

    // Poll socket connection status every 3 seconds
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        setState(() {
          _isSocketConnected = SocketService.instance.isConnected;
        });
      }
    });

    // Initial check
    setState(() => _isSocketConnected = SocketService.instance.isConnected);

    // Sprint 5: Start foreground service for 24/7 monitoring
    NativeService.startForegroundService();

    // Sprint 5: Prompt user to grant required permissions
    await _checkAndRequestPermissions();

    // Sprint 5: Sync all installed apps once on startup (for parent's app-blocking screen)
    _syncInstalledApps();

    // Sprint 5: Sync app usage every 5 minutes
    _startUsageSync();

    // Sprint 5: Sync blocked apps from server
    _syncBlockedApps();

    // Sprint 8: Sync all policies (web filtering, per-app limits, school mode)
    if (_deviceCode != null) {
      PolicyService.instance.syncAll(_deviceCode!);
    }

    // Sprint 9: Start YouTube tracking service
    if (_deviceCode != null) {
      YouTubeService.instance.start(_deviceCode!);
    }

    // NOTE: Screen state polling moved to _initSession() — it must start AFTER
    // session is established, otherwise resume/pause API calls will 404.

    // Sprint 4: Task 2 - Session & Countdown
    _initSession();
    _setupSocketListeners();
    
    // Task 3: Start location tracking
    _startLocationTracking();
  }

  void _startLocationTracking() {
    if (_deviceCode == null) return;
    
    LocationService.instance.start(onUpdate: (position) async {
      try {
        await _locationRepo.syncLocation(
          deviceCode: _deviceCode!,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        );
        print('✅ [LOCATION SYNC] Sent to server');
      } catch (e) {
        print('❌ [LOCATION SYNC] Error: $e');
      }
    });
  }

  Future<void> _initSession() async {
    if (_deviceCode == null) return;

    try {
      // 1. Get remaining time
      final todayLimit = await _childRepo.getTodayLimit(_deviceCode!);
      print('📊 [DEBUG] _initSession: limitMinutes=${todayLimit.limitMinutes}, remainingMinutes=${todayLimit.remainingMinutes}, remainingSeconds=${todayLimit.remainingSeconds}');

      _currentTotalLimitMinutes = todayLimit.limitMinutes;

      if (mounted) {
        final serverSeconds = todayLimit.remainingSeconds;
        final serverEndTime = DateTime.now().add(Duration(seconds: serverSeconds));

        // Restore saved endTime for second-level accuracy after force-close.
        // Backend closes UsageLogs at device.lastSeen (~60s heartbeat granularity).
        // savedEndTime gives the exact wall-clock anchor from the previous session.
        final prefs = await SharedPreferences.getInstance();
        final savedEpoch = prefs.getInt('end_time_epoch_ms_$_deviceCode');
        final savedEndTime = savedEpoch != null
            ? DateTime.fromMillisecondsSinceEpoch(savedEpoch)
            : null;

        // Prefer whichever end time gives the child MORE time remaining:
        // - Socket extension applied → savedEndTime > serverEndTime → keep saved
        // - Parent reduced limit → serverEndTime < savedEndTime → keep server (min of two)
        // - Parent increased limit → serverEndTime > savedEndTime → keep server (max)
        // Rule: always take the later of the two when savedEndTime is still in the future.
        // This avoids the old 120s threshold which broke socket-applied extensions.
        DateTime chosenEndTime;
        if (savedEndTime != null && savedEndTime.isAfter(DateTime.now())) {
          chosenEndTime = savedEndTime.isAfter(serverEndTime) ? savedEndTime : serverEndTime;
        } else {
          chosenEndTime = serverEndTime;
        }

        setState(() {
          _isLimitEnabled = todayLimit.isLimitEnabled;
          _endTime = chosenEndTime;
          _remainingSeconds = chosenEndTime.difference(DateTime.now()).inSeconds.clamp(0, serverSeconds + 120).toInt();

          // BUG 1.2 FIX: Initialize guard flags based on current time to prevent 
          // redundant warnings if starting/resuming when already below milestones.
          _hasShown30m = _remainingSeconds <= 30 * 60;
          _hasShown15m = _remainingSeconds <= 15 * 60;
          _hasShown5m = _remainingSeconds <= 5 * 60;
        });

        // Persist chosen endTime for the next restart
        await prefs.setInt('end_time_epoch_ms_$_deviceCode', chosenEndTime.millisecondsSinceEpoch);
      }

      // 2. Check if native service was in locked state (e.g. after reboot)
      final wasLocked = await NativeService.isInLockedState();

      // 3. Start session
      final sid = await _childRepo.startSession(_deviceCode!);
      _sessionId = sid;

      // 4. Start countdown or trigger time up immediately
      if (wasLocked && !_isTimeUpDialogShowing) {
         // Device was locked before reboot — resume locked state immediately
         print('🔒 [BOOT] Restoring locked state from native service');
         _onTimeUp();
      } else if (!_isLimitEnabled) {
         if (_isTimeUpDialogShowing) {
            setState(() => _isTimeUpDialogShowing = false);
         }
      } else if (_remainingSeconds <= 0 || (_isLimitEnabled && _currentTotalLimitMinutes == 0)) {
         if (!_isTimeUpDialogShowing) {
            _onTimeUp();
         }
      } else {
         _startCountdown();
      }

      // 4. Heartbeat every 60s
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
        if (_sessionId != null) {
          try {
            final result = await _childRepo.heartbeat(
              sessionId: _sessionId!,
              deviceCode: _deviceCode!,
            );
            if (mounted) {
              print('💓 [HEARTBEAT] ping successful. server=${result.remainingSeconds}s');

              // Sync countdown nếu lệch > 10s so với server (tránh drift dài hạn)
              if (_isLimitEnabled && _endTime != null) {
                final localRemaining = (_endTime!.difference(DateTime.now()).inMilliseconds / 1000).round();
                final diff = (result.remainingSeconds - localRemaining).abs();
                if (diff > 10) {
                  print('⚠️ [HEARTBEAT] Drift ${diff}s detected, syncing from server');
                  setState(() {
                    _remainingSeconds = result.remainingSeconds;
                    _endTime = DateTime.now().add(Duration(seconds: result.remainingSeconds));
                  });
                  _saveEndTime();
                }
              }

              // If server says blocked, trigger time up
              if (result.isBlocked && !_isTimeUpDialogShowing) {
                _onTimeUp();
              }
            }
          } catch (e) {
            print('❌ Heartbeat error: $e');
          }
        }
      });

      // Sprint 6: Start screen state polling AFTER session is established
      // This prevents resume/pause API calls from 404-ing due to no active session
      _startScreenStatePoll();
    } catch (e) {
      print('❌ Init session error: $e');
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    if (!mounted) return;

    final hasUsage = await NativeService.hasUsageStatsPermission();
    if (!hasUsage && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.bar_chart, color: Color(0xFF6366f1)),
              const SizedBox(width: 8),
              Flexible(child: Text('Cần quyền theo dõi app', style: GoogleFonts.nunito(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(
            'KidFun cần quyền "Đọc dữ liệu sử dụng ứng dụng" để phụ huynh có thể xem và quản lý các app con đang dùng.',
            style: GoogleFonts.nunito(fontSize: 15),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                NativeService.requestUsageStatsPermission();
              },
              icon: const Icon(Icons.settings),
              label: Text('Mở Cài đặt', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return; // Chờ user cấp quyền, sẽ re-check khi resume
    }

    final hasAccessibility = await NativeService.isAccessibilityEnabled();
    if (!hasAccessibility && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.accessibility, color: Color(0xFF6366f1)),
              const SizedBox(width: 8),
              Flexible(child: Text('Cần quyền Accessibility', style: GoogleFonts.nunito(fontWeight: FontWeight.bold))),
            ],
          ),
          content: Text(
            'KidFun cần quyền Accessibility để có thể chặn các ứng dụng khi phụ huynh yêu cầu.',
            style: GoogleFonts.nunito(fontSize: 15),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                NativeService.requestAccessibilityPermission();
              },
              icon: const Icon(Icons.settings),
              label: Text('Mở Cài đặt', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      return; // Re-check sẽ được gọi khi app resume sau khi user bật trong Settings
    }

    // Android 13+: request POST_NOTIFICATIONS permission tại runtime
    // Nếu không có permission này, tất cả notification từ BlockNotificationHelper sẽ silently fail
    final notifStatus = await Permission.notification.status;
    if (notifStatus.isDenied) {
      await Permission.notification.request();
    }

    // Ask for location permission
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
       print('Location service disabled');
    } else {
       LocationPermission permission = await Geolocator.checkPermission();
       if (permission == LocationPermission.denied && mounted) {
         await showDialog(
           context: context,
           barrierDismissible: false,
           builder: (ctx) => AlertDialog(
             title: Row(
               children: [
                 const Icon(Icons.location_on, color: Color(0xFF6366f1)),
                 const SizedBox(width: 8),
                 Flexible(child: Text('Cần quyền Vị trí', style: GoogleFonts.nunito(fontWeight: FontWeight.bold))),
               ],
             ),
             content: Text(
               'KidFun cần quyền Vị trí để gửi vị trí hiện tại cho phụ huynh, giúp phụ huynh biết trẻ đang ở đâu.',
               style: GoogleFonts.nunito(fontSize: 15),
             ),
             actions: [
               ElevatedButton.icon(
                 onPressed: () async {
                   Navigator.pop(ctx);
                   await Geolocator.requestPermission();
                   if (Platform.isAndroid) {
                     final status = await Permission.locationAlways.request();
                     if (status.isGranted) {
                       print('✅ Background location granted');
                     }
                   }
                   _startLocationTracking();
                 },
                 icon: const Icon(Icons.check),
                 label: Text('Cấp quyền', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
               ),
             ],
           ),
         );
       }
    }
  }

  Future<void> _syncInstalledApps() async {
    if (_deviceCode == null) return;
    try {
      final apps = await NativeService.getInstalledApps();
      if (apps.isNotEmpty) {
        await _childRepo.syncAppUsage(_deviceCode!, apps);
        print('📱 [INSTALLED] Synced ${apps.length} installed apps to server');
      }
    } catch (e) {
      print('❌ [INSTALLED] Sync error: $e');
    }
  }

  void _startUsageSync() {
    _usageSyncTimer?.cancel();
    _usageSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      if (_deviceCode == null) return;
      try {
        final hasPermission = await NativeService.hasUsageStatsPermission();
        if (!hasPermission) return;
        final usage = await NativeService.getAppUsage();
        if (usage.isNotEmpty) {
          await _childRepo.syncAppUsage(_deviceCode!, usage);
          print('📊 [USAGE] Synced ${usage.length} apps to server');
        }
      } catch (e) {
        print('❌ [USAGE] Sync error: $e');
      }
    });
  }

  Future<void> _syncBlockedApps() async {
    if (_deviceCode == null) return;
    try {
      final blockedApps = await _childRepo.getBlockedApps(_deviceCode!);
      final packages = blockedApps.map((a) => a.packageName).toList();
      await NativeService.setBlockedApps(packages);
      // Force-check: nếu app hiện tại đang bị chặn → đẩy về Home ngay
      await NativeService.checkAndBlockCurrentApp();
      print('🚫 [BLOCKED] Synced ${packages.length} blocked apps');
    } catch (e) {
      print('❌ [BLOCKED] Sync error: $e');
    }
  }

  // ── Screen State Polling (Sprint 6: Pause/Resume timer on screen off/on) ────

  void _startScreenStatePoll() {
    _screenPollTimer?.cancel();
    _screenPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted || _deviceCode == null) return;
      if (_isTimeUpDialogShowing) return; // Don't poll during locked state

      try {
        final screenOn = await NativeService.isScreenOn();

        if (!screenOn && !_isScreenPaused) {
          // Screen just turned off — pause timer
          _pauseForScreenOff();
        } else if (screenOn && _isScreenPaused) {
          // Screen just turned on — resume timer
          await _resumeFromScreenOn();
        }
      } catch (e) {
        // Native call might fail if service not ready — silently ignore
        print('❌ [SCREEN] Poll error: $e');
      }
    });
  }

  void _pauseForScreenOff() {
    if (_isScreenPaused || !_isLimitEnabled) return;
    if (_sessionId == null) return; // Guard: no session yet, skip pause

    print('📱 [SCREEN OFF] Pausing timer and notifying backend');
    _isScreenPaused = true;
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();

    // Notify backend to close open usage logs (stops counting)
    if (_deviceCode != null) {
      _childRepo.pauseSession(_deviceCode!).then((remainingSeconds) {
        print('⏸️ [PAUSE] Backend confirmed pause. Server remaining: ${remainingSeconds}s');
      }).catchError((e) {
        print('❌ [PAUSE] Backend error: $e');
      });
    }
  }

  Future<void> _resumeFromScreenOn() async {
    if (!_isScreenPaused || !_isLimitEnabled) return;
    if (_sessionId == null) return; // Guard: no session yet, skip resume

    print('📱 [SCREEN ON] Resuming timer from backend');
    _isScreenPaused = false;

    if (_deviceCode == null) return;

    try {
      // Notify backend to create new usage log (resumes counting)
      final serverSeconds = await _childRepo.resumeSession(_deviceCode!);

      if (mounted) {
        // BUG #7 FIX: Server may return 0 seconds due to heartbeat gap while screen was off.
        // If _endTime is still in the future, trust it over the server response to
        // avoid a false lock-trigger when < 30 min remaining.
        final localSecsRemaining = _endTime != null
            ? (_endTime!.difference(DateTime.now()).inMilliseconds / 1000).round()
            : 0;
        final effectiveSeconds = (serverSeconds > 0)
            ? serverSeconds
            : (localSecsRemaining > 30 ? localSecsRemaining : serverSeconds);

        setState(() {
          _remainingSeconds = effectiveSeconds > 0 ? effectiveSeconds : 0;
          _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
        });
        _saveEndTime();

        if (_remainingSeconds > 0) {
          _startCountdown();
          // Restart heartbeat
          _heartbeatTimer?.cancel();
          _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
            if (_sessionId != null) {
              try {
                final result = await _childRepo.heartbeat(
                  sessionId: _sessionId!,
                  deviceCode: _deviceCode!,
                );
                if (mounted) {
                  if (_isLimitEnabled && _endTime != null) {
                    final localRemaining = (_endTime!.difference(DateTime.now()).inMilliseconds / 1000).round();
                    final diff = (result.remainingSeconds - localRemaining).abs();
                    if (diff > 10) {
                      setState(() {
                        _remainingSeconds = result.remainingSeconds;
                        _endTime = DateTime.now().add(Duration(seconds: result.remainingSeconds));
                      });
                      _saveEndTime();
                    }
                  }
                  if (result.isBlocked && !_isTimeUpDialogShowing) {
                    _onTimeUp();
                  }
                }
              } catch (e) {
                print('❌ Heartbeat error: $e');
              }
            }
          });
        } else if (!_isTimeUpDialogShowing) {
          _onTimeUp();
        }
      }
    } catch (e) {
      print('❌ [RESUME] Error: $e');
      // Fallback: just resume countdown from last known state
      if (mounted && _endTime != null) {
        final secs = (_endTime!.difference(DateTime.now()).inMilliseconds / 1000).round();
        setState(() => _remainingSeconds = secs > 0 ? secs : 0);
        if (_remainingSeconds > 0) _startCountdown();
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isLimitEnabled) {
        timer.cancel();
        return;
      }
      
      // This prevents 1-minute jumps caused by Timer.periodic jitter accumulation.
      final now = DateTime.now();
      int secs = _endTime != null
          ? (_endTime!.difference(now).inMilliseconds / 1000).round()
          : (_remainingSeconds - 1);
          
      if (secs < 0) secs = 0; // Prevent _remainingSeconds from ever going below 0

      if (secs > 0) {
        setState(() => _remainingSeconds = secs);
        _checkSoftWarning();
      } else {
        setState(() => _remainingSeconds = 0);
        timer.cancel();
        _countdownTimer?.cancel();
        _onTimeUp();
      }
    });
  }

  void _checkSoftWarning() {
    if (!_isLimitEnabled) return;

    // Trigger <= 30 minutes
    if (_remainingSeconds <= 30 * 60 && !_hasShown30m) {
      _hasShown30m = true;
      _showWarningDialog('SOFT_30', 'Còn 30 phút', 'Con còn 30 phút sử dụng thiết bị hôm nay.');
    }

    // Trigger <= 15 minutes
    if (_remainingSeconds <= 15 * 60 && !_hasShown15m) {
      _hasShown15m = true;
      _showWarningDialog('SOFT_15', 'Còn 15 phút', 'Con còn 15 phút. Hãy hoàn thành việc đang làm nhé!');
    }

    // Trigger <= 5 minutes
    if (_remainingSeconds <= 5 * 60 && !_hasShown5m) {
      _hasShown5m = true;
      _showWarningDialog('SOFT_5', 'Còn 5 phút!', 'Con còn 5 phút. Sắp hết giờ rồi!');
    }
  }

  void _showWarningDialog(String type, String title, String message) {
    // Ghi log warning lên server
    if (_deviceCode != null) {
      _childRepo.logWarning(
        deviceCode: _deviceCode!, 
        type: type, 
        remainingMinutes: _remainingSeconds ~/ 60,
      );
    }

    // Hiển thị dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.orange, size: 32),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: GoogleFonts.nunito(fontSize: 16)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Đã hiểu', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onTimeUp() {
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    if (_sessionId != null) {
      _childRepo.endSession(_sessionId!, _deviceCode ?? '');
      _sessionId = null;
    }

    // Log warning
    if (_deviceCode != null) {
      _childRepo.logWarning(deviceCode: _deviceCode!, type: 'TIME_UP', remainingMinutes: 0);
    }

    // Sprint 5: Lock screen bằng native DevicePolicyManager
    NativeService.lockScreen().catchError((e) {
      print('❌ [LOCK] lockScreen error: $e');
    });
    // Bật chế độ khoá liên tục: thiết bị tự khoá lại mỗi khi trẻ mở khoá
    NativeService.enterLockedState().catchError((e) {
      print('❌ [LOCK] enterLockedState error: $e');
    });

    // Hiện màn hình khóa fullscreen thay thế toàn bộ dashboard
    setState(() => _isTimeUpDialogShowing = true);
  }

  // Persist _endTime to SharedPreferences so it survives force-close.
  Future<void> _saveEndTime() async {
    if (_deviceCode == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (_endTime == null) {
      await prefs.remove('end_time_epoch_ms_$_deviceCode');
    } else {
      await prefs.setInt('end_time_epoch_ms_$_deviceCode', _endTime!.millisecondsSinceEpoch);
    }
  }

  Future<void> _fetchAndApplyNewLimit() async {
    if (_deviceCode == null) return;
    try {
      final nowLimit = await _childRepo.getTodayLimit(_deviceCode!);
      final newTotalLimitMinutes = nowLimit.limitMinutes;
      final newRemainingSeconds = nowLimit.remainingSeconds;
      final enabled = nowLimit.isLimitEnabled;
      
      final deltaMinutes = newTotalLimitMinutes - _currentTotalLimitMinutes;
      _currentTotalLimitMinutes = newTotalLimitMinutes;

      print('📊 [_fetchAndApplyNewLimit] limitDelta=$deltaMinutes newLimit=$newTotalLimitMinutes enabled=$enabled');

      if (mounted) {
        final wasUnlimited = !_isLimitEnabled || _endTime == null;

        setState(() {
          _isLimitEnabled = enabled;
          
          if (!enabled) {
            _pausedRemainingSeconds = _remainingSeconds;
            _countdownTimer?.cancel();
            _endTime = null;
            _remainingSeconds = newRemainingSeconds;
          } else {
            // Because the parent manually updated the limit, we should strictly trust 
            // the server's remainingSeconds instead of attempting a complex delta calculation 
            // which can cause the timer to get stuck at 0.
            _remainingSeconds = newRemainingSeconds;
            _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
            _pausedRemainingSeconds = null;
            
            if (_remainingSeconds > 30 * 60) _hasShown30m = false;
            if (_remainingSeconds > 15 * 60) _hasShown15m = false;
            if (_remainingSeconds > 5 * 60) _hasShown5m = false;
          }
        });

        // Persist updated endTime so the next restart picks up the correct anchor
        _saveEndTime();

        if ((!enabled || _remainingSeconds > 0) && _isTimeUpDialogShowing) {
          setState(() => _isTimeUpDialogShowing = false);
          // Tắt chế độ khoá liên tục vì phụ huynh đã cấp thêm thời gian
          NativeService.exitLockedState().catchError((e) {
            print('❌ [LOCK] exitLockedState error: $e');
          });
        }

        if (enabled) {
          if (_remainingSeconds > 0 && _currentTotalLimitMinutes > 0) {
            if (_countdownTimer == null || !_countdownTimer!.isActive) {
              _hasShown30m = false;
              _hasShown15m = false;
              _hasShown5m = false;
              _startCountdown();
            }
          } else if (!_isTimeUpDialogShowing) {
            _onTimeUp();
          }
        }
      }
    } catch (e) {
      print('❌ [_fetchAndApplyNewLimit] Error fetching new limit: $e');
    }
  }

  void _setupSocketListeners() {
    final socket = SocketService.instance.socket;

    // Always call off() before on() to ensure idempotent listener registration.
    // Without this, every _onAppResumed → _initializeDashboard → _setupSocketListeners cycle
    // stacks an additional listener, causing N dialogs per event after N resume cycles.

    socket.off('timeLimitUpdated');
    socket.on('timeLimitUpdated', (data) async {
      print('🔔 [SOCKET] timeLimitUpdated received. Applying delta to countdown.');
      await _fetchAndApplyNewLimit();
    });

    socket.off('blockedAppsUpdated');
    socket.on('blockedAppsUpdated', (data) async {
      print('🔔 [SOCKET] blockedAppsUpdated received — re-syncing blocked apps');
      await _syncBlockedApps();
    });

    // Sprint 8: Web filtering, per-app limits, school mode real-time sync
    socket.off('blockedDomainsUpdated');
    socket.on('blockedDomainsUpdated', (data) async {
      print('🔔 [SOCKET] blockedDomainsUpdated — syncing policies');
      if (_deviceCode != null) await PolicyService.instance.syncAll(_deviceCode!);
    });

    socket.off('blockedVideosUpdated');
    socket.on('blockedVideosUpdated', (_) {
      print('🔔 [SOCKET] blockedVideosUpdated — syncing blocked videos');
      if (_deviceCode != null) YouTubeService.instance.forceSyncBlocked(_deviceCode!);
    });

    socket.off('appTimeLimitUpdated');
    socket.on('appTimeLimitUpdated', (data) async {
      print('🔔 [SOCKET] appTimeLimitUpdated — syncing policies');
      if (_deviceCode != null) await PolicyService.instance.syncAll(_deviceCode!);
    });

    socket.off('schoolScheduleUpdated');
    socket.on('schoolScheduleUpdated', (data) async {
      print('🔔 [SOCKET] schoolScheduleUpdated — syncing policies');
      if (_deviceCode != null) await PolicyService.instance.syncAll(_deviceCode!);
    });

    socket.off('locationRequested');
    socket.on('locationRequested', (data) async {
      print('📍 [SOCKET] locationRequested from parent — sending location now');
      if (_deviceCode == null) return;
      try {
        final position = await LocationService.instance.getCurrentLocation();
        if (position != null) {
          await _locationRepo.syncLocation(
            deviceCode: _deviceCode!,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
          );
          print('✅ [SOCKET] Location sent on request');
        }
      } catch (e) {
        print('❌ [SOCKET] locationRequested handler error: $e');
      }
    });

    socket.off('timeExtensionResponse');
    socket.on('timeExtensionResponse', (data) async {
      print('🔔 [SOCKET] RECEIVED timeExtensionResponse: $data');
      final approved = data['approved'] as bool;
      final responseMinutes = data['responseMinutes'] as int? ?? 0;

      if (mounted) {
        setState(() => _waitingForResponse = false);
        if (approved && responseMinutes > 0) {
          // Apply extension directly from socket payload — no HTTP round-trip needed.
          // This gives instant UI feedback. _currentTotalLimitMinutes is updated so
          // subsequent _fetchAndApplyNewLimit() calls see deltaMinutes=0 and don't
          // apply the extension a second time.
          setState(() {
            _currentTotalLimitMinutes += responseMinutes;
            final isExpired = _remainingSeconds <= 0 ||
                _endTime == null ||
                _endTime!.isBefore(DateTime.now());
            if (isExpired) {
              _endTime = DateTime.now().add(Duration(minutes: responseMinutes));
            } else {
              _endTime = _endTime!.add(Duration(minutes: responseMinutes));
            }
            final secs =
                (_endTime!.difference(DateTime.now()).inMilliseconds / 1000)
                    .round();
            _remainingSeconds = secs > 0 ? secs : 0;
            if (_remainingSeconds > 30 * 60) _hasShown30m = false;
            if (_remainingSeconds > 15 * 60) _hasShown15m = false;
            if (_remainingSeconds > 5 * 60) _hasShown5m = false;
          });
          _saveEndTime();
          _startCountdown();
          NativeService.cancelScheduledLock().catchError((e) => null);
          // Dismiss locked screen if showing — setState triggers build() to show dashboard
          if (_isTimeUpDialogShowing && mounted) {
            setState(() => _isTimeUpDialogShowing = false);
            NativeService.exitLockedState().catchError((e) => null);
          }
        }
        if (mounted) {
          _showResultDialog(approved, responseMinutes);
        }
      }
    });
  }

  void _showResultDialog(bool approved, int minutes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approved ? '✅ Được duyệt!' : '❌ Bị từ chối', 
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        content: Text(
          approved
              ? 'Phụ huynh đã cho thêm $minutes phút!'
              : 'Phụ huynh đã từ chối yêu cầu.',
          style: GoogleFonts.nunito(fontSize: 16),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Auto-navigate back to child dashboard (clears any pushed routes like request time screen)
              if (mounted) context.go('/child-dashboard');
            },
            child: Text('OK', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    if (_remainingSeconds <= 0) return "00:00:00";
    final h = _remainingSeconds ~/ 3600;
    final m = (_remainingSeconds % 3600) ~/ 60;
    final s = _remainingSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _connectionCheckTimer?.cancel();
    _countdownTimer?.cancel();
    _heartbeatTimer?.cancel();
    _usageSyncTimer?.cancel();
    _screenPollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    
    if (_sessionId != null) {
      _childRepo.endSession(_sessionId!, _deviceCode ?? '');
    }
    
    // Remove socket listeners
    SocketService.instance.socket.off('timeLimitUpdated');
    SocketService.instance.socket.off('timeExtensionResponse');
    SocketService.instance.socket.off('blockedAppsUpdated');
    LocationService.instance.stop();
    YouTubeService.instance.stop();
    _sosTimer?.cancel();
    _audioRecorder.dispose();
    
    super.dispose();
  }

  void _showSOSConfirmDialog() {
    if (_isSOSing) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.red.shade50,
        title: Row(
          children: [
            const Icon(Icons.sos_rounded, color: Colors.red, size: 32),
            const SizedBox(width: 8),
            Text('Gửi SOS?',
                style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold, color: Colors.red.shade800)),
          ],
        ),
        content: Text(
          'Hệ thống sẽ ghi âm 15 giây và gửi cảnh báo khẩn tới phụ huynh ngay lập tức.',
          style: GoogleFonts.nunito(fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Hủy',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _triggerSOS();
                  },
                  child: Text('🆘 GỬI SOS',
                      style: GoogleFonts.nunito(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSOS() async {
    if (_deviceCode == null || _isSOSing) return;

    // TC-16 FIX: Check mic status without requesting permission.
    // Using .request() forces a permission popup even when permission was already denied,
    // which blocks the SOS flow. We check the current status instead and only request
    // if the status is "undetermined" (never asked before).
    PermissionStatus micStatus = await Permission.microphone.status;
    if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
      // No mic permission — send SOS without audio (TC-16 fallback)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Không có quyền micro — gửi SOS không có ghi âm."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ));
      }
      setState(() => _isSOSing = true);
      await _finishSOS(withAudio: false);
      return;
    }

    // Permission not yet determined — request it once
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        setState(() => _isSOSing = true);
        await _finishSOS(withAudio: false);
        return;
      }
    }

    setState(() {
      _isSOSing = true;
      _sosCountdown = 15;
    });

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/sos_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) return;
        setState(() {
          _sosCountdown--;
        });

        if (_sosCountdown <= 0) {
          timer.cancel();
          await _finishSOS();
        }
      });
    } catch (e) {
      print('❌ Start SOS error: $e');
      if (mounted) setState(() => _isSOSing = false);
    }
  }

  /// Kết thúc SOS: dừng ghi âm (nếu có) và gửi lên server.
  /// [withAudio] = false → bỏ qua dừng recorder và gửi không kèm audio (TC-16).
  Future<void> _finishSOS({bool withAudio = true}) async {
    try {
      String? recordedPath;
      if (withAudio) {
        recordedPath = await _audioRecorder.stop();
        if (recordedPath == null) throw Exception("Recording failed");
      }

      final position = await LocationService.instance.getCurrentLocation();
      double lat = position?.latitude ?? 0;
      double lng = position?.longitude ?? 0;

      await _childRepo.sendSOS(
        deviceCode: _deviceCode!,
        lat: lat,
        lng: lng,
        audioPath: recordedPath, // null when withAudio=false
      );
      print('✅ SOS sent (audio: $withAudio)');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Đã gửi cảnh báo SOS đến phụ huynh!"),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      print('❌ Send SOS error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Lỗi khi gửi SOS! Vui lòng thử lại."),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSOSing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: AppTheme.gradientBg(AppColors.timeRemainingGradient),
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }

    if (!_hasToken) {
      return _buildRelinkScreen();
    }

    if (_isTimeUpDialogShowing) {
      return ChildLockedWidget(
        onRequestTime: () => context.push('/child-request-time'),
        onGoHome: () => setState(() => _isTimeUpDialogShowing = false),
      );
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: AppTheme.gradientBg(AppColors.timeRemainingGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.screenPadding,
                  ),
                  child: Column(
                    children: [
                      _buildTopBar(),
                      _buildProfileRow(),
                      const SizedBox(height: 8),
                      _buildCircularProgress(),
                      const SizedBox(height: 16),
                      _buildStatusMessage(),
                      const SizedBox(height: 16),
                      _buildAppUsageCard(),
                      const SizedBox(height: 16),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      _buildFooterStars(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        floatingActionButton: _isSOSing 
          ? FloatingActionButton.extended(
              onPressed: null,
              backgroundColor: Colors.red.shade800,
              icon: const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              ),
              label: Text("Đang ghi âm $_sosCountdown s...", style: const TextStyle(color: Colors.white)),
            )
          : FloatingActionButton(
              onPressed: _showSOSConfirmDialog,
              backgroundColor: Colors.red,
              child: const Icon(Icons.sos_rounded, color: Colors.white, size: 32),
            ),
      ),
    );
  }

  Widget _buildRelinkScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.link_off, size: 100, color: Colors.white70),
                  const SizedBox(height: 24),
                  Text(
                    'Chưa liên kết thiết bị',
                    style: GoogleFonts.nunito(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vui lòng liên kết thiết bị với tài khoản phụ huynh trước khi tiếp tục.',
                    style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(roleProvider.notifier).setLinked(false),
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: Text('Quét mã QR', style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF667EEA),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(AppTheme.radiusIconSm),
            ),
            child: const Icon(Icons.shield_outlined, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Text(
            'KidFun',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (ctx, _) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isSocketConnected
                      ? const Color(0xFF34D399)
                      : Colors.red.shade300,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isSocketConnected ? 'Đang giám sát' : 'Mất kết nối',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.white.withOpacity(0.80),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
            ),
            child: const Center(child: Text('👦', style: TextStyle(fontSize: 24))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào!',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _deviceCode ?? 'Thiết bị',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.60),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(AppTheme.radiusIconSm),
            ),
            child: const Icon(
              Icons.notifications_none_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularProgress() {
    final totalSeconds = _currentTotalLimitMinutes * 60;
    final percent = totalSeconds > 0
        ? (1.0 - (_remainingSeconds / totalSeconds)).clamp(0.0, 1.0)
        : 0.0;
    final isWarning = _remainingSeconds > 0 && _remainingSeconds < 30 * 60;

    if (!_isLimitEnabled) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: AppTheme.glassCard(),
          child: Text(
            'Hôm nay con có thể thoải mái sử dụng thiết bị 🎉',
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Center(
      child: SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(220, 220),
              painter: _CircularProgressPainter(
                percent: percent,
                trackColor: Colors.white.withOpacity(0.20),
                fillColor: isWarning ? const Color(0xFFF97316) : Colors.white,
                strokeWidth: 18,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Thời gian còn lại',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.60),
                  ),
                ),
                Text(
                  _formattedTime,
                  style: GoogleFonts.nunito(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  '/ ${_currentTotalLimitMinutes ~/ 60}h'
                  '${_currentTotalLimitMinutes % 60 > 0 ? " ${_currentTotalLimitMinutes % 60}m" : ""}'
                  ' hôm nay',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.60),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isWarning
                        ? const Color(0xFFF97316).withOpacity(0.30)
                        : Colors.white.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                  child: Text(
                    'Đã dùng: ${_formatTimeDisplay((_currentTotalLimitMinutes * 60) - _remainingSeconds)}',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isWarning ? const Color(0xFFFFEDD5) : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeDisplay(int seconds) {
    if (seconds < 0) seconds = 0;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
    if (m > 0) return '${m}m${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  Widget _buildStatusMessage() {
    final isWarning = _remainingSeconds > 0 && _remainingSeconds < 30 * 60;
    final remainMins = _remainingSeconds ~/ 60;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isWarning
            ? const Color(0xFFF97316).withOpacity(0.20)
            : Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        border: Border.all(
          color: isWarning
              ? const Color(0xFFFED7AA).withOpacity(0.30)
              : Colors.white.withOpacity(0.20),
        ),
      ),
      child: Column(
        children: [
          Text(
            isWarning ? '⚠️ Sắp hết giờ!' : '🌟 Đang dùng tốt!',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isWarning ? const Color(0xFFFED7AA) : Colors.white,
            ),
          ),
          Text(
            isWarning
                ? 'Còn $remainMins phút, hãy chuẩn bị dừng lại nhé'
                : 'Tiếp tục giữ thói quen tốt bạn nhé!',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: isWarning
                  ? const Color(0xFFFED7AA).withOpacity(0.70)
                  : Colors.white.withOpacity(0.60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppUsageCard() {
    final apps = [
      {'emoji': '▶️', 'name': 'YouTube',   'used': 45, 'max': 60,  'color': const Color(0xFFEF4444), 'blocked': false},
      {'emoji': '🎮', 'name': 'Roblox',    'used': 30, 'max': 45,  'color': const Color(0xFFF97316), 'blocked': false},
      {'emoji': '📚', 'name': 'Khan Acad', 'used': 20, 'max': 120, 'color': const Color(0xFF10B981), 'blocked': false},
      {'emoji': '🎵', 'name': 'TikTok',    'used': 0,  'max': 0,   'color': const Color(0xFFEF4444), 'blocked': true},
    ];

    return Container(
      decoration: AppTheme.glassCard(),
      padding: const EdgeInsets.all(AppTheme.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ứng dụng hôm nay',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withOpacity(0.80),
            ),
          ),
          const SizedBox(height: 12),
          ...apps.map((app) => _buildAppRow(app)),
        ],
      ),
    );
  }

  Widget _buildAppRow(Map app) {
    final blocked = app['blocked'] as bool;
    final used = app['used'] as int;
    final max = app['max'] as int;
    final color = app['color'] as Color;
    final progress = max > 0 ? (used / max).clamp(0.0, 1.0) : 0.0;
    final isOver = progress > 0.9;

    return Opacity(
      opacity: blocked ? 0.50 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Row(
              children: [
                Text(app['emoji'] as String, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app['name'] as String,
                    style: GoogleFonts.nunito(fontSize: 13, color: Colors.white),
                  ),
                ),
                blocked
                    ? Row(
                        children: [
                          const Icon(Icons.lock_outline, size: 12, color: Color(0xFFFCA5A5)),
                          const SizedBox(width: 4),
                          Text(
                            'Bị chặn',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: const Color(0xFFFCA5A5),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '$used/${max}ph',
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.60),
                        ),
                      ),
              ],
            ),
            if (!blocked) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.20),
                  valueColor: AlwaysStoppedAnimation(
                    isOver ? const Color(0xFFF97316) : color,
                  ),
                  minHeight: 6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      height: AppTheme.btnHeightLg,
      child: GestureDetector(
        onTap: _waitingForResponse
            ? null
            : () => context.push('/child-request-time'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: _waitingForResponse
                ? null
                : const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF0F0FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: _waitingForResponse ? Colors.white.withOpacity(0.20) : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
            border: _waitingForResponse
                ? Border.all(color: Colors.white.withOpacity(0.20))
                : null,
            boxShadow: _waitingForResponse
                ? null
                : [
                    BoxShadow(
                      color: AppColors.slate900.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _waitingForResponse
                      ? Icons.hourglass_top_outlined
                      : Icons.access_time_outlined,
                  color: _waitingForResponse
                      ? Colors.white
                      : AppColors.indigo700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _waitingForResponse ? 'Đang chờ phụ huynh...' : '⏱ Xin thêm giờ',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: _waitingForResponse
                        ? Colors.white
                        : AppColors.indigo700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterStars() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        5,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.star, size: 16, color: Colors.white.withOpacity(0.30)),
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double percent;
  final Color trackColor;
  final Color fillColor;
  final double strokeWidth;

  const _CircularProgressPainter({
    required this.percent,
    required this.trackColor,
    required this.fillColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * percent;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    if (percent > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = fillColor
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.percent != percent || old.fillColor != fillColor;
}
