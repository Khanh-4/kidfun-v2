import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../auth/providers/role_provider.dart';
import '../../../core/network/socket_service.dart';
import '../../../core/services/native_service.dart';
import '../data/child_repository.dart';

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

    // Sprint 4: Task 2 - Session & Countdown
    _initSession();
    _setupSocketListeners();
  }

  Future<void> _initSession() async {
    if (_deviceCode == null) return;

    try {
      // 1. Get remaining time
      final todayLimit = await _childRepo.getTodayLimit(_deviceCode!);
      // Bug D fix: debug log to verify API returns correct value
      print('📊 [DEBUG] _initSession: limitMinutes=${todayLimit.limitMinutes}, remainingMinutes=${todayLimit.remainingMinutes}, remainingSeconds=${todayLimit.remainingSeconds}');
      
      _currentTotalLimitMinutes = todayLimit.limitMinutes; // Initialize total limit tracking

      if (mounted) {
        final serverSeconds = todayLimit.remainingSeconds;
        final drift = _endTime == null ? 0 : (_remainingSeconds - serverSeconds).abs();
        setState(() {
          _isLimitEnabled = todayLimit.isLimitEnabled;
          if (drift > 60 || _endTime == null) {
             _remainingSeconds = serverSeconds;
             // BUG 2 FIX: pin endTime anchor so countdown is wall-clock-based
             _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
          }
        });
      }

      // 2. Start session
      final sid = await _childRepo.startSession(_deviceCode!);
      _sessionId = sid;

      // 3. Start countdown or trigger time up immediately
      if (!_isLimitEnabled) {
         if (_isTimeUpDialogShowing) {
            Navigator.of(context, rootNavigator: true).pop();
            _isTimeUpDialogShowing = false;
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
            );
            if (mounted) {
              // Completely decouple heartbeat API response from UI countdown
              print('💓 [HEARTBEAT] ping successful. UI timer isolated from API latency.');
              
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
      print('🚫 [BLOCKED] Synced ${packages.length} blocked apps');
    } catch (e) {
      print('❌ [BLOCKED] Sync error: $e');
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
      _childRepo.endSession(_sessionId!);
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

    // Hiện màn hình khóa fullscreen (backup nếu Device Admin chưa được cấp)
    _isTimeUpDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false, // Chặn nút back
        child: AlertDialog(
          title: Text('⏰ Hết giờ!', 
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: Colors.red)),
          content: Text(
            'Thời gian sử dụng thiết bị hôm nay đã hết.\nHãy nghỉ ngơi nhé!',
            style: GoogleFonts.nunito(fontSize: 16),
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () => _showRequestDialog(),
              icon: const Icon(Icons.access_time),
              label: Text('Xin thêm giờ', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _isTimeUpDialogShowing = false;
    });
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
            // ONLY apply delta to preserve exact local seconds played, do NOT overwrite with backend remainingSeconds
            if (wasUnlimited) {
              _remainingSeconds = (_pausedRemainingSeconds ?? newRemainingSeconds) + (deltaMinutes * 60);
              _endTime = DateTime.now().add(Duration(seconds: _remainingSeconds));
              _pausedRemainingSeconds = null;
            } else {
              final isExpired = _remainingSeconds <= 0 || _endTime!.isBefore(DateTime.now());
              if (isExpired) {
                _endTime = DateTime.now().add(Duration(minutes: deltaMinutes));
              } else {
                _endTime = _endTime!.add(Duration(minutes: deltaMinutes));
              }
            }
            
            final secs = (_endTime!.difference(DateTime.now()).inMilliseconds / 1000).round();
            _remainingSeconds = secs > 0 ? secs : 0;
            
            if (_remainingSeconds > 30 * 60) _hasShown30m = false;
            if (_remainingSeconds > 15 * 60) _hasShown15m = false;
            if (_remainingSeconds > 5 * 60) _hasShown5m = false;
          }
        });
        
        if ((!enabled || _remainingSeconds > 0) && _isTimeUpDialogShowing) {
          Navigator.of(context, rootNavigator: true).pop();
          _isTimeUpDialogShowing = false;
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

    socket.off('timeExtensionResponse');
    socket.on('timeExtensionResponse', (data) async {
      print('🔔 [SOCKET] RECEIVED timeExtensionResponse: $data');
      final approved = data['approved'] as bool;
      final responseMinutes = data['responseMinutes'] as int? ?? 0;

      if (mounted) {
        setState(() => _waitingForResponse = false);
        _showResultDialog(approved, responseMinutes);
        if (approved) {
          await _fetchAndApplyNewLimit();
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
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showRequestDialog() {
    int requestMinutes = 15;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Xin thêm giờ', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Con muốn xin thêm bao nhiêu phút?', style: GoogleFonts.nunito()),
              const SizedBox(height: 16),
              // Chọn số phút
              Wrap(
                spacing: 8,
                children: [15, 30, 45, 60].map((min) {
                  return ChoiceChip(
                    label: Text('$min phút', style: GoogleFonts.nunito()),
                    selected: requestMinutes == min,
                    onSelected: (selected) {
                      if (selected) setDialogState(() => requestMinutes = min);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              // Lý do
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Lý do (không bắt buộc)',
                  hintText: 'VD: Con đang làm bài tập...',
                  hintStyle: GoogleFonts.nunito(color: Colors.grey),
                  labelStyle: GoogleFonts.nunito(),
                  border: const OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Hủy', style: GoogleFonts.nunito(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _sendTimeExtensionRequest(requestMinutes, reasonController.text);
              },
              child: Text('Gửi yêu cầu', style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _sendTimeExtensionRequest(int minutes, String reason) {
    if (_deviceCode == null) return;

    SocketService.instance.socket.emit('requestTimeExtension', {
      'deviceCode': _deviceCode,
      'requestMinutes': minutes,
      'reason': reason,
    });

    setState(() => _waitingForResponse = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi yêu cầu cho phụ huynh. Đang chờ phản hồi...', 
          style: GoogleFonts.nunito()),
        backgroundColor: Colors.blue,
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
    WidgetsBinding.instance.removeObserver(this);
    
    if (_sessionId != null) {
      _childRepo.endSession(_sessionId!);
    }
    
    // Remove socket listeners
    SocketService.instance.socket.off('timeLimitUpdated');
    SocketService.instance.socket.off('timeExtensionResponse');
    SocketService.instance.socket.off('blockedAppsUpdated');
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasToken) {
      return _buildRelinkScreen();
    }

    return _buildDashboard();
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

  Widget _buildDashboard() {
    return PopScope(
      canPop: false, // Child cannot go back
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildWelcomeCard(),
                      const SizedBox(height: 24),
                      _buildTimeCard(),
                      const SizedBox(height: 24),
                      _buildConnectionStatus(),
                      const SizedBox(height: 24),
                      _buildRequestMoreTimeButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // App name
          Expanded(
            child: Text(
              'KidFun 🌟',
              style: GoogleFonts.nunito(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          // Connection indicator
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isSocketConnected ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _isSocketConnected ? Colors.greenAccent : Colors.red.shade300,
                    shape: BoxShape.circle,
                    boxShadow: _isSocketConnected
                        ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.7), blurRadius: 8, spreadRadius: 2)]
                        : [],
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            _isSocketConnected ? 'Đã kết nối máy chủ' : 'Mất kết nối máy chủ',
            style: GoogleFonts.nunito(
              color: _isSocketConnected ? Colors.greenAccent : Colors.red.shade200,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF42E695), Color(0xFF3BB2B8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF42E695).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          const Text('👦', style: TextStyle(fontSize: 60)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xin chào!',
                  style: GoogleFonts.nunito(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  'Hôm nay vui không? 😊',
                  style: GoogleFonts.nunito(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          if (!_isLimitEnabled) ...[
            Text(
              'Hôm nay con có thể thoải mái sử dụng thiết bị',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.green.shade600,
                height: 1.4,
              ),
            ),
          ] else ...[
            Text(
              '⏳ Thời gian còn lại',
              style: GoogleFonts.nunito(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _formattedTime,
              style: GoogleFonts.nunito(
                fontSize: 72,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF667EEA),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thời gian hôm nay có hạn. Hãy sử dụng thông minh!',
              style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isSocketConnected
            ? Colors.green.shade50
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isSocketConnected ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (ctx, child) {
              return Transform.scale(
                scale: _isSocketConnected ? _pulseAnimation.value : 1.0,
                child: Icon(
                  _isSocketConnected ? Icons.wifi : Icons.wifi_off,
                  color: _isSocketConnected ? Colors.green : Colors.red,
                  size: 32,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isSocketConnected ? '🟢 Đã kết nối với máy chủ' : '🔴 Mất kết nối',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _isSocketConnected ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                Text(
                  _isSocketConnected
                      ? 'Phụ huynh có thể theo dõi hoạt động của bạn'
                      : 'Đang cố gắng kết nối lại...',
                  style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          if (!_isSocketConnected)
            IconButton(
              onPressed: () {
                SocketService.instance.reconnect();
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Kết nối lại',
            ),
        ],
      ),
    );
  }

  Widget _buildRequestMoreTimeButton() {
    return GestureDetector(
      onTap: _waitingForResponse ? null : _showRequestDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: _waitingForResponse
              ? const LinearGradient(colors: [Colors.grey, Colors.blueGrey])
              : const LinearGradient(
                  colors: [Color(0xFFFF9966), Color(0xFFFF5E62)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: (_waitingForResponse ? Colors.grey : const Color(0xFFFF5E62))
                  .withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_waitingForResponse ? '⏳' : '🙋', style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Text(
                _waitingForResponse ? 'Đang chờ duyệt...' : 'Xin thêm giờ',
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
