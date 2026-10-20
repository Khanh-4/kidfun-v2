# M2 tầng 2 — kết quả thực nghiệm (tuần 5)

Huấn luyện trước 01/03/2026, kiểm tra từ ngày đó. Làm sạch nhãn: {'nhãn giờ cài vào': 1873, 'nhãn giờ còn dùng máy (giữ)': 1527, 'nhãn ngày cài vào': 1680, 'nhãn ngày giữ': 1618}.

## Mức giờ (cảnh báo 1% số giờ có dùng máy) — 174,369 dòng kiểm tra, 676 dòng bất thường

| bộ phát hiện     |   PR-AUC |   ROC-AUC |   Precision |   Recall |    F1 |   tỷ lệ cảnh báo |   giây |   recall new_app |   recall night_use |   recall spike |
|:-----------------|---------:|----------:|------------:|---------:|------:|-----------------:|-------:|-----------------:|-------------------:|---------------:|
| z-score          |    0.614 |     0.933 |       0.334 |    0.664 | 0.444 |            0.008 |  0.037 |            0.65  |              0.962 |          0.45  |
| isolation forest |    0.592 |     0.943 |       0.082 |    0.743 | 0.148 |            0.035 |  2.162 |            0.951 |              1     |          0.472 |
| luật tầng 1      |    0.535 |     0.931 |       0.19  |    0.655 | 0.294 |            0.013 |  0.04  |            0.813 |              0.991 |          0.346 |
| autoencoder      |    0.357 |     0.931 |       0.119 |    0.605 | 0.199 |            0.02  | 58.774 |            0.976 |              0.421 |          0.597 |

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

## Mức ngày (cảnh báo 5% số ngày) — 17,854 dòng kiểm tra, 845 dòng bất thường

| bộ phát hiện     |   PR-AUC |   ROC-AUC |   Precision |   Recall |    F1 |   tỷ lệ cảnh báo |   giây |   recall binge_day |   recall danger_content |   recall new_app |   recall night_use |   recall spike |
|:-----------------|---------:|----------:|------------:|---------:|------:|-----------------:|-------:|-------------------:|------------------------:|-----------------:|-------------------:|---------------:|
| dbscan           |    0.704 |     0.934 |       0.514 |    0.76  | 0.613 |            0.07  |  1.683 |              0.269 |                   0.887 |            0.966 |              0.948 |          0.755 |
| isolation forest |    0.597 |     0.921 |       0.511 |    0.614 | 0.558 |            0.057 |  0.424 |              0.183 |                   0.907 |            0.89  |              0.651 |          0.44  |
| autoencoder      |    0.507 |     0.851 |       0.418 |    0.502 | 0.456 |            0.057 |  2.465 |              0.263 |                   0.335 |            0.855 |              0.628 |          0.509 |
| luật tầng 1      |    0.181 |     0.782 |       0.225 |    0.204 | 0.214 |            0.043 |  0.006 |              0.154 |                   0.237 |            0.352 |              0.169 |          0.119 |
| z-score          |    0.134 |     0.659 |       0.157 |    0.148 | 0.153 |            0.044 |  0.004 |              0.234 |                   0.041 |            0.103 |              0.174 |          0.195 |

Câu giải thích của bộ có F1 cao nhất — tỷ lệ nói đúng loại bất thường:

| kind           |   số cảnh báo đúng |   câu giải thích đúng loại |
|:---------------|-------------------:|---------------------------:|
| binge_day      |                 47 |                      0.298 |
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

- Ngày mai (thứ Sáu) bé có khả năng dùng quá giới hạn 45 phút (khoảng 90%). Lý do chính: gần đây bé xem video nhiều.
- Ngày mai (thứ Sáu) bé có khả năng dùng quá giới hạn 1 giờ (khoảng 80%). Lý do chính: giới hạn ngày mai thấp so với thói quen của bé.
- Ngày mai (thứ Hai) bé có khả năng dùng quá giới hạn 45 phút (khoảng 80%). Lý do chính: giới hạn ngày mai thấp so với thói quen của bé.
