# 1. Tổng quan đề tài

Bản đầy đủ: `thesis-topic01.pdf` ở gốc repo (bản 2.1, đã gồm 4 góp ý của GVHD).

## Thông tin chung

| | |
|---|---|
| Tên đề tài | Ứng dụng học máy dự đoán và phát hiện bất thường trong hành vi sử dụng thiết bị di động của trẻ em, tích hợp vào hệ thống giám sát KidFun |
| Tên tiếng Anh | Machine Learning for Forecasting and Anomaly Detection of Children's Mobile Device Usage in a Parental Control System |
| GVHD | Dương Thành Phết |
| Thành viên | Cao Duy Quốc Khánh (2380601019), Đinh Bùi Tuấn Anh (2380600035), lớp 23DTHC1 |
| Thời gian | 9 tuần, 12/10/2026 – 13/12/2026 |

## Mục tiêu

Chuyển KidFun từ **phản ứng sau sự việc** sang **dự báo và cảnh báo sớm**:

1. Dự đoán trước một ngày trẻ có nguy cơ vượt giới hạn phụ huynh đặt hay không.
2. Tự phát hiện thay đổi bất thường trong thói quen dùng máy, kèm câu giải thích dễ hiểu.
3. Báo ngay khi trẻ dùng máy lúc khuya mà không làm app trẻ tốn pin.
4. Học từ xác nhận đúng/sai của phụ huynh để bớt báo nhầm.

## Câu hỏi nghiên cứu

| RQ | Câu hỏi | Trả lời ở |
|---|---|---|
| RQ1 | Mô hình nào dự đoán tổng thời gian ngày mai tốt nhất (cơ sở, XGBoost, Prophet, LSTM)? Mô hình phức tạp có thật sự hơn mô hình cơ sở khi dữ liệu ngắn? | `docs/thesis/06`, `07` |
| RQ2 | Xác suất "ngày mai vượt giới hạn" có đủ tin cậy (phân biệt tốt, hiệu chỉnh tốt) để gửi cảnh báo trước? | `docs/thesis/07` |
| RQ3 | Isolation Forest, DBSCAN, Autoencoder bắt được kiểu bất thường nào, với precision/recall bao nhiêu? | `docs/thesis/08` |
| RQ4 | Tầng 1 trên máy báo nhanh hơn chấm theo lô bao nhiêu, và tốn thêm bao nhiêu pin? | T8 (chưa có số đo) |
| RQ5 | Phản hồi đúng/sai của phụ huynh giảm báo nhầm bao nhiêu mà vẫn giữ recall? | `docs/thesis/09` (mô phỏng); T8 (dữ liệu thật) |

## 4 module

| Module | Nội dung | Mức đầu tư |
|---|---|---|
| M1 — Dự đoán | Tổng phút dùng máy ngày mai + xác suất vượt giới hạn, giải thích bằng SHAP | Trọng tâm, thực nghiệm đầy đủ |
| M2 — Bất thường | Tầng 1 luật nhẹ trên máy trẻ (Kotlin) + tầng 2 học máy theo lô trên server | Trọng tâm, thực nghiệm đầy đủ |
| M3 — Khai phá mẫu | Heatmap theo giờ, nhóm thói quen K-Means (Apriori bỏ nếu thiếu giờ) | Gọn |
| M4 — Gợi ý | Hệ luật gợi ý chỉnh giới hạn / School Mode, có dẫn nguồn (WHO, khảo sát) | Gọn |

## Kiến trúc

```
App trẻ (Kotlin)                         Server                                 App phụ huynh (Flutter)
─────────────────                        ──────                                 ───────────────────────
HourlyUsageWorker (30 phút) ──batch──▶  AppUsageHourly
Tier1Rules + baseline JSON ──khẩn──▶   BehaviorAlert (TIER1) ──FCM──────────▶ thông báo + nút đúng/sai
        ▲                                      ▲                                         │
        └──── GET behavior-baseline ◀──── BehaviorBaseline                                │
                                               ▲                                         ▼
                         Tác vụ ban đêm (Python, T7): baseline, M1, M2 tầng 2  ◀── feedback (RQ5)
                                               └──▶ BehaviorAlert (M1, TIER2) ──FCM──▶ tab AI Insights
```

- **Tầng 1 (đã có):** luật khuya / tăng đột biến chạy trên máy trẻ sau mỗi lần thu thập, so với mức thường ngày do
  server tính sẵn. Không thêm lần đánh thức máy nào.
- **Tầng 2 (T7):** tác vụ Python chạy theo lịch: tính mức thường ngày, dự đoán M1 mỗi tối, chấm bất thường M2.

## Dữ liệu

| Nguồn | Vai trò | Ghi chú |
|---|---|---|
| Bộ sinh mô phỏng (`ml/simulator/`) | Huấn luyện, so sánh, có nhãn bất thường | Lịch học, Tết, nghỉ hè VN; hiệu chỉnh theo khảo sát |
| LSApp, StudentLife | Kiểm chứng phương pháp trên dữ liệu thật | Người lớn → nêu thành hạn chế |
| KidFun production (`AppUsageHourly`, `BehaviorAlert`, ...) | Demo, kiểm tra cuối, phản hồi thật | Ít người dùng; cần tích luỹ từ sớm |

## Phạm vi

- **Trong phạm vi:** Android; 4 module; thu thập theo giờ gửi theo đợt; tầng 1 trên máy; tầng 2 theo lô; câu giải
  thích cho mọi cảnh báo; nút đúng/sai; tab "AI Insights" trong app phụ huynh.
- **Ngoài phạm vi:** iOS, mô hình học máy chạy trên điện thoại, real-time qua socket, frontend web (đã ngừng).

## Công nghệ

Python (pandas, scikit-learn, XGBoost, Prophet, PyTorch), Kotlin (UsageStatsManager, WorkManager), Flutter,
Node.js/Express trên Vercel, PostgreSQL (Supabase), FCM, GitHub Actions cron.
