# Bước 3 — Home Screen (Phụ huynh Dashboard)

> **Branch:** `feat/ui/parent/home-screen`  
> **Trạng thái:** ⬜ Chưa làm  
> **File:** `mobile/lib/app.dart` → class `HomeScreen`

---

## Mục tiêu

Thay màn hình home đơn giản (2 nút) thành dashboard phụ huynh đẹp:  
greeting, quick stats, nav cards dẫn đến các tính năng.

---

## Thiết kế mới

### AppBar với greeting
```dart
AppBar(
  automaticallyImplyLeading: false,
  flexibleSpace: Container(
    decoration: AppTheme.gradientBg([AppColors.indigo600, AppColors.indigo700]),
  ),
  title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Xin chào, Phụ huynh 👋',
        style: GoogleFonts.nunito(fontSize: 14, color: Colors.white.withOpacity(0.80))),
    Text('KidShield',
        style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
  ]),
  actions: [
    IconButton(
      icon: Icon(Icons.logout_outlined, color: Colors.white),
      onPressed: () => ref.read(authProvider.notifier).logout(),
    ),
  ],
)
```

### Body
```dart
Scaffold(
  backgroundColor: AppColors.slate50,
  body: SingleChildScrollView(
    padding: EdgeInsets.all(AppTheme.screenPadding),
    child: Column(children: [
      SizedBox(height: 8),
      _buildQuickStats(),   // 2 stat cards: số hồ sơ, số thiết bị
      SizedBox(height: 20),
      _buildNavSection(),   // 4 nav cards dạng grid 2x2
      SizedBox(height: 20),
      _buildTipCard(),      // Mẹo sử dụng
    ]),
  ),
)
```

### Quick Stats (2 cards ngang)
```dart
Row(children: [
  Expanded(child: _StatCard(
    icon: Icons.people_outline, label: 'Hồ sơ con', value: '${profiles.length}',
    color: AppColors.indigo600,
  )),
  SizedBox(width: AppTheme.gap),
  Expanded(child: _StatCard(
    icon: Icons.devices_outlined, label: 'Thiết bị', value: '${devices.length}',
    color: AppColors.purple600,
  )),
])

// _StatCard widget:
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
    border: Border.all(color: AppColors.slate200),
    boxShadow: [BoxShadow(color: AppColors.slate900.withOpacity(0.06), blurRadius: 8, offset: Offset(0,2))],
  ),
  padding: EdgeInsets.all(16),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusIconSm),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
    SizedBox(height: 12),
    Text(value, style: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.slate800)),
    Text(label, style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
  ]),
)
```

### Nav Cards (grid 2×2)
```dart
GridView.count(
  shrinkWrap: true, physics: NeverScrollableScrollPhysics(),
  crossAxisCount: 2, crossAxisSpacing: AppTheme.gap, mainAxisSpacing: AppTheme.gap,
  childAspectRatio: 1.1,
  children: [
    _NavCard(icon: Icons.people_outline,   label: 'Hồ sơ con',     color: AppColors.indigo600, onTap: () => context.push('/profiles')),
    _NavCard(icon: Icons.devices_outlined,  label: 'Thiết bị',      color: AppColors.purple600, onTap: () => context.push('/devices')),
    _NavCard(icon: Icons.timer_outlined,    label: 'Giới hạn giờ',  color: AppColors.warning,   onTap: () => context.push('/profiles')),
    _NavCard(icon: Icons.bar_chart_outlined,label: 'Báo cáo',       color: AppColors.success,   onTap: () => context.push('/profiles')),
  ],
)

// _NavCard widget:
GestureDetector(
  onTap: onTap,
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
      border: Border.all(color: AppColors.slate200),
      boxShadow: [BoxShadow(color: AppColors.slate900.withOpacity(0.06), blurRadius: 8, offset: Offset(0,2))],
    ),
    padding: EdgeInsets.all(16),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
      SizedBox(height: 10),
      Text(label, textAlign: TextAlign.center,
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate700)),
    ]),
  ),
)
```

### Tip Card
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [AppColors.indigo600, AppColors.purple600],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('💡 Mẹo hôm nay',
          style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
      SizedBox(height: 4),
      Text('Đặt giới hạn thời gian hợp lý giúp con cân bằng học tập và giải trí.',
          style: GoogleFonts.nunito(fontSize: 12, color: Colors.white.withOpacity(0.80))),
    ])),
    Icon(Icons.arrow_forward_ios, color: Colors.white.withOpacity(0.60), size: 16),
  ]),
)
```

---

## Commit message

```
feat(mobile/ui): redesign HomeScreen phụ huynh — stats, nav grid, tip card
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI - Parent/Step3-HomeScreen.md`.
Tạo branch `feat/ui/parent/home-screen` từ develop.
Redesign class HomeScreen trong `mobile/lib/app.dart` theo plan.
Giữ nguyên logic (profileProvider, deviceProvider, authProvider).
Commit + push + PR về develop.
```
