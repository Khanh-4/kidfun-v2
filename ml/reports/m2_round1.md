# M2 tầng 2 — kết quả thực nghiệm (tuần 5)

Huấn luyện trước 01/03/2026, kiểm tra từ ngày đó. Làm sạch nhãn: {'nhãn giờ cài vào': 1873, 'nhãn giờ còn dùng máy (giữ)': 1527, 'nhãn ngày cài vào': 1680, 'nhãn binge_day bị giới hạn chặn (bỏ)': 231, 'nhãn ngày giữ': 1387}.

## Mức giờ (cảnh báo 1% số giờ có dùng máy) — 174,369 dòng kiểm tra, 676 dòng bất thường

| bộ phát hiện     |   PR-AUC |   ROC-AUC |   Precision |   Recall |    F1 |   tỷ lệ cảnh báo |    giây |   recall new_app |   recall night_use |   recall spike |
|:-----------------|---------:|----------:|------------:|---------:|------:|-----------------:|--------:|-----------------:|-------------------:|---------------:|
| z-score          |    0.614 |     0.933 |       0.334 |    0.664 | 0.444 |            0.008 |   0.042 |            0.65  |              0.962 |          0.45  |
| isolation forest |    0.592 |     0.943 |       0.082 |    0.743 | 0.148 |            0.035 |   2.605 |            0.951 |              1     |          0.472 |
| luật tầng 1      |    0.535 |     0.931 |       0.19  |    0.655 | 0.294 |            0.013 |   0.047 |            0.813 |              0.991 |          0.346 |
| autoencoder      |    0.357 |     0.931 |       0.119 |    0.605 | 0.199 |            0.02  | 138.235 |            0.976 |              0.421 |          0.597 |

Câu giải thích của bộ có F1 cao nhất — tỷ lệ nói đúng loại bất thường:

| kind      |   số cảnh báo đúng |   câu giải thích đúng loại |
|:----------|-------------------:|---------------------------:|
| new_app   |                 80 |                      0.862 |
| night_use |                226 |                      0.991 |
| spike     |                143 |                      0.839 |

Ví dụ:

- `new_app`: Bé dùng một ứng dụng mới lúc 17h trong 30 phút — trước đây bé gần như chưa dùng.
- `night_use`: Bé chơi game lúc 3h trong 38 phút — giờ này bé thường đã ngủ.
- `spike`: Bé dùng một ứng dụng mới lúc 19h trong 38 phút — trước đây bé gần như chưa dùng.

## Mức ngày (cảnh báo 5% số ngày) — 17,854 dòng kiểm tra, 717 dòng bất thường

| bộ phát hiện     |   PR-AUC |   ROC-AUC |   Precision |   Recall |    F1 |   tỷ lệ cảnh báo |   giây |   recall binge_day |   recall danger_content |   recall new_app |   recall night_use |   recall spike |
|:-----------------|---------:|----------:|------------:|---------:|------:|-----------------:|-------:|-------------------:|------------------------:|-----------------:|-------------------:|---------------:|
| dbscan           |    0.767 |     0.955 |       0.495 |    0.862 | 0.629 |            0.07  |  1.599 |              0.489 |                   0.887 |            0.966 |              0.948 |          0.755 |
| isolation forest |    0.649 |     0.945 |       0.5   |    0.709 | 0.586 |            0.057 |  0.401 |              0.447 |                   0.907 |            0.89  |              0.651 |          0.44  |
| autoencoder      |    0.54  |     0.857 |       0.398 |    0.563 | 0.467 |            0.057 |  4.553 |              0.553 |                   0.335 |            0.855 |              0.628 |          0.509 |
| luật tầng 1      |    0.186 |     0.823 |       0.221 |    0.236 | 0.228 |            0.043 |  0.006 |              0.511 |                   0.237 |            0.352 |              0.169 |          0.119 |
| z-score          |    0.13  |     0.652 |       0.147 |    0.163 | 0.155 |            0.044 |  0.004 |              0.702 |                   0.041 |            0.103 |              0.174 |          0.195 |

Câu giải thích của bộ có F1 cao nhất — tỷ lệ nói đúng loại bất thường:

| kind           |   số cảnh báo đúng |   câu giải thích đúng loại |
|:---------------|-------------------:|---------------------------:|
| binge_day      |                 23 |                      0.609 |
| danger_content |                172 |                      1     |
| new_app        |                140 |                      0.771 |
| night_use      |                163 |                      0.883 |
| spike          |                120 |                      0.517 |

Ví dụ:

- `new_app`: Hôm nay bé dùng một ứng dụng mới trong 30 phút.
- `danger_content`: Hôm nay bé xem 3 video có thể không phù hợp với lứa tuổi.
- `night_use`: Hôm nay bé dùng máy 38 phút vào giờ ngủ (22h–6h sáng).
- `binge_day`: Hôm nay bé dùng máy 1 giờ 20 phút, gấp 2 lần một ngày đi học bình thường (khoảng 37 phút).
- `spike`: Hôm nay bé dùng một ứng dụng mới trong 1 giờ 6 phút.

## Câu cảnh báo M1 (dự báo vượt giới hạn, lý do từ SHAP của XGBoost)

- Ngày mai (thứ Tư) bé có khả năng dùng quá giới hạn 1 giờ (khoảng 100%). Lý do chính: giới hạn ngày mai thấp so với thói quen của bé.
- Ngày mai (thứ Tư) bé có khả năng dùng quá giới hạn 1 giờ 30 phút (khoảng 100%). Lý do chính: giới hạn ngày mai thấp so với thói quen của bé.
- Ngày mai (thứ Hai) bé có khả năng dùng quá giới hạn 2 giờ (khoảng 100%). Lý do chính: sắp tới kỳ nghỉ.
