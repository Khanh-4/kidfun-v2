# KidShield — Mô tả UI đầy đủ (UI Specification)

> Tài liệu này mô tả toàn bộ giao diện của ứng dụng KidShield để làm tham chiếu khi xây dựng KidFun trên React Native / Flutter.

---

## Mục lục

1. [Tổng quan & Tech Stack](#1-tổng-quan--tech-stack)
2. [Design Tokens](#2-design-tokens)
3. [Shared UI Patterns](#3-shared-ui-patterns)
4. [MOBILE — Child Pages (4 màn hình)](#4-mobile--child-pages)
   - 4.1 [LinkDevicePage — Liên kết thiết bị](#41-linkdevicepage--liên-kết-thiết-bị)
   - 4.2 [TimeRemainingPage — Dashboard trẻ](#42-timeremainingpage--dashboard-trẻ)
   - 4.3 [LockedPage — Màn hình khóa](#43-lockedpage--màn-hình-khóa)
   - 4.4 [RequestTimePage — Xin thêm giờ](#44-requesttimepage--xin-thêm-giờ)
5. [PARENT — Layout chung](#5-parent--layout-chung)
6. [PARENT — Trang LoginPage](#6-parent--loginpage)
7. [PARENT — DashboardPage](#7-parent--dashboardpage)
8. [PARENT — ChildrenPage](#8-parent--childrenpage)
9. [PARENT — DevicesPage](#9-parent--devicespage)
10. [PARENT — TimeLimitsPage](#10-parent--timelimitspage)
11. [PARENT — BlockedSitesPage](#11-parent--blockedsitespage)
12. [PARENT — NotificationsPage](#12-parent--notificationspage)
13. [PARENT — HistoryPage](#13-parent--historypage)
14. [PARENT — ReportsPage](#14-parent--reportspage)

---

## 1. Tổng quan & Tech Stack

**Tên app:** KidShield — Ứng dụng kiểm soát thời gian sử dụng thiết bị cho trẻ em  
**Ngôn ngữ UI gốc:** Tiếng Việt  
**Hai vai trò:** Phụ huynh (Parent) và Trẻ em (Child)

| Thành phần | Công nghệ |
|---|---|
| Framework | React 18 + TypeScript |
| Routing | React Router v7 |
| Styling | Tailwind CSS v4 |
| UI Components | Radix UI (shadcn/ui) |
| Icons | Lucide React |
| Charts | Recharts (AreaChart, BarChart, PieChart) |
| Build tool | Vite 6 |

---

## 2. Design Tokens

### 2.1 Màu sắc — Gradients

```
Child — Link Device:     #6366F1 → #9333EA → #EC4899   (indigo → purple → pink)
Child — Time Remaining:  #7C3AED → #4F46E5 → #1D4ED8   (violet → indigo → blue)
Child — Locked Screen:   #0F172A → #1E293B → #1E1B4B   (slate-900 → slate-800 → indigo-950)
Child — Request Time:    #FB923C → #EC4899 → #F43F5E   (orange → pink → rose)

Parent — Login left:     #4F46E5 → #7C3AED             (indigo-600 → purple-700)
Parent — Login bg:       #0F172A → #1E1B4B → #3B0764   (slate-900 → indigo-950 → purple-950)
Parent — Sidebar:        #0F172A                        (slate-900)
Parent — Content bg:     #F8FAFC                        (slate-50)
```

### 2.2 Màu sắc — Semantic

| Ngữ cảnh | Background | Text | Border |
|---|---|---|---|
| Tích cực / OK | `#ECFDF5` (emerald-50) | `#059669` (emerald-600) | `#A7F3D0` (emerald-100) |
| Cảnh báo | `#FFFBEB` (amber-50) | `#D97706` (amber-600) | `#FDE68A` (amber-100) |
| Nguy hiểm | `#FFF1F2` (rose-50) | `#E11D48` (rose-600) | `#FFE4E6` (rose-100) |
| Thông tin | `#EFF6FF` (blue-50) | `#2563EB` (blue-600) | `#DBEAFE` (blue-100) |
| Request | `#EEF2FF` (indigo-50) | `#4F46E5` (indigo-600) | `#C7D2FE` (indigo-100) |
| Trung tính | `#F8FAFC` (slate-50) | `#64748B` (slate-500) | `#E2E8F0` (slate-200) |

### 2.3 Typography

| Cấp | Size | Weight | Color |
|---|---|---|---|
| Page title | 24px (text-2xl) | bold (700) | slate-800 |
| Section heading | 16-18px | semibold (600) | slate-800 |
| Card title | 14-16px | semibold (600) | slate-800 |
| Body | 14px (text-sm) | regular (400) | slate-600 |
| Caption / label | 12px (text-xs) | regular / medium | slate-500 |
| Hero number (child) | 48-64px | extrabold (800) | white |
| Clock (locked) | 64px (text-7xl) | extrabold (800) | white |

### 2.4 Border Radius

| Loại | Giá trị |
|---|---|
| Card lớn | 24px (rounded-3xl) |
| Card thường | 16px (rounded-2xl) |
| Button primary | 16px (rounded-2xl) |
| Button nhỏ / badge | 8-12px (rounded-xl) |
| Badge / pill | 9999px (rounded-full) |
| Input | 12px (rounded-xl) |
| Icon container nhỏ | 12px (rounded-xl) |

### 2.5 Spacing & Sizing

| Thành phần | Kích thước |
|---|---|
| Screen padding (mobile) | 20px (p-5) |
| Card padding | 20-24px |
| Gap giữa items | 12px (gap-3) |
| Button height primary | 52-56px (py-3.5) |
| Button height nhỏ | 36-40px (py-2) |
| Icon button | 36x36px (w-9 h-9) |
| Avatar card header | 64x64px (w-16 h-16) |
| Stat icon | 44x44px (w-11 h-11) |
| Mobile max-width | 384px (max-w-sm) |

### 2.6 Shadows

```
Card:     shadow-sm + border border-slate-100
Button:   shadow-lg shadow-indigo-900/50  (cho nút primary dark)
Modal:    shadow-2xl
```

### 2.7 Animations

| Animation | Cách dùng |
|---|---|
| `animate-pulse` | Icon khóa, dot online, nút chờ xác nhận |
| `animate-bounce` | Bouncing dots (loading), 3 chấm chờ |
| `animate-spin` | Spinner gửi request (duration 3s) |
| transition-all | Tất cả button hover/active |
| strokeDashoffset 0.5s ease | Circular progress SVG |
| scale-105 | Button selected (time options) |

---

## 3. Shared UI Patterns

### 3.1 Glass Card (dùng trên nền gradient)
```
bg-white/15 backdrop-blur rounded-3xl border border-white/20 p-5
```

### 3.2 Ghost Button (trên nền gradient)
```
bg-white/20 backdrop-blur border border-white/20 rounded-2xl text-white
hover: bg-white/30
```

### 3.3 Primary Button (sáng trên gradient tối)
```
bg-white text-indigo-700 font-bold rounded-2xl py-3.5
hover: bg-white/90
shadow-lg
```

### 3.4 Primary Button (indigo, trang parent)
```
bg-indigo-600 text-white rounded-xl font-medium
hover: bg-indigo-700
shadow-md shadow-indigo-200
```

### 3.5 Toggle Switch (custom CSS)
```html
<label class="relative inline-flex items-center cursor-pointer">
  <input type="checkbox" class="sr-only peer" />
  <div class="w-9 h-5 bg-slate-200 rounded-full peer
              peer-checked:bg-indigo-600
              after:content-[''] after:absolute after:top-0.5 after:left-0.5
              after:bg-white after:rounded-full after:h-4 after:w-4
              after:transition-all peer-checked:after:translate-x-4" />
</label>
```
> Dùng màu `peer-checked:bg-rose-500` cho toggle "chặn website"

### 3.6 Circular Progress (SVG)
```
radius = (size - strokeWidth) / 2
circumference = 2 * π * radius
strokeDashoffset = circumference * (1 - percent)
rotate -90deg để bắt đầu từ đỉnh

Track: stroke white/20, fill none
Fill:  stroke white (hoặc màu app), strokeLinecap="round"
       đổi sang #f97316 (orange) khi percent > 80%
```

### 3.7 Stat Card (trang parent)
```
bg-white rounded-2xl p-5 shadow-sm border border-slate-100
  ├─ Icon container (w-11 h-11, rounded-xl, màu semantic)
  ├─ Trend badge (TrendingUp/Down, rose/emerald)
  ├─ Value (text-2xl font-bold slate-800)
  ├─ Label (text-sm slate-500)
  └─ Sub (text-xs slate-400)
```

### 3.8 Progress Bar
```
Track: h-2.5 bg-slate-100 rounded-full overflow-hidden
Fill:  h-full rounded-full
  - Normal:   bg-gradient-to-r from-indigo-500 to-purple-500
  - Warning:  bg-gradient-to-r from-amber-400 to-amber-500   (>80%)
  - Over:     bg-gradient-to-r from-rose-400 to-rose-600    (vượt giới hạn)
  - Battery:  emerald (>50%), amber (>20%), rose (≤20%)
```

### 3.9 Modal
```
Overlay: fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4
Card:    bg-white rounded-2xl p-6 w-full max-w-md shadow-2xl
Footer:  flex gap-3 mt-6
  - Nút hủy: border border-slate-200 text-slate-700
  - Nút xác nhận: bg-indigo-600 text-white
```

### 3.10 Badge / Status
```
Online:   bg-emerald-50 text-emerald-600 border-emerald-100 + dot animate-pulse bg-emerald-500
Offline:  bg-slate-50 text-slate-500 border-slate-200 + dot bg-slate-400
Warning:  bg-amber-50 text-amber-600 rounded-full
Danger:   bg-rose-50 text-rose-600 rounded-full
Request:  bg-indigo-50 text-indigo-600 rounded-full
Unread:   bg-rose-500 text-white rounded-full (badge đếm)
```

---

## 4. MOBILE — Child Pages

> Tất cả child pages: `min-h-screen`, gradient background, `max-w-sm mx-auto`  
> Font: toàn bộ text màu trắng hoặc white/70, white/60

---

### 4.1 LinkDevicePage — Liên kết thiết bị

**Route:** `/child/link-device`  
**Background:** `from-indigo-500 via-purple-600 to-pink-500`  
**3 trạng thái (step): `'input'` | `'waiting'` | `'success'`**

#### Header (dùng chung ở cả 3 trạng thái)
```
Row: [← Back button (w-9 h-9, bg-white/20, rounded-xl)] [Title + Subtitle]

Back button: ArrowLeft icon, navigate('/')
Title: "Liên kết thiết bị" — white, font-bold, text-lg
Sub:   "KidShield Child Monitor" — white/70, text-xs
```

---

#### Step: `input` — Nhập mã

```
[Hero]
  Icon container: w-24 h-24, bg-white/20 backdrop-blur, rounded-3xl, shadow-2xl
    Content: emoji 🔗, text-5xl
  Heading: "Liên kết với Phụ huynh" — text-2xl font-bold white
  Description: "Nhập mã 4 chữ số..." — white/70, text-sm

[Code Input Card]  ← Glass card
  Label: "Nhập mã liên kết" — white/80, text-sm, text-center
  4 ô input:
    - Mỗi ô: w-14 h-16 (56x64px)
    - bg-white/20, border-2 border-white/30, rounded-2xl
    - text-2xl font-bold white, text-center
    - focus: border-white/70
    - placeholder: "·"
    - type="text" inputMode="numeric" maxLength=1
    - Auto-focus next input khi nhập xong
  Nút "Xác nhận liên kết":
    - full width, py-3.5, bg-white text-indigo-700 font-bold, rounded-2xl
    - disabled khi chưa nhập đủ 4 số (opacity-50)
    - shadow-lg
  Footer text: "Mã sẽ hết hạn sau 10 phút" — white/60, text-xs, text-center

[Steps Card]  ← Glass card mờ hơn (bg-white/10)
  Heading: "Hướng dẫn liên kết:" — white/80, text-sm font-semibold
  4 steps:
    - Icon: emoji trong w-8 h-8 bg-white/20 rounded-xl
    - Title: white, text-sm font-medium
    - Description: white/60, text-xs
  Step data:
    1. 📱 "Tải ứng dụng" — Tải KidShield từ App Store hoặc Google Play
    2. 🚀 "Mở ứng dụng" — Mở và chọn "Liên kết thiết bị mới"
    3. 🔢 "Nhập mã hoặc quét QR" — Nhập mã 4 chữ số từ phụ huynh
    4. ✅ "Xác nhận từ phụ huynh" — Phụ huynh nhận thông báo xác nhận
```

---

#### Step: `waiting` — Đang chờ xác nhận

```
[Icon vòng tròn pulsing]
  Ngoài: w-28 h-28 bg-white/20 rounded-full animate-pulse
  Trong: w-20 h-20 bg-white/30 rounded-full
  Emoji: ⏳ text-5xl

[Text]
  Heading: "Đang chờ xác nhận..." — text-2xl font-bold white
  Sub: "Phụ huynh đang xem xét yêu cầu..." — white/70, text-sm

[Info Card]  ← Glass card
  Sub label: "Thiết bị đang liên kết" — white/80, text-sm
  Device name: "Samsung Galaxy A54" — white, font-bold, text-lg
  3 dots bouncing:
    - 3x div w-2 h-2 bg-white/60 rounded-full animate-bounce
    - animationDelay: 0s, 0.15s, 0.30s
```

---

#### Step: `success` — Thành công

```
[Icon checkmark]
  Ngoài: w-28 h-28 bg-emerald-400/30 rounded-full
  Trong: w-20 h-20 bg-emerald-400/40 rounded-full
  Icon: CheckCircle2 w-12 h-12 text-white

[Text]
  Heading: "Liên kết thành công! 🎉" — text-2xl font-bold white
  Sub: "Thiết bị đã được liên kết với tài khoản của Bố/Mẹ" — white/70

[Info Card]  ← Glass card
  3 rows (justify-between):
    "Trẻ em"        | "Minh Khoa"
    "Thiết bị"      | "Samsung Galaxy A54"
    "Giới hạn/ngày" | "3 giờ"
  Label: white/70, text-sm
  Value: white, font-semibold

[Nút "Bắt đầu sử dụng →"]
  full width, py-3.5, bg-white text-indigo-700 font-bold, rounded-2xl, shadow-lg
  navigate('/child/time-remaining')
```

---

### 4.2 TimeRemainingPage — Dashboard trẻ

**Route:** `/child/time-remaining`  
**Background:** `from-violet-600 via-indigo-600 to-blue-700`  
**max-w-sm mx-auto**

#### Top Bar
```
Row (justify-between, px-5 pt-6):
  Left:
    - Shield icon trong w-8 h-8 bg-white/20 rounded-xl
    - Text "KidShield" — white, font-bold, text-sm
  Right:
    - Dot w-2 h-2 bg-emerald-400 rounded-full animate-pulse
    - Text "Đang giám sát" — white/80, text-xs
```

#### Profile Row
```
Row (px-5 py-4, gap-3):
  Avatar: w-12 h-12 bg-white/20 backdrop-blur rounded-2xl, emoji 👦 text-2xl
  Info:
    Name: "Xin chào, Minh Khoa!" — white, font-bold
    Sub:  "iPad Air · Hôm nay, Thứ Ba" — white/60, text-xs
  Bell button (ml-auto): w-9 h-9 bg-white/20 rounded-xl, Bell icon white
```

#### Circular Progress
```
Vị trí: items-center justify-center, mb-6
SVG size: 220x220px
  rotate(-90deg) để bắt đầu từ đỉnh
  strokeWidth: 18px
  Track: stroke white/20 (#ffffff20), fill none
  Fill:  stroke white (#ffffff)
         stroke-linecap: round
         transition: stroke-dashoffset 0.5s ease
         → màu #f97316 (orange) nếu percent > 80%

Text ở giữa (absolute center):
  Label trên: "Thời gian còn lại" — white/60, text-xs
  Số chính:   "1h25m" — text-5xl font-extrabold white
  Label dưới: "/ 3 giờ hôm nay" — white/60, text-xs
  Badge:
    - Normal:  bg-white/20 text-white, px-3 py-1 rounded-full, text-xs font-semibold
    - Warning: bg-orange-400/30 text-orange-200 (khi còn < 30 phút)
    - Nội dung: "Đã dùng: 1h35m"

Data mẫu:
  totalLimit = 180 phút, totalUsed = 95 phút → remaining = 85 phút
```

#### Status Message
```
Normal (remaining >= 30):
  bg-white/10 border border-white/20 rounded-2xl px-5 py-3 mb-6
  text-white font-semibold text-sm: "🌟 Đang dùng tốt!"
  text-white/60 text-xs: "Tiếp tục giữ thói quen tốt bạn nhé!"

Warning (remaining < 30):
  bg-orange-400/20 border border-orange-300/30 rounded-2xl
  text-orange-200 font-semibold: "⚠️ Sắp hết giờ!"
  text-orange-200/70: "Còn {mins} phút, hãy chuẩn bị dừng lại nhé"
```

#### App Usage Card  ← Glass card
```
Header: "Ứng dụng hôm nay" — white/80, text-sm font-semibold

Mỗi app (space-y-3):
  Row: [emoji text-lg] [app name text-sm white flex-1] [time text-xs white/60]
  Progress bar (nếu không bị khóa):
    h-1.5 bg-white/20 rounded-full
    Fill: màu app (đổi sang #f97316 nếu >90%)

Data mẫu:
  ▶️ YouTube    | 45/60ph  | #ef4444 (red)
  🎮 Roblox     | 30/45ph  | #f97316 (orange)
  📚 Khan Acad  | 20/120ph | #10b981 (emerald)
  🎵 TikTok     | locked   | opacity-50, "🔒 Bị chặn" text-red-300

App bị khóa: opacity-50, hiện "Lock icon + Bị chặn" thay cho time
```

#### Action Buttons (grid 2 cột)
```
Nút "Xin thêm giờ":
  bg-white/20 backdrop-blur border border-white/20 rounded-2xl py-3
  Clock icon + text, white, text-sm font-semibold
  navigate('/child/request-time')

Nút "Trang chủ":
  bg-white text-indigo-700 rounded-2xl py-3, shadow-lg
  Home icon + text, text-sm font-semibold
```

#### Demo nav (nhỏ, ở dưới)
```
2 nút nhỏ: "🔒 Màn hình khóa" | "🔗 Liên kết TB"
  bg-white/10 text-white/70 rounded-xl text-xs py-2 border border-white/10
```

#### Footer decoration
```
5 Star icons w-4 h-4 text-white/30 fill-current, justify-center, pb-6
```

---

### 4.3 LockedPage — Màn hình khóa

**Route:** `/child/locked`  
**Background:** `from-slate-900 via-slate-800 to-indigo-950`  
**max-w-sm mx-auto, overflow-hidden**

#### Background Decoration
```
2 blur circles (absolute, pointer-events-none):
  - Top-left:     w-64 h-64, bg-indigo-500/10, rounded-full, blur-3xl
  - Bottom-right: w-64 h-64, bg-purple-500/10, rounded-full, blur-3xl
```

#### Clock (top)
```
pt-16, items-center
Đồng hồ: text-7xl font-extrabold white tracking-tight
  Format: "HH:MM" (giờ hiện tại, không giây)
Date: text-white/50 text-sm capitalize
  Format: new Date().toLocaleDateString('vi-VN', {weekday: 'long', day: 'numeric', month: 'long'})
```

#### Center — Lock Section
```
[Pulsing Lock Icon — 3 vòng tròn đồng tâm]
  Ngoài cùng: w-40 h-40 bg-rose-500/10 rounded-full animate-pulse
  Giữa:       w-28 h-28 bg-rose-500/20 rounded-full
  Trong:      w-20 h-20 bg-rose-500/30 rounded-full
  Icon:       Lock w-10 h-10 text-rose-300

[Text]
  Heading: "Đã hết giờ!" — text-3xl font-extrabold white
  Sub: "Bạn đã sử dụng hết 3 giờ được phép hôm nay." — white/60, text-base
  Sub2: "Nghỉ ngơi là điều quan trọng! 😊" — white/50, text-sm

[Countdown Card]  ← bg-white/10 backdrop-blur border border-white/20 rounded-3xl px-8 py-5
  Label: "Mở khóa lần tiếp theo" — white/60, text-xs, mb-2
  Timer: format HH:MM:SS — text-4xl font-extrabold text-indigo-300 tracking-widest
         (đếm ngược realtime bằng setInterval mỗi giây)
  Sub:   "06:00 sáng ngày mai" — white/40, text-xs
  Progress bar: h-1.5 bg-white/10, fill bg-gradient-to-r from-indigo-500 to-purple-500 (100%)

[Activities Card]  ← bg-gradient-to-r from-amber-500/20 to-orange-500/20, border-amber-400/30
  Heading: "💡 Bạn có thể làm gì bây giờ?" — amber-200, text-sm font-semibold
  4 suggestions (text-left):
    📚 Đọc sách hoặc làm bài tập
    🎨 Vẽ tranh hoặc tô màu
    🏃 Vận động, chơi ngoài trời
    💤 Nghỉ ngơi và ngủ đủ giấc
  Text: amber-200/70, text-xs

[Buttons]
  Nút "Xin thêm giờ từ Bố/Mẹ":
    full width, py-3.5, bg-indigo-600 hover:bg-indigo-500 text-white font-bold rounded-2xl
    MessageCircle icon + text, shadow-lg shadow-indigo-900/50
    navigate('/child/request-time')
  Nút "Về trang chủ":
    full width, py-3, bg-white/10 hover:bg-white/20, border border-white/20
    text-white/80 font-medium rounded-2xl, text-sm
    Home icon + text
```

#### Bottom
```
pb-8, text-center
"KidShield đang bảo vệ bạn 🛡️" — white/20, text-xs
```

---

### 4.4 RequestTimePage — Xin thêm giờ

**Route:** `/child/request-time`  
**Background:** `from-orange-400 via-pink-500 to-rose-600`  
**max-w-sm mx-auto**  
**3 trạng thái: `'form'` | `'sending'` | `'sent'`**

#### Header (dùng chung ở cả 3 trạng thái)
```
Row (px-5 pt-6 pb-4, gap-3):
  ← Back: w-9 h-9 bg-white/20 backdrop-blur rounded-xl, ArrowLeft icon white
  Title: "Xin thêm giờ" — white, font-bold, text-lg
  Sub:   "Gửi yêu cầu đến Bố/Mẹ" — white/70, text-xs
```

---

#### Step: `form`

```
[Illustration]
  Icon container: w-24 h-24 bg-white/20 backdrop-blur rounded-3xl, shadow-xl
    Emoji: 🙏 text-5xl
  Heading: "Nhờ Bố/Mẹ giúp!" — white font-bold text-xl
  Sub: "Hãy chọn lý do và thời gian phù hợp" — white/70 text-sm

[Reason Card]  ← Glass card
  Header: "📋 Lý do xin thêm giờ?" — white font-semibold
  Grid 2 cột (grid-cols-2 gap-2):
    6 nút reason (p-3 rounded-2xl border-2 text-sm transition):
      Unselected: bg-white/10 text-white border-white/20
      Selected:   bg-white text-orange-600 border-white shadow-lg
      Layout mỗi nút: [emoji text-xl] [label text-xs font-medium leading-tight]
  Data:
    📚 Đang học bài
    🎬 Xem phim chưa xong
    👫 Chơi với bạn bè
    🎉 Cuối tuần / ngày nghỉ
    🎓 Xem video học tập
    ✍️ Lý do khác

[Time Card]  ← Glass card
  Header: "⏱ Muốn xin thêm bao lâu?" — white font-semibold
  Grid 2 cột (grid-cols-2 gap-2):
    4 nút time (py-3 rounded-2xl border-2 text-sm font-bold transition):
      Unselected: bg-white/10 text-white border-white/20
      Selected:   bg-white text-orange-600 border-white shadow-lg scale-105
      Layout: [emoji text-xl] [label]
  Data:
    ⏱ 15 phút (value: 15)
    ⏰ 30 phút (value: 30)
    🕐 1 giờ   (value: 60)
    🕑 2 giờ   (value: 120)

[Note Card]  ← Glass card
  Header: "💬 Lời nhắn cho Bố/Mẹ (tùy chọn)" — white font-semibold
  Textarea:
    rows=3, resize-none
    bg-white/20 border border-white/30 rounded-2xl px-4 py-3
    text-white placeholder:text-white/40 text-sm
    focus: border-white/60
    placeholder: "Ví dụ: Con đang xem video toán học..."

[Submit Button]
  full width, py-4, bg-white text-orange-600 font-extrabold rounded-2xl text-base
  Send icon + "Gửi yêu cầu cho Bố/Mẹ"
  disabled khi chưa chọn reason hoặc time: opacity-50
  shadow-2xl shadow-orange-900/30

[Previous Requests]  ← bg-white/10 rounded-3xl p-4 border border-white/10
  Header: "Yêu cầu gần đây:" — white/80 text-xs font-semibold
  Mỗi row (justify-between):
    Left:  "{emoji} Xin thêm {time}" — white/70 text-xs
    Right: [date text-white/40] [badge]
  Badge:
    Approved: bg-emerald-400/20 text-emerald-300 rounded-full
    Rejected: bg-rose-400/20 text-rose-300 rounded-full
  Data mẫu:
    ✅ 30 phút · 16/03 · Được duyệt
    ❌ 1 giờ   · 15/03 · Bị từ chối
    ✅ 15 phút · 14/03 · Được duyệt
```

---

#### Step: `sending`

```
min-h-[60vh] flex flex-col items-center justify-center gap-6

[Spinner]
  Ngoài: w-32 h-32 rounded-full bg-white/20 animate-spin (duration: 3s)
  Trong: w-28 h-28 rounded-full bg-white/10
  Icon:  Send w-12 h-12 text-white

[Text]
  "Đang gửi yêu cầu..." — white font-bold text-xl
  "Bố/Mẹ sẽ nhận được thông báo ngay" — white/70 text-sm

[3 bouncing dots]
  3x div w-2.5 h-2.5 bg-white/60 rounded-full animate-bounce
  delay: 0s, 0.2s, 0.4s
```

---

#### Step: `sent`

```
min-h-[60vh] flex flex-col items-center justify-center gap-6

[Checkmark icon]
  Ngoài: w-32 h-32 rounded-full bg-white/20
  Trong: w-24 h-24 rounded-full bg-white/20
  Icon:  CheckCircle2 w-14 h-14 text-white

[Text]
  "Đã gửi! 🎉" — white font-bold text-2xl
  "Yêu cầu xin thêm {X} phút đã được gửi đến Bố/Mẹ. Hãy chờ một chút nhé!"

[Summary Card]  ← Glass card
  Row (items-center gap-3):
    Icon: 🙏 trong w-10 h-10 bg-white/20 rounded-xl
    Info: "Yêu cầu của bạn" / "Đang chờ phê duyệt" — white, white/60
    Badge "Đang chờ": bg-amber-400/20 text-amber-200 rounded-full text-xs px-3 py-1
  Divider: border-t border-white/10 pt-3
  2 rows (justify-between text-xs):
    "Thời gian xin" | "{X} phút"
    "Lý do"         | "{reason name}"
  Label: white/60, Value: white font-semibold

[Bottom section]
  Info card: bg-white/10 rounded-2xl p-4 text-center
    "💡 Mẹo nhỏ: Trong khi chờ, bạn có thể đọc sách hoặc nghỉ ngơi!"
    white/60 text-sm
  Nút "Về màn hình chính":
    full width, py-3.5, bg-white text-orange-600 font-bold rounded-2xl
    navigate('/child/time-remaining')
```

---

## 5. PARENT — Layout chung

**File:** `ParentLayout.tsx`  
**Cấu trúc:** Sidebar (fixed) + Header + Main content  

### Sidebar (264px wide)

```
Background: bg-slate-900 (#0F172A)
Position:   fixed left-0 top-0 h-full w-64 z-30
Mobile:     translate-x-[-100%] → translate-x-0 (transition-transform duration-300)
            + overlay bg-black/50 khi mở

[Logo section] — px-5 py-5 border-b border-white/10
  Icon: w-9 h-9 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-xl
        Shield icon w-5 h-5 text-white
  Text: "KidShield" — white font-bold text-lg
        "Parent Dashboard" — indigo-400 text-xs
  X button (mobile): text-slate-500 hover:text-white

[Profile Quick View] — px-4 py-4 border-b border-white/10
  Container: px-3 py-3 bg-white/5 rounded-xl
  Avatar: w-9 h-9 bg-gradient-to-br from-indigo-400 to-purple-500 rounded-full
          Initials "NA" — white font-bold text-sm
  Name:   text-white text-sm font-medium (truncate)
  Sub:    "2 trẻ em · 4 thiết bị" — slate-400 text-xs

[Nav Items] — px-3 py-4 space-y-1 overflow-y-auto flex-1
  Mỗi item: flex items-center gap-3 px-3 py-2.5 rounded-xl transition-all
    Active:   bg-indigo-600 text-white shadow-lg shadow-indigo-900/50
    Inactive: text-slate-400 hover:bg-white/10 hover:text-white
    Badge:    ml-auto bg-rose-500 text-white text-xs rounded-full w-5 h-5 (chỉ khi inactive)

  Nav Items:
    LayoutDashboard  "Tổng quan"          /parent
    Users            "Hồ sơ con"          /parent/children
    Smartphone       "Thiết bị"           /parent/devices
    Clock            "Giới hạn thời gian" /parent/time-limits
    Globe            "Website bị chặn"    /parent/blocked-sites
    Bell             "Thông báo"          /parent/notifications  [badge: 3]
    History          "Lịch sử hoạt động"  /parent/history
    BarChart2        "Báo cáo thống kê"   /parent/reports

[Bottom Actions] — px-3 py-4 border-t border-white/10 space-y-1
  Settings: text-slate-400 hover:bg-white/10 hover:text-white
  Logout:   text-slate-400 hover:bg-rose-500/10 hover:text-rose-400
```

### Header (64px high)

```
Background: bg-white border-b border-slate-200
Height:     h-16 px-4 lg:px-6

[Mobile menu button]: Menu icon, text-slate-500 (lg:hidden)

[Search bar] (hidden on mobile, flex-1 max-w-md):
  bg-slate-100 rounded-xl pl-9 pr-4 py-2
  Search icon absolute left-3, text-slate-400 w-4 h-4
  placeholder "Tìm kiếm..."
  focus: ring-2 ring-indigo-500 bg-white

[Right side] (ml-auto flex gap-3):
  Bell button:
    text-slate-500, p-2
    Red dot: absolute top-1 right-1 w-2 h-2 bg-rose-500 rounded-full
  Profile dropdown:
    Avatar: w-8 h-8 gradient rounded-full, initials "NA"
    Name + role (hidden on mobile)
    ChevronDown icon
    Dropdown: bg-white rounded-xl shadow-lg border
      "Hồ sơ cá nhân" | "Cài đặt tài khoản" | --- | "Đăng xuất" (rose)
```

---

## 6. PARENT — LoginPage

**Route:** `/login`  
**Background:** `from-slate-900 via-indigo-950 to-purple-950`

### Layout: 2 cột (lg:flex)

#### Left Panel (lg:w-1/2, ẩn trên mobile)
```
Background: from-indigo-600 to-purple-700
Decoration: 3 circles trắng opacity-10 (absolute, sizes: 256px, 192px, 128px)

[← Về trang chủ] (indigo-200 hover:text-white)

[Logo]:
  Shield icon trong w-16 h-16 bg-white/20 rounded-2xl
  "KidShield" — text-4xl font-extrabold white
  "Bảo vệ con yêu của bạn" — indigo-200 text-sm

[Tagline]:
  "Quản lý thời gian / sử dụng thiết bị / của trẻ em"
  text-3xl font-bold white

[Feature list] (4 items, gap-3):
  Bullet: w-5 h-5 bg-white/30 rounded-full + w-2 h-2 bg-white inner
  Text: indigo-100, text-sm
  - Đặt giới hạn thời gian linh hoạt
  - Chặn nội dung không phù hợp
  - Nhận thông báo tức thời
  - Báo cáo chi tiết theo ngày/tuần

[Footer]: "© 2025 KidShield" — indigo-300 text-xs
```

#### Right Panel (form)
```
flex-1, flex items-center justify-center p-6

[Mobile logo] (lg:hidden):
  Shield icon trong w-10 h-10 gradient rounded-xl
  "KidShield" — white font-bold text-xl

[Tab switcher]:
  bg-white/10 rounded-2xl p-1 flex border border-white/10
  Nút active:   bg-white text-indigo-900 shadow rounded-xl py-2.5
  Nút inactive: text-slate-300 hover:text-white
  Tabs: "Đăng nhập" | "Đăng ký"
```

##### Tab: Đăng nhập
```
Heading: "Chào mừng trở lại!" — text-2xl font-bold white
Sub: "Đăng nhập để quản lý tài khoản" — slate-400 text-sm

[Input: Email]
  Label: text-sm text-slate-300
  Input: pl-11 (Mail icon prefix), bg-white/10 border border-white/20 rounded-xl
         text-white placeholder:text-slate-500
         focus: border-indigo-400 bg-white/15

[Input: Mật khẩu]
  Label: text-sm text-slate-300
  Input: pl-11 (Lock icon prefix), pr-12 (Eye/EyeOff toggle button)
  Toggle password visibility: Eye / EyeOff icon right-3

[Row: Checkbox "Ghi nhớ" + Link "Quên mật khẩu?"]
  Checkbox: accent-indigo-500
  Link: text-sm text-indigo-400

[Nút Đăng nhập]:
  full width, py-3, gradient from-indigo-600 to-purple-600, rounded-xl font-semibold
  shadow-lg shadow-indigo-900/50
  navigate('/parent')

[Divider]: "hoặc tiếp tục với" — text-xs text-slate-500

[Social login] (grid 2 cột):
  bg-white/10 border border-white/20 rounded-xl py-2.5
  "🌐 Google" | "📘 Facebook"
```

##### Tab: Đăng ký
```
Heading: "Tạo tài khoản mới" — text-2xl font-bold white

Fields:
  Grid 2 cột: [Họ] [Tên]
  Email (Mail icon prefix)
  Số điện thoại (Phone icon prefix)
  Mật khẩu (Lock icon + Eye toggle)
  Xác nhận mật khẩu (Lock icon + Eye toggle)
  Checkbox: "Tôi đồng ý với Điều khoản dịch vụ và Chính sách bảo mật"

Nút "Tạo tài khoản": full width, gradient, rounded-xl
```

---

## 7. PARENT — DashboardPage

**Route:** `/parent`  
**Background:** slate-50  
**Padding:** `p-4 lg:p-6`

### Page Header
```
Row (justify-between):
  Left:
    "Tổng quan" — text-2xl font-bold slate-800
    Date: "Thứ Ba, 17 tháng 3, 2025" — slate-500 text-sm
  Right:
    Bell nút: bg-indigo-600 text-white rounded-xl px-4 py-2 text-sm
              "3 cảnh báo mới" (ẩn trên mobile với hidden sm:inline)
```

### Stats Grid (2 cột mobile, 4 cột desktop)
```
4 StatCard components:
  [Clock]         "Tổng thời gian hôm nay" | "6h 25m" | bg-indigo-50/text-indigo-600  | trend +12%
  [Users]         "Trẻ đang theo dõi"      | "2"      | bg-emerald-50/text-emerald-600 | –
  [Smartphone]    "Thiết bị đang kết nối"  | "3/4"    | bg-amber-50/text-amber-600    | –
  [AlertTriangle] "Cảnh báo hôm nay"       | "4"      | bg-rose-50/text-rose-600      | trend -5%
```

### StatCard layout
```
bg-white rounded-2xl p-5 shadow-sm border border-slate-100
  Row (justify-between mb-4):
    Icon container: w-11 h-11 rounded-xl, màu semantic
    Trend badge (nếu có): flex items-center gap-1 text-xs px-2 py-1 rounded-full
      Tăng: bg-rose-50 text-rose-600 + TrendingUp icon
      Giảm: bg-emerald-50 text-emerald-600 + TrendingDown icon
  Value: text-2xl font-bold slate-800
  Label: text-sm slate-500
  Sub:   text-xs slate-400
```

### Main Grid (1 cột mobile, 3 cột desktop)

#### Chart Section (lg:col-span-2)
```
bg-white rounded-2xl p-5 shadow-sm border border-slate-100
Header row (justify-between mb-5):
  "Thời gian sử dụng tuần này" — font-semibold slate-800
  "Đơn vị: giờ/ngày" — text-xs slate-500
  Select: "7 ngày qua" / "30 ngày" — border rounded-lg px-2 py-1

Recharts AreaChart (height: 220px):
  CartesianGrid: strokeDasharray="3 3" stroke="#f1f5f9"
  XAxis/YAxis: axisLine=false tickLine=false, tick fill #94a3b8 size 12
  Tooltip: borderRadius 12px, shadow
  Area Khoa: stroke #6366f1, fill gradient indigo opacity 0→0.3
  Area Linh: stroke #ec4899, fill gradient pink opacity 0→0.3
  strokeWidth: 2
Data: T2–CN, 2 series (Khoa + Linh), unit: giờ/ngày
```

#### Alerts Section
```
bg-white rounded-2xl p-5 shadow-sm border border-slate-100
Header: "Cảnh báo gần đây" + Link "Xem tất cả"

Mỗi alert (space-y-3):
  Container (flex items-start gap-3 p-3 rounded-xl border):
    Types:
      warning: bg-amber-50 border-amber-100
      danger:  bg-rose-50 border-rose-100
      request: bg-indigo-50 border-indigo-100
      info:    bg-slate-50 border-slate-100
    [emoji text-lg] [content]
    Content:
      Row: [childName text-xs font-semibold slate-700] [time text-xs slate-400]
      Message: text-xs slate-600
      (nếu type=request): 2 nút "Chấp nhận" (indigo-600) + "Từ chối" (white)

Data mẫu:
  ⚠️ Linh · 5 phút trước · "Vượt giới hạn thời gian 30 phút" · warning
  🎮 Khoa · 20 phút trước · "Đang sử dụng YouTube 2 giờ liên tục" · info
  🙏 Linh · 1 giờ trước · "Yêu cầu thêm 30 phút sử dụng" · request
  🌐 Khoa · 2 giờ trước · "Cố gắng truy cập trang bị chặn" · danger
```

### Children Status Section
```
bg-white rounded-2xl p-5 shadow-sm border border-slate-100
Header: "Trạng thái hôm nay" + Link "Quản lý >"

Grid 2 cột (md:grid-cols-2 gap-4):
Mỗi child card (border border-slate-100 rounded-2xl p-4):
  Row (justify-between mb-4):
    Left: [Avatar emoji trong 48px container] [Name + Age]
      Container: w-12 h-12 rounded-2xl (blue-100 / pink-100)
    Right: [Online/Offline badge] [Vượt giới hạn badge nếu over]
  
  Usage row (flex justify-between text-xs):
    "Đang dùng: {device} · {app}"
    "{used}h{m} / {limit}h{m}" (đỏ nếu over)
  Progress bar h-2.5 (indigo → amber nếu >80% → rose nếu over)
  
  3 action buttons (flex gap-2):
    "Chi tiết" — bg-slate-100
    "Cài đặt" — bg-indigo-50 text-indigo-700
    "Khóa ngay" — bg-rose-50 text-rose-700 (chỉ khi over)
```

### Quick Actions (grid 2 cột mobile, 4 cột desktop)
```
4 action cards (bg-white border-2 rounded-2xl p-4 text-left):
  Hover: đổi border + bg màu theo type
  Layout: [emoji text-2xl mb-2] [label text-sm font-semibold] [desc text-xs slate-400]
  
  ⏱️ "Thêm 30 phút" · "Cho tất cả trẻ"    · border-indigo-100 hover:bg-indigo-50
  🔒 "Khóa ngay"    · "Tất cả thiết bị"   · border-rose-100 hover:bg-rose-50
  📊 "Xem báo cáo"  · "Tuần này"          · border-emerald-100 hover:bg-emerald-50
  ⚙️ "Cài đặt nhanh"· "Chế độ học tập"   · border-amber-100 hover:bg-amber-50
```

---

## 8. PARENT — ChildrenPage

**Route:** `/parent/children`

### Header
```
"Hồ sơ con" + Sub: "Quản lý thông tin và quy tắc cho từng trẻ"
Nút "Thêm trẻ" (indigo-600, Plus icon)
```

### Children Grid (md:grid-cols-2 gap-6)

#### Child Card
```
bg-white rounded-2xl shadow-sm border border-slate-100 overflow-hidden

[Card Header] — bg-gradient-to-br {child.color} p-6
  child 1: from-blue-400 to-indigo-500
  child 2: from-pink-400 to-rose-500
  
  Row:
    Left:
      Avatar: w-16 h-16 bg-white/20 rounded-2xl, emoji text-4xl
      Info:
        Name: text-xl font-bold white
        Age + Grade: white/80 text-sm
        School: white/70 text-xs
    Right:
      Online badge: bg-white/20 text-white backdrop-blur rounded-full text-xs
      MoreVertical button: text-white/70
  
  Progress Bar (mt-4):
    Container: bg-white/10 backdrop-blur rounded-xl p-3
    Row: "Thời gian hôm nay" | "{used}/{limit}" (rose-200 nếu over)
    Bar: h-2 bg-white/20 → fill white (rose-300 nếu over)
    Over message: "⚠️ Đã vượt giới hạn {X} phút" — rose-200 text-xs

[Card Body] — p-5 space-y-4
  
  [Current Status] — bg-slate-50 rounded-xl p-3 flex gap-3
    Icon: Smartphone trong w-8 h-8 bg-indigo-100 rounded-lg
    Info: "Đang sử dụng" (text-xs slate-500) + app name (text-sm font-medium slate-800)
    Time: ml-auto text-xs slate-400
  
  [Restrictions]
    Header: "Quy tắc đang áp dụng" — text-xs font-semibold slate-600
    List (space-y-1.5):
      Mỗi rule: dot w-1.5 h-1.5 bg-indigo-500 + text text-xs slate-600
    Data mẫu: "YouTube (30ph/ngày)", "Game (1h/ngày)", "Giờ ngủ: 21:00"
  
  [Stats] — grid 3 cột, border-t pt-3
    Số thiết bị | TB/ngày (phút) | Trạng thái (Vi phạm/Tuân thủ)
    middle: border-x border-slate-100
    Tuân thủ: emerald-600, Vi phạm: rose-600
  
  [Actions] — flex gap-2
    "Cài đặt"  — bg-indigo-50 text-indigo-700 Settings icon
    "Thời gian"— bg-slate-100 text-slate-700 Clock icon
    "Lịch sử"  — bg-slate-100 text-slate-700 ChevronRight icon
    Mỗi nút: rounded-xl text-xs font-medium py-2 flex-1
```

#### Add Child Card (dashed border)
```
border-2 border-dashed border-slate-200 rounded-2xl p-8
hover: border-indigo-300 bg-indigo-50/50

Icon: Plus trong w-14 h-14 bg-indigo-50 rounded-2xl (hover:bg-indigo-100)
Text: "Thêm hồ sơ con" + "Quản lý thiết bị cho thêm trẻ"
```

### Add Child Modal
```
[Avatar editor]
  w-20 h-20 gradient rounded-2xl, emoji 👶 text-4xl
  Plus button: absolute -bottom-1 -right-1 w-7 h-7 bg-indigo-600 rounded-full

[Fields]
  Họ và tên (text input)
  Biệt danh (text input)
  Grid 2: [Tuổi (number)] [Giới tính (select: Nam/Nữ)]
  Giới hạn thời gian: [number input w-20] + text "giờ / ngày"

[Footer]: Hủy (border) + Tạo hồ sơ (indigo-600)
```

---

## 9. PARENT — DevicesPage

**Route:** `/parent/devices`

### Header
```
"Quản lý thiết bị" + "4 thiết bị · 2 đang hoạt động"
Nút "Liên kết thiết bị" (indigo-600, Plus icon)
```

### Stats (grid 2/4)
```
4 cards (bg-white rounded-2xl p-4):
  [Smartphone] "Tổng thiết bị"       | "4"     | bg-indigo-50
  [Wifi]       "Đang online"         | "2"     | bg-emerald-50
  [WifiOff]    "Đang offline"        | "2"     | bg-slate-100
  [Settings]   "TB thời gian/TB"     | "2h 45m"| bg-amber-50
```

### Device Cards (space-y-4)

```
Mỗi card: bg-white rounded-2xl shadow-sm border overflow-hidden

[Card Body] — p-5
  Row (items-start gap-4):
    Device Icon (w-14 h-14 rounded-2xl border-2, màu riêng):
      iPad:         bg-blue-50  text-blue-600  border-blue-100
      Samsung:      bg-pink-50  text-pink-600  border-pink-100
      Laptop/TV:    bg-slate-50 text-slate-500 border-slate-100
      Icon: Tablet / Smartphone / Laptop / Monitor (w-7 h-7)
    
    Info (flex-1):
      Row (items-start justify-between):
        Name: font-semibold slate-800
        Type + OS: text-xs slate-500
        Status badge:
          Online:  bg-emerald-50 text-emerald-600 border-emerald-100
                   dot animate-pulse bg-emerald-500
          Offline: bg-slate-50 text-slate-500 bg-slate-200
                   dot bg-slate-400
        MoreVertical button
      
      Info Grid (2/4 cột, mt-4 gap-3):
        4 cells: bg-slate-50 rounded-xl p-2.5
          "Liên kết với" | child name
          "Đang dùng"    | app name
          "TG hôm nay"   | screen time
          "Hoạt động cuối"| last active
      
      Battery (nếu có, mt-3):
        Row: [Battery icon + "{X}%"] [progress bar flex-1] [Wifi + IP]
        Bar: emerald (>50%), amber (>20%), rose (≤20%)

[Card Footer] — px-5 pb-4 pt-3 border-t border-slate-50 flex gap-2
  "Cài đặt"     — bg-indigo-50 text-indigo-700  Settings icon
  "Đổi liên kết"— bg-slate-100 text-slate-700   Link2 icon
  "Khóa màn hình"— bg-amber-50 text-amber-700   (chỉ khi online)
  "Hủy liên kết"— bg-rose-50 text-rose-600 ml-auto Trash2 icon
```

### Link Device Modal
```
Title: "Liên kết thiết bị mới"
Sub: "Cài đặt ứng dụng KidShield trên thiết bị của trẻ..."

[Code Display Card] — bg-indigo-50 rounded-2xl p-6 text-center
  Label: "Mã liên kết của bạn" — text-xs text-indigo-600
  Code:  "4A9K" — text-5xl font-extrabold tracking-widest text-indigo-700
  Sub:   "Hết hạn sau: 10:00 phút"
  Progress bar: h-1.5 bg-indigo-200, fill bg-indigo-600

[Divider]: "— hoặc —"

[QR Code] — bg-slate-900 rounded-2xl p-6
  7x7 grid (49 cells, w-3 h-3 each): random white/slate-900 pattern
  Label: "Quét mã QR bằng ứng dụng" — white text-xs

[Footer]: Hủy + Làm mới mã
```

---

## 10. PARENT — TimeLimitsPage

**Route:** `/parent/time-limits`

### Header
```
"Cài đặt giới hạn thời gian" + "Thiết lập quy tắc sử dụng cho từng trẻ"
Nút "Lưu thay đổi" (Save icon, indigo-600)
```

### Child Selector
```
bg-white rounded-2xl p-4 shadow-sm
Label: "Chọn trẻ để cài đặt:"

2 child buttons (flex gap-3):
  Container: px-4 py-3 rounded-xl border-2 transition
    Selected:   border-indigo-500 bg-indigo-50
    Unselected: border-slate-200 hover:border-indigo-200
  Content: [emoji text-2xl] [Name text-sm font-semibold + Age text-xs]
```

### TimeSlider Component
```
flex items-center gap-3
  range input (flex-1, accent-indigo-600, min=0 max=240 step=15)
  Value display: w-20 text-sm font-semibold text-indigo-700 bg-indigo-50 px-3 py-1 rounded-lg
    0    → "Khóa"
    <60  → "{X}ph"
    ≥60  → "{X}h{Y}ph"
```

### Two-column grid (lg:grid-cols-2)

#### Daily Limit Card
```
bg-white rounded-2xl p-5 shadow-sm
Icon: Clock trong w-10 h-10 bg-indigo-50 rounded-xl
"Giới hạn tổng/ngày"
"Tổng thời gian sử dụng tất cả ứng dụng"

TimeSlider

Preset buttons (grid 3 cột, 6 nút):
  1h / 2h / 3h / 4h / 5h / Khóa
  Selected: bg-indigo-600 text-white border-indigo-600
  Others:   border-slate-200 text-slate-600 hover:border-indigo-300
  py-1.5 text-xs rounded-lg border
```

#### Bedtime / Schedule Card
```
bg-white rounded-2xl p-5 shadow-sm
Icon: Moon trong w-10 h-10 bg-indigo-50 rounded-xl
"Chế độ giờ giấc"
"Tự động khóa thiết bị theo lịch"

3 schedule rows (space-y-4):
  bg-slate-50 rounded-xl p-3 flex items-center gap-3
  [Icon bg-white rounded-lg border] [Label + Time range] [Toggle switch]
  
  Data:
    Moon     "Giờ ngủ (Tự động khóa)"    21:30 – 06:30  ON
    BookOpen "Giờ học (Chỉ học tập)"     14:00 – 17:00  ON
    Sun      "Cuối tuần (Nới lỏng)"      07:00 – 22:00  OFF
```

### Per-App Limits
```
bg-white rounded-2xl p-5
Header: "Giới hạn theo ứng dụng" + "Thêm ứng dụng" link

Mỗi app (space-y-4):
  Container (border rounded-xl p-4):
    Enabled:  màu riêng (red-50, pink-50, orange-50, blue-50, emerald-50, amber-50)
    Disabled: bg-slate-50 border-slate-100 opacity-60
  
  Row: [emoji text-2xl] [Name + Category] [Toggle switch]
  TimeSlider (chỉ hiện khi enabled)

Data:
  ▶️ YouTube     · Giải trí     · 60ph  · ON   · bg-red-50
  🎵 TikTok      · Mạng xã hội · 30ph  · ON   · bg-pink-50
  🎮 Roblox      · Game        · 45ph  · ON   · bg-orange-50
  📘 Facebook    · Mạng xã hội · 30ph  · OFF  · bg-blue-50
  📚 Khan Academy· Học tập     · 120ph · ON   · bg-emerald-50
  ⛏️ Minecraft   · Game        · 60ph  · ON   · bg-amber-50
```

### Weekly Schedule
```
bg-white rounded-2xl p-5
Header: "Lịch tuần chi tiết" + "Thêm lịch" link

Mỗi schedule (space-y-3):
  bg-slate-50 rounded-xl p-3 flex items-center gap-4
  [Name + Days badge + Time range] [Toggle]
  Days badge: bg-indigo-100 text-indigo-700 rounded-full text-xs px-2 py-0.5

Data:
  "Ngày học"  T2-T6  06:00–21:30 Giới hạn: 2h   ON
  "Cuối tuần" T7-CN  07:00–22:00 Giới hạn: 3h   ON
  "Giờ học"   T2-T6  14:00–17:00 Giới hạn: 0h   ON
```

---

## 11. PARENT — BlockedSitesPage

**Route:** `/parent/blocked-sites`

### Header
```
"Quản lý website bị chặn" + "Kiểm soát nội dung trẻ có thể truy cập"
Nút "Thêm website" (indigo-600, Plus icon)
```

### Stats (3 cột)
```
Đang chặn: bg-rose-50 border-rose-100  · text-rose-600  · "{N} Danh mục bị chặn"
Tùy chỉnh: bg-indigo-50 border-indigo  · text-indigo-600· "{N} Website tùy chỉnh"
Cho phép:  bg-emerald-50 border-emerald· text-emerald-600· "{N} Website cho phép"
Text-3xl font-bold + text-sm
```

### Tab Switcher
```
bg-slate-100 rounded-xl p-1 flex w-fit
Tabs: "Danh mục" | "Tùy chỉnh" | "Cho phép"
Active: bg-white text-slate-800 shadow-sm rounded-lg
```

### Search Bar
```
max-w-md, Search icon prefix, bg-white border border-slate-200 rounded-xl
```

#### Tab: Danh mục
```
Grid 2 cột (md:grid-cols-2 gap-4):
Mỗi category card (bg-white border-2 rounded-2xl p-4):
  Blocked: màu riêng (rose/orange/amber)
  Allowed: border-slate-100
  
  Row: [emoji text-3xl] [content] 
  Content:
    Row: [Name font-semibold] [Toggle switch — peer-checked:bg-rose-500]
    Description: text-xs slate-500
    Row: [count text-xs slate-400] [badge "🔒 Đang chặn" / "✅ Cho phép"]

Data (6 categories):
  🔞 Nội dung người lớn  · blocked  · rose
  💀 Bạo lực & Kinh dị   · blocked  · orange
  🎰 Cờ bạc              · blocked  · amber
  👥 Mạng xã hội         · allowed  · blue
  🎮 Trò chơi online     · allowed  · purple
  🛒 Mua sắm online      · allowed  · teal
```

#### Tab: Tùy chỉnh (Custom Blocked)
```
bg-white rounded-2xl overflow-hidden divide-y divide-slate-50

Mỗi row (flex items-center gap-4 p-4 hover:bg-slate-50):
  Globe icon trong w-10 h-10 bg-rose-50 border-rose-100 rounded-xl
  Info: [URL font-semibold] + [reason · appliedTo]
  Right: [date text-slate-400] [badge "Đang chặn"] [Trash2 button]
```

#### Tab: Cho phép (Whitelist)
```
Giống custom nhưng icon màu emerald, badge "✅ Cho phép"
```

### Add Website Modal
```
Fields:
  "Địa chỉ website" (text, placeholder: "vd: tiktok.com hoặc *.tiktok.com")
  "Lý do" (text)
  "Áp dụng cho" (select: Cả 2 trẻ / Minh Khoa / Thị Linh)
  "Loại":
    Grid 2 nút: [🚫 Chặn (rose-600, white)] [✅ Cho phép (white, border)]
Footer: Hủy + Thêm
```

---

## 12. PARENT — NotificationsPage

**Route:** `/parent/notifications`

### Header
```
Row:
  "Thông báo" + badge "{N} mới" (bg-rose-500 text-white rounded-full text-xs)
  Sub: "Cập nhật từ các thiết bị của con"
  Nút "Đọc tất cả" (Check icon, border border-slate-200)
```

### Filters (2 filter groups)
```
Group 1: "Tất cả" | "Chưa đọc ({N})" | "Cảnh báo" | "Yêu cầu"
Group 2: "Tất cả" | "Minh Khoa" | "Thị Linh"
Style: bg-slate-100 rounded-xl p-1
  Active: bg-white text-slate-800 shadow-sm rounded-lg px-3 py-1.5 text-xs font-medium
```

### Notification List

```
Mỗi notification (flex items-start gap-4 p-4 rounded-2xl border-2):
  Unread: màu theo type (warning=amber, danger=rose, request=indigo, info=blue, success=emerald)
  Read:   bg-white border-slate-100

  [Icon section]
    w-12 h-12 rounded-2xl, emoji text-2xl
    Dot badge (-top-1 -right-1 w-3 h-3, border-2 border-white) nếu chưa đọc
  
  [Content]
    Row:
      Title: text-sm font-semibold (slate-900 unread, slate-700 read)
      [childName · time]
      [Check button] [Trash button]
    Description: text-xs slate-600 mt-1.5

  [Action buttons — chỉ cho type=request, chưa đọc]
    "Chấp nhận +30 phút" — bg-indigo-600 text-white, CheckCircle2 icon
    "Từ chối" — bg-white border text-slate-600

TypeConfig:
  warning: bg-amber-50  border-amber-100  dot-bg-amber-500
  danger:  bg-rose-50   border-rose-100   dot-bg-rose-500
  request: bg-indigo-50 border-indigo-100 dot-bg-indigo-500
  info:    bg-blue-50   border-blue-100   dot-bg-blue-400
  success: bg-emerald-50 border-emerald-100 dot-bg-emerald-500
```

---

## 13. PARENT — HistoryPage

**Route:** `/parent/history`

### Header
```
"Lịch sử hoạt động" + Sub
Date picker: [Calendar icon] [selectedDate] [ChevronDown] — bg-white border rounded-xl
```

### Child Filter
```
3 nút (flex gap-2):
  Selected: bg-indigo-600 text-white border-indigo-600 shadow-md
  Others:   bg-white text-slate-600 border-slate-200
  Content: [emoji] [label]
  "👨‍👩‍👧‍👦 Tất cả" | "👦 Minh Khoa" | "👧 Thị Linh"
```

### Weekly Overview (Bar Chart custom)
```
bg-white rounded-2xl p-5
"Tổng quan 7 ngày"

Custom bar chart (h-36 flex items-end gap-2):
  7 columns (flex-1 each):
    Nội dung: [bar pair] [day label] [date label]
    Khoa bar: bg-indigo-200 (normal) / bg-indigo-500 (today) rounded-t-lg
    Linh bar: bg-pink-200  (normal) / bg-pink-500  (today) rounded-t-lg
    Height: (value / maxVal) * 100 %

Legend: dot w-3 h-3 + label text-xs
```

### Activity Timeline
```
bg-white rounded-2xl shadow-sm overflow-hidden

Header: "Hoạt động hôm nay" | "{N} hoạt động"

Mỗi activity (flex items-center gap-4 px-5 py-4 hover:bg-slate-50 divide-y):
  [Time w-14 text-right text-sm font-semibold]
  [Timeline: dot + line]
    dot: w-3 h-3 rounded-full bg-indigo-400
    line: w-0.5 h-8 bg-slate-100 mt-1
  [App Icon w-10 h-10 rounded-xl border text-xl]
  [Info flex-1]:
    Row: [App name text-sm font-semibold] [Clock icon + duration text-xs]
    Sub: [childName] · [Smartphone icon + deviceName] · [category badge]
  Category badge: text-xs px-2 py-0.5 rounded-full (màu theo category)

Footer: "Tổng: {X} phút" | "Xuất báo cáo →" link
```

---

## 14. PARENT — ReportsPage

**Route:** `/parent/reports`

### Header
```
"Báo cáo thống kê" + "Tháng 3/2025 · Tuần 3"
Right: [Select month] [Xuất PDF button (indigo-600, Download icon)]
```

### Key Stats (2/4 grid)
```
4 StatCard:
  "Tổng TG tháng này" | "52h 30m" | trend +8%  | text-rose-600
  "TB mỗi ngày"       | "2h 38m"  | trend +5%  | text-amber-600
  "Số lần vượt giới hạn"| "12 lần"| trend -15% | text-indigo-600
  "Tuân thủ quy tắc"  | "72%"     | trend -10% | text-emerald-600
```

### Charts Row 1 (lg:grid-cols-2)

#### Thống kê theo tuần (BarChart)
```
Recharts BarChart (height: 200px)
3 series: Khoa (#6366f1), Linh (#ec4899), Giới hạn (#e2e8f0)
radius: [4,4,0,0], barGap: 4
CartesianGrid dọc ẩn
Tooltip + Legend
```

#### Xu hướng 7 ngày (AreaChart)
```
Recharts AreaChart (height: 200px)
2 series: khoa (#6366f1), linh (#ec4899)
Fill: linearGradient opacity 0.2→0
Custom Tooltip: bg-white rounded-xl border shadow-lg
```

### App Usage Pie Charts (md:grid-cols-2)
```
2 charts (Khoa + Linh):
  Recharts PieChart innerRadius=40 outerRadius=65 paddingAngle=3
  Legend bên phải: [color dot] [name] [percent %]

Data Khoa:  YouTube 35%(red), Game 25%(orange), Học tập 30%(emerald), Khác 10%(slate)
Data Linh:  TikTok 40%(pink), Học tập 28%(emerald), Mạng XH 20%(blue), Khác 12%(slate)
```

### Compliance Chart (BarChart)
```
Recharts BarChart (height: 180px)
2 series: khoaOk (#6366f1), linhOk (#ec4899)
YAxis domain [0,100], tickFormatter: "{v}%"
```

### Insights Section
```
bg-white rounded-2xl p-5
"💡 Nhận xét & Khuyến nghị"

3 insight rows (space-y-3):
  Container: flex items-start gap-3 p-3 bg-slate-50 rounded-xl
  Icon: w-8 h-8 rounded-lg flex items-center justify-center
  Text: text-sm slate-700

Data:
  ⚠️ AlertTriangle (amber): "Thị Linh thường xuyên vượt giới hạn vào cuối tuần..."
  📉 TrendingDown (emerald): "Minh Khoa đã giảm 15% thời gian chơi game..."
  🕐 Clock (indigo):         "Thời gian học tập trực tuyến của Thị Linh chiếm 28%..."
```

---

## Phụ lục — Route map

```
/                          → HomePage (landing)
/login                     → LoginPage (parent auth)
/parent                    → ParentLayout
  /parent                  → DashboardPage
  /parent/children         → ChildrenPage
  /parent/devices          → DevicesPage
  /parent/time-limits      → TimeLimitsPage
  /parent/blocked-sites    → BlockedSitesPage
  /parent/notifications    → NotificationsPage
  /parent/history          → HistoryPage
  /parent/reports          → ReportsPage
/child/link-device         → LinkDevicePage    ← MOBILE
/child/time-remaining      → TimeRemainingPage ← MOBILE
/child/locked              → LockedPage        ← MOBILE
/child/request-time        → RequestTimePage   ← MOBILE
```

---

*Tài liệu này được tạo từ source code của KidShield để tham chiếu khi xây dựng KidFun trên React Native / Flutter.*
