# Hướng dẫn chèn sơ đồ vào báo cáo (Google Docs)

Thư mục này chứa **21 sơ đồ UML** cho báo cáo Đồ án Cơ sở KidFun.
Mỗi sơ đồ có 2 file: `.puml` (mã nguồn PlantUML) và `.png` (ảnh đã render sẵn).
**Khi chèn vào báo cáo chỉ dùng file `.png`.**

---

## 1. Bảng ánh xạ — chèn ảnh nào vào đâu

Trong file báo cáo, tìm dòng chữ nghiêng `*[Hình 3.x.x.x: ... — sẽ được chèn tại đây]*`
rồi thay bằng ảnh tương ứng:

| File ảnh (.png) | Chèn tại Hình | Mục |
|---|---|---|
| `Hinh-3.2.1.1-UseCase-TongQuan` | 3.2.1.1 | Sơ đồ Use Case tổng quan |
| `Hinh-3.3.1.1-UseCase-UC02-DangNhap` | 3.3.1.1 | UC-02 Đăng nhập |
| `Hinh-3.3.2.1-UseCase-UC06-07-LienKetQR` | 3.3.2.1 | UC-06+07 Liên kết QR |
| `Hinh-3.3.3.1-UseCase-UC08-GioiHanThoiGian` | 3.3.3.1 | UC-08 Giới hạn thời gian |
| `Hinh-3.3.4.1-UseCase-UC09-ChanUngDung` | 3.3.4.1 | UC-09 Chặn ứng dụng |
| `Hinh-3.3.5.1-UseCase-UC20-24-CanhBaoKhoa` | 3.3.5.1 | UC-20+24 Cảnh báo mềm & Khóa máy |
| `Hinh-3.3.6.1-UseCase-UC21-12-XinThemGio` | 3.3.6.1 | UC-21+12 Xin thêm giờ |
| `Hinh-3.3.7.1-UseCase-UC22-SOS` | 3.3.7.1 | UC-22 SOS |
| `Hinh-3.4.1.1-Sequence-DangNhap` | 3.4.1.1 | Sequence — Đăng nhập |
| `Hinh-3.4.2.1-Sequence-LienKetQR` | 3.4.2.1 | Sequence — Liên kết QR |
| `Hinh-3.4.3.1-Sequence-CanhBaoKhoa` | 3.4.3.1 | Sequence — Cảnh báo mềm & Khóa |
| `Hinh-3.4.4.1-Sequence-XinThemGio` | 3.4.4.1 | Sequence — Xin thêm giờ |
| `Hinh-3.4.5.1-Sequence-ChanUngDung` | 3.4.5.1 | Sequence — Chặn ứng dụng |
| `Hinh-3.4.6.1-Sequence-SOS` | 3.4.6.1 | Sequence — SOS |
| `Hinh-3.5.1.1-Activity-LienKetQR` | 3.5.1.1 | Activity — Liên kết QR |
| `Hinh-3.5.2.1-Activity-VongLapThoiGian` | 3.5.2.1 | Activity — Vòng lặp kiểm soát thời gian |
| `Hinh-3.5.3.1-Activity-XinThemGio` | 3.5.3.1 | Activity — Xin thêm giờ |
| `Hinh-3.5.4.1-Activity-ChanUngDung` | 3.5.4.1 | Activity — Chặn ứng dụng |
| `Hinh-3.5.5.1-Activity-SOS` | 3.5.5.1 | Activity — Kích hoạt SOS |
| `Hinh-3.7.1-ClassDiagram` | 3.7.1 | Class Diagram 32 lớp |
| `Hinh-3.8.1-ERD` | 3.8.1 | ERD 32 bảng |

---

## 2. Cách chèn vào Google Docs

1. Đặt con trỏ vào đúng dòng `*[Hình 3.x.x.x: ...]*` → xóa dòng đó đi.
2. **Insert → Image → Upload from computer** → chọn file `.png` tương ứng.
3. Chọn ảnh → kiểu bao văn bản để **In line** (hoặc *Wrap text* nếu muốn).
4. Giữ dòng chú thích *Hình 3.x.x.x: ...* ngay dưới ảnh, canh giữa.

---

## 3. Căn kích thước cho "vừa khung hình"

Chia làm 3 nhóm theo tỉ lệ ảnh:

### Nhóm A — Sơ đồ ngang, chèn full chiều rộng trang
Use Case chi tiết (3.3.x), Sequence (3.4.x), và Activity 3.5.2.1, 3.5.4.1.
→ Kéo ảnh cho **rộng bằng lề trang (~16 cm)**. Ảnh sẽ thấp, nằm gọn 1 trang.

### Nhóm B — Sơ đồ cao, căn theo CHIỀU CAO trang
Activity dạng cột: **3.5.1.1, 3.5.3.1, 3.5.5.1** (ảnh hẹp & cao).
→ **KHÔNG** kéo full chiều rộng (sẽ tràn 2 trang).
→ Kéo cho ảnh **cao vừa 1 trang (~20 cm)**, chiều rộng tự co còn ~8–10 cm, rồi **canh giữa trang**.

### Nhóm C — Sơ đồ lớn, đặt TRANG NGANG (Landscape)
**3.7.1 Class Diagram** và **3.8.1 ERD** (32 lớp/bảng — rất rộng).
→ Tạo riêng cho mỗi sơ đồ một trang xoay ngang:
  - Bôi đen vùng trang đó → **Format → Page orientation → Landscape**
    (hoặc tách section: Insert → Break → Section break).
  - Chèn ảnh full chiều rộng trang ngang (~24 cm).
→ Sơ đồ Use Case tổng quan **3.2.1.1** (gần vuông) có thể để trang dọc, full chiều rộng,
  hoặc cho riêng 1 trang.

---

## 4. Chỉnh sửa & render lại sơ đồ

Nếu cần sửa nội dung sơ đồ, sửa file `.puml` rồi render lại ra `.png`:

```bash
cd "Báo Cáo Đồ Án Cơ Sở/diagrams"
java -DPLANTUML_LIMIT_SIZE=20000 -jar ~/.cache/plantuml/plantuml.jar \
  -tpng -charset UTF-8 *.puml
```

- Cần Java (đã có sẵn) và file `~/.cache/plantuml/plantuml.jar` (PlantUML 1.2026.3).
- Có thể render online không cần cài đặt: dán nội dung `.puml` vào https://www.plantuml.com/plantuml
- Tham số `-DPLANTUML_LIMIT_SIZE=20000` để 2 sơ đồ lớn (Class, ERD) không bị thu nhỏ.
