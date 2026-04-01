# Bước 4 — Profile Screens

> **Branch:** `feat/ui/parent/profile-screens`  
> **Trạng thái:** ⬜ Chưa làm  
> **Files:**
> - `mobile/lib/features/profile/screens/profile_list_screen.dart`
> - `mobile/lib/features/profile/screens/create_profile_screen.dart`
> - `mobile/lib/features/profile/screens/edit_profile_screen.dart`

---

## Mục tiêu

Redesign 3 màn hình profile với AppBar indigo gradient, card trắng, emoji avatar.  
Giữ nguyên toàn bộ logic (profileProvider, CRUD).

---

## Profile List Screen

### AppBar
```dart
AppBar(
  title: Text('Hồ sơ con', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: Colors.white)),
  flexibleSpace: Container(decoration: AppTheme.gradientBg([AppColors.indigo600, AppColors.indigo700])),
  iconTheme: IconThemeData(color: Colors.white),
  actions: [
    IconButton(icon: Icon(Icons.add, color: Colors.white), onPressed: () => context.push('/profiles/create')),
  ],
)
```

### Profile Card (thay ListTile cũ)
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
    onTap: () => context.push('/profiles/${profile.id}/edit', extra: profile),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(children: [
        // Avatar emoji circle
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: AppColors.indigo600.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Center(child: Text('👧', style: TextStyle(fontSize: 28))),
        ),
        SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(profile.profileName,
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800)),
          Text(profile.age != null ? '${profile.age} tuổi' : 'Chưa có thông tin',
              style: GoogleFonts.nunito(fontSize: 13, color: AppColors.slate500)),
        ])),
        // Quick action buttons
        Row(children: [
          _QuickActionBtn(icon: Icons.timer_outlined, color: AppColors.warning,
              onTap: () => context.push('/profiles/${profile.id}/time-limit?name=${profile.profileName}')),
          SizedBox(width: 8),
          _QuickActionBtn(icon: Icons.apps_outlined, color: AppColors.indigo600,
              onTap: () => context.push('/profiles/${profile.id}/app-blocking?name=${profile.profileName}')),
          SizedBox(width: 8),
          Icon(Icons.chevron_right, color: AppColors.slate400),
        ]),
      ]),
    ),
  ),
)

// _QuickActionBtn:
GestureDetector(
  onTap: onTap,
  child: Container(
    width: 32, height: 32,
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, size: 18, color: color),
  ),
)
```

### Empty state
```dart
Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  Icon(Icons.people_outline, size: 80, color: AppColors.slate300),
  SizedBox(height: 16),
  Text('Chưa có hồ sơ nào',
      style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.slate600)),
  Text('Nhấn + để tạo hồ sơ cho con',
      style: GoogleFonts.nunito(fontSize: 14, color: AppColors.slate400)),
  SizedBox(height: 24),
  ElevatedButton.icon(
    onPressed: () => context.push('/profiles/create'),
    icon: Icon(Icons.add),
    label: Text('Tạo hồ sơ đầu tiên', style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
  ),
]))
```

---

## Create / Edit Profile Screen

### Layout chung
```dart
Scaffold(
  backgroundColor: AppColors.slate50,
  appBar: AppBar(
    title: Text('Tạo hồ sơ', style: ...),  // hoặc "Chỉnh sửa hồ sơ"
    flexibleSpace: ...,
  ),
  body: SingleChildScrollView(
    padding: EdgeInsets.all(AppTheme.screenPadding),
    child: Column(children: [
      _buildAvatarSection(),  // emoji avatar chọn
      SizedBox(height: 20),
      _buildFormCard(),       // card trắng chứa fields
      SizedBox(height: 20),
      if (isEdit) _buildDangerZone(),  // xóa hồ sơ
    ]),
  ),
)
```

### Avatar section
```dart
Center(child: Column(children: [
  Container(
    width: 96, height: 96,
    decoration: BoxDecoration(
      color: AppColors.indigo600.withOpacity(0.10),
      shape: BoxShape.circle,
      border: Border.all(color: AppColors.indigo200, width: 2),
    ),
    child: Center(child: Text('👧', style: TextStyle(fontSize: 52))),
  ),
  SizedBox(height: 8),
  Text('Ảnh đại diện', style: GoogleFonts.nunito(fontSize: 12, color: AppColors.slate500)),
]))
```

### Form Card
```dart
Container(
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
    border: Border.all(color: AppColors.slate200),
    boxShadow: [...],
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(children: [
    _buildLabeledField('Tên con', _nameController, Icons.person_outline),
    SizedBox(height: 16),
    _buildLabeledField('Tuổi', _ageController, Icons.cake_outlined,
        keyboardType: TextInputType.number),
    SizedBox(height: 24),
    SizedBox(
      width: double.infinity, height: AppTheme.btnHeightLg,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _save,
        child: Text('Lưu hồ sơ', style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    ),
  ]),
)
```

### Danger Zone (Edit only)
```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.dangerBg,
    borderRadius: BorderRadius.circular(AppTheme.radiusCardMd),
    border: Border.all(color: AppColors.dangerBorder),
  ),
  padding: EdgeInsets.all(AppTheme.cardPadding),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Vùng nguy hiểm', style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.danger)),
    SizedBox(height: 8),
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _deleteProfile,
        icon: Icon(Icons.delete_outline, color: AppColors.danger),
        label: Text('Xóa hồ sơ này', style: GoogleFonts.nunito(color: AppColors.danger, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: AppColors.danger)),
      ),
    ),
  ]),
)
```

---

## Commit message

```
feat(mobile/ui): redesign Profile screens — list, create, edit
```

---

## Prompt để tiếp tục

```
Đọc file `UI/Plan Upgrade UI - Parent/Step4-ProfileScreens.md`.
Tạo branch `feat/ui/parent/profile-screens` từ develop.
Redesign 3 file profile screens theo plan.
Giữ nguyên toàn bộ logic profileProvider + CRUD.
Commit + push + PR về develop.
```
