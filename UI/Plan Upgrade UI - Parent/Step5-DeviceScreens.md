# Bước 5 — Device Screens

> **Branch:** `feat/ui/parent/device-screens`  
> **Trạng thái:** ⬜ Chưa làm  
> **Files:**
> - `mobile/lib/features/device/screens/device_list_screen.dart`
> - `mobile/lib/features/device/screens/add_device_screen.dart`

---

## Mục tiêu

Redesign 2 màn hình quản lý thiết bị.  
Giữ nguyên toàn bộ logic (deviceProvider, assignProfile, deleteDevice, generatePairingCode).

---

## Device List Screen

### AppBar
```dart
AppBar(
  title: Text('Thiết bị', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
  flexibleSpace: Container(decoration: AppTheme.gradientBg([AppColors.indigo600, AppColors.indigo700])),
  iconTheme: IconThemeData(color: Colors.white),
  actions: [
    IconButton(icon: Icon(Icons.add, color: Colors.white), onPressed: () => context.push('/devices/add')),
  ],
)
```

### Device Card
```dart
Container(
  margin: EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
    border: Border.all(color: AppColors.slate200),
    boxShadow: [BoxShadow(color: AppColors.slate900.withOpacity(0.06), blurRadius: 8, offset: Offset(0,2))],
  ),
  child: InkWell(
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
    onTap: () => _showDeviceOptions(context, device, profiles),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(children: [
        // Status indicator + icon
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: device.isOnline
                ? AppColors.successBg
                : AppColors.slate100,
            borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
          ),
          child: Icon(
            Icons.phone_android_outlined,
            color: device.isOnline ? AppColors.success : AppColors.slate400,
            size: 26,
          ),
        ),
        SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(device.deviceName,
              style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate800),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: 2),
          Text('Hồ sơ: $profileName',
              style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
          SizedBox(height: 4),
          // Online badge
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: device.isOnline ? AppColors.successBg : AppColors.slate100,
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: device.isOnline ? AppColors.successBorder : AppColors.slate200),
            ),
            child: Text(
              device.isOnline ? 'Đang online' : (lastSeenStr.isNotEmpty ? 'Online $lastSeenStr' : 'Offline'),
              style: GoogleFonts.nunito(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: device.isOnline ? AppColors.success : AppColors.slate400,
              ),
            ),
          ),
        ])),
        Icon(Icons.more_vert, color: AppColors.slate400),
      ]),
    ),
  ),
)
```

### Bottom Sheet options (thay AlertDialog cũ)
```dart
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.white,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
  ),
  builder: (ctx) => Padding(
    padding: EdgeInsets.all(AppTheme.cardPadding),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      // Handle bar
      Container(width: 40, height: 4, decoration: BoxDecoration(
        color: AppColors.slate200, borderRadius: BorderRadius.circular(2))),
      SizedBox(height: 16),
      Text(device.deviceName,
          style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800)),
      SizedBox(height: 20),
      // Assign profile dropdown (giữ nguyên logic)
      // ...
      // Navigate buttons
      // Delete button (đỏ)
    ]),
  ),
)
```

### Empty state
```dart
Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  Icon(Icons.devices_outlined, size: 80, color: AppColors.slate300),
  SizedBox(height: 16),
  Text('Chưa có thiết bị nào',
      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.slate600)),
  Text('Nhấn + để thêm thiết bị của con',
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.slate400)),
  SizedBox(height: 24),
  ElevatedButton.icon(
    onPressed: () => context.push('/devices/add'),
    icon: Icon(Icons.add),
    label: Text('Thêm thiết bị', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
  ),
]))
```

---

## Add Device Screen

### Layout
```dart
Scaffold(
  backgroundColor: AppColors.slate50,
  appBar: AppBar(title: Text('Thêm thiết bị'), ...),
  body: SingleChildScrollView(
    padding: EdgeInsets.all(AppTheme.screenPadding),
    child: Column(children: [
      _buildPairingCodeCard(),  // Hiển thị mã + QR
      SizedBox(height: 16),
      _buildInstructionCard(),  // Hướng dẫn các bước
    ]),
  ),
)
```

### Pairing Code Card
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [AppColors.indigo600, AppColors.indigo700],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    boxShadow: [BoxShadow(color: AppColors.indigo600.withOpacity(0.30), blurRadius: 20, offset: Offset(0,8))],
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(children: [
    Text('Mã liên kết thiết bị',
        style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.70))),
    SizedBox(height: 12),
    // Mã 6 số to
    Text(pairingCode,
        style: GoogleFonts.nunito(fontSize: 48, fontWeight: FontWeight.w800,
            color: Colors.white, letterSpacing: 8)),
    SizedBox(height: 8),
    Text('Hết hạn sau 10 phút',
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.60))),
    SizedBox(height: 16),
    // Refresh button
    OutlinedButton.icon(
      onPressed: _generateCode,
      icon: Icon(Icons.refresh, color: Colors.white),
      label: Text('Tạo mã mới', style: GoogleFonts.nunito(color: Colors.white)),
      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.white.withOpacity(0.50))),
    ),
  ]),
)
```

### Instruction Card
```dart
Container(
  decoration: BoxDecoration(color: Colors.white, borderRadius: ..., border: ..., boxShadow: ...),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Cách kết nối thiết bị con',
        style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
    SizedBox(height: 16),
    // Steps 1-3 (giống step guide trong LinkDevicePage)
    _buildStep('1', 'Mở app KidShield trên thiết bị con'),
    _buildStep('2', 'Chọn "Thiết bị của con" → "Liên kết thiết bị"'),
    _buildStep('3', 'Nhập mã ${pairingCode} hoặc quét mã QR'),
  ]),
)
```

---

## Commit message

```
feat(mobile/ui): redesign Device screens — list, add device
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI - Parent/Step5-DeviceScreens.md`.
Tạo branch `feat/ui/parent/device-screens` từ develop.
Redesign 2 file device screens theo plan.
Giữ nguyên toàn bộ logic deviceProvider.
Commit + push + PR về develop.
```
