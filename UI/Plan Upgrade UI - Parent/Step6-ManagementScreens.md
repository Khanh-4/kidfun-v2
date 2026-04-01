# Bước 6 — Management Screens (Giới hạn giờ / Chặn app / Báo cáo)

> **Branch:** `feat/ui/parent/management-screens`  
> **Trạng thái:** ⬜ Chưa làm  
> **Files:**
> - `mobile/lib/features/time_limit/screens/time_limit_screen.dart`
> - `mobile/lib/features/profile/screens/app_blocking_screen.dart`
> - `mobile/lib/features/profile/screens/app_usage_report_screen.dart`

---

## Mục tiêu

Redesign 3 màn hình quản lý — phức tạp nhất vì có nhiều dữ liệu.  
Giữ nguyên 100% logic (time limit CRUD, app blocking toggle, usage stats).

---

## Time Limit Screen

### Layout
```dart
Scaffold(
  backgroundColor: AppColors.slate50,
  appBar: AppBar(
    title: Text('Giới hạn thời gian', ...),
    flexibleSpace: Container(decoration: AppTheme.gradientBg([AppColors.warning, Color(0xFFD97706)])),
    // amber gradient cho màn hình giới hạn
    iconTheme: IconThemeData(color: Colors.white),
  ),
  body: SingleChildScrollView(
    padding: EdgeInsets.all(AppTheme.screenPadding),
    child: Column(children: [
      _buildSummaryCard(),    // Tổng giới hạn tuần
      SizedBox(height: 16),
      _buildDayLimitList(),   // List 7 ngày
      SizedBox(height: 16),
      _buildSaveButton(),
    ]),
  ),
)
```

### Summary Card
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [AppColors.warning, Color(0xFFF59E0B)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(children: [
    Text('Tổng giới hạn tuần này',
        style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.80))),
    Text('$totalHours giờ',
        style: GoogleFonts.nunito(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white)),
    Text('Trung bình ${(totalHours / 7).toStringAsFixed(1)} giờ/ngày',
        style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.70))),
  ]),
)
```

### Day Limit Row (mỗi ngày)
```dart
Container(
  margin: EdgeInsets.only(bottom: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
    border: Border.all(color: AppColors.slate200),
  ),
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  child: Row(children: [
    // Day label
    SizedBox(width: 40,
        child: Text(dayLabel, style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700))),
    // Enable toggle
    Switch(value: isEnabled, onChanged: _toggleDay, activeColor: AppColors.warning),
    Expanded(child: isEnabled
        // Slider giờ
        ? Slider(value: hours, min: 0.5, max: 12, divisions: 23,
              activeColor: AppColors.warning,
              label: '${hours}h',
              onChanged: _updateHours)
        : Text('Không giới hạn',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate400))),
    if (isEnabled)
      Text('${hours}h', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.warning)),
  ]),
)
```

---

## App Blocking Screen

### Layout
```dart
Scaffold(
  backgroundColor: AppColors.slate50,
  appBar: AppBar(title: Text('Chặn ứng dụng'), ...),
  body: Column(children: [
    _buildSearchBar(),    // Search field
    Expanded(child: _buildAppList()),  // List apps với toggle
  ]),
)
```

### Search Bar
```dart
Container(
  color: Colors.white,
  padding: EdgeInsets.all(12),
  child: TextField(
    decoration: InputDecoration(
      prefixIcon: Icon(Icons.search, color: AppColors.slate400),
      hintText: 'Tìm ứng dụng...',
      hintStyle: GoogleFonts.nunito(color: AppColors.slate400),
    ),
    onChanged: _filterApps,
  ),
)
```

### App Row
```dart
Container(
  margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
    border: Border.all(color: isBlocked ? AppColors.dangerBorder : AppColors.slate200),
  ),
  child: ListTile(
    leading: Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: isBlocked ? AppColors.dangerBg : AppColors.slate100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: app.icon != null
          ? Image.memory(app.icon!) 
          : Icon(Icons.apps_outlined, color: isBlocked ? AppColors.danger : AppColors.slate500),
    ),
    title: Text(app.appName, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600,
        color: isBlocked ? AppColors.danger : AppColors.slate800)),
    subtitle: Text(app.packageName, style: GoogleFonts.nunito(fontSize: 11, color: AppColors.slate400),
        maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: Switch(value: isBlocked, onChanged: _toggleBlock,
        activeColor: AppColors.danger, activeTrackColor: AppColors.dangerBg),
  ),
)
```

---

## App Usage Report Screen

### Layout
```dart
Scaffold(
  backgroundColor: AppColors.slate50,
  appBar: AppBar(
    title: Text('Báo cáo sử dụng'),
    flexibleSpace: Container(decoration: AppTheme.gradientBg([AppColors.success, Color(0xFF059669)])),
    iconTheme: IconThemeData(color: Colors.white),
    actions: [
      // Date picker
      IconButton(icon: Icon(Icons.calendar_today_outlined, color: Colors.white), onPressed: _pickDate),
    ],
  ),
  body: SingleChildScrollView(
    padding: EdgeInsets.all(AppTheme.screenPadding),
    child: Column(children: [
      _buildTotalCard(),      // Tổng giờ hôm nay
      SizedBox(height: 16),
      _buildAppUsageList(),   // List app + bar chart đơn giản
    ]),
  ),
)
```

### Total Card
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [AppColors.success, Color(0xFF059669)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tổng thời gian hôm nay',
          style: GoogleFonts.nunito(fontSize: 13, color: Colors.white.withOpacity(0.80))),
      Text('${totalHours}h ${totalMins}m',
          style: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white)),
    ]),
    Icon(Icons.bar_chart_outlined, size: 48, color: Colors.white.withOpacity(0.40)),
  ]),
)
```

### Usage App Row
```dart
Container(
  margin: EdgeInsets.only(bottom: 10),
  decoration: BoxDecoration(color: Colors.white, borderRadius: ..., border: ..., boxShadow: ...),
  padding: EdgeInsets.all(14),
  child: Column(children: [
    Row(children: [
      // App icon
      Text(app.appName, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600)),
      Spacer(),
      Text('${minutes}ph', style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500)),
    ]),
    SizedBox(height: 8),
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: percent,
        backgroundColor: AppColors.slate100,
        valueColor: AlwaysStoppedAnimation(percent > 0.8 ? AppColors.danger : AppColors.success),
        minHeight: 6,
      ),
    ),
  ]),
)
```

---

## Commit message

```
feat(mobile/ui): redesign Management screens — time limit, app blocking, usage report
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI - Parent/Step6-ManagementScreens.md`.
Tạo branch `feat/ui/parent/management-screens` từ develop.
Redesign 3 file:
- mobile/lib/features/time_limit/screens/time_limit_screen.dart
- mobile/lib/features/profile/screens/app_blocking_screen.dart
- mobile/lib/features/profile/screens/app_usage_report_screen.dart
Giữ nguyên 100% logic (CRUD, toggle, stats).
Commit + push + PR về develop.
```
