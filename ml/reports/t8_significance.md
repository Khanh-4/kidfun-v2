# T8.4 — Kiểm định thống kê M1 và M2 tầng 2

## M1 — dữ liệu mô phỏng (trẻ em)

17,955 dự đoán, 100 người.

Wilcoxon cặp trên MAE theo từng người (hai phía; ΔMAE < 0 là mô hình sai ít hơn MA7):

| so sánh        | thắng/tổng   |   trung vị ΔMAE (phút) |   W | p       | p (Holm)   | kết luận             |
|:---------------|:-------------|-----------------------:|----:|:--------|:-----------|:---------------------|
| xgb_rel vs ma7 | 100/100      |                 -12.53 |   0 | < 0,001 | < 0,001    | khác biệt có ý nghĩa |
| lstm vs ma7    | 100/100      |                 -10.29 |   0 | < 0,001 | < 0,001    | khác biệt có ý nghĩa |

MAE và khoảng tin cậy 95% (bootstrap 2000 lần theo người):

| model   |   MAE | KTC 95% MAE   |   ΔMAE so với ma7 | KTC 95% ΔMAE   |
|:--------|------:|:--------------|------------------:|:---------------|
| xgb_rel |  33.5 | [29.0; 38.3]  |             -18.7 | [-22.0; -15.5] |
| xgb_abs |  34   | [29.5; 38.8]  |             -18.3 | [-21.5; -15.2] |
| lstm    |  36.8 | [31.9; 42.0]  |             -15.4 | [-18.2; -12.8] |
| ma7     |  52.3 | [45.5; 59.5]  |             nan   | nan            |

## M1 — LSApp (người lớn)

945 dự đoán, 93 người.

Wilcoxon cặp trên MAE theo từng người (hai phía; ΔMAE < 0 là mô hình sai ít hơn MA7):

| so sánh        | thắng/tổng   |   trung vị ΔMAE (phút) |    W | p     | p (Holm)   | kết luận           |
|:---------------|:-------------|-----------------------:|-----:|:------|:-----------|:-------------------|
| xgb_rel vs ma7 | 35/89        |                   2.1  | 1440 | 0,031 | 0,062      | chưa đủ bằng chứng |
| lstm vs ma7    | 45/89        |                  -0.15 | 1907 | 0,696 | 0,696      | chưa đủ bằng chứng |

MAE và khoảng tin cậy 95% (bootstrap 2000 lần theo người):

| model   |   MAE | KTC 95% MAE   |   ΔMAE so với ma7 | KTC 95% ΔMAE   |
|:--------|------:|:--------------|------------------:|:---------------|
| lstm    |  80.2 | [68.8; 91.7]  |              -0.2 | [-3.7; 3.3]    |
| ma7     |  81.4 | [69.6; 93.9]  |             nan   | nan            |
| xgb_abs |  83.3 | [71.4; 96.1]  |               3   | [0.4; 5.7]     |
| xgb_rel |  84.2 | [72.2; 97.0]  |               2.8 | [0.3; 5.3]     |

## M1 — StudentLife (sinh viên)

984 dự đoán, 47 người.

Wilcoxon cặp trên MAE theo từng người (hai phía; ΔMAE < 0 là mô hình sai ít hơn MA7):

| so sánh        | thắng/tổng   |   trung vị ΔMAE (phút) |   W | p     | p (Holm)   | kết luận             |
|:---------------|:-------------|-----------------------:|----:|:------|:-----------|:---------------------|
| xgb_rel vs ma7 | 20/46        |                   0.64 | 487 | 0,926 | 0,926      | chưa đủ bằng chứng   |
| lstm vs ma7    | 29/46        |                  -6.41 | 335 | 0,024 | 0,048      | khác biệt có ý nghĩa |

MAE và khoảng tin cậy 95% (bootstrap 2000 lần theo người):

| model   |   MAE | KTC 95% MAE    |   ΔMAE so với ma7 | KTC 95% ΔMAE   |
|:--------|------:|:---------------|------------------:|:---------------|
| lstm    | 142.3 | [125.2; 160.1] |              -6.8 | [-12.6; -1.5]  |
| ma7     | 148   | [131.2; 165.8] |             nan   | nan            |
| xgb_rel | 148.6 | [131.9; 165.0] |               0.6 | [-5.5; 6.5]    |
| xgb_abs | 149.5 | [132.1; 167.3] |               1.5 | [-5.8; 8.6]    |

## M2 tầng 2 — mức giờ

174,369 dòng kiểm tra, 676 dòng bất thường, 100 trẻ. Bootstrap 1000 lần theo trẻ:

| bộ phát hiện                 |   PR-AUC | KTC 95%         |
|:-----------------------------|---------:|:----------------|
| luật tầng 1                  |    0.535 | [0.466; 0.614]  |
| z-score                      |    0.614 | [0.535; 0.690]  |
| isolation forest             |    0.592 | [0.527; 0.663]  |
| autoencoder                  |    0.357 | [0.300; 0.430]  |
| Δ z-score − isolation forest |    0.022 | [-0.023; 0.065] |

## M2 tầng 2 — mức ngày

17,854 dòng kiểm tra, 845 dòng bất thường, 100 trẻ. Bootstrap 1000 lần theo trẻ:

| bộ phát hiện                |   PR-AUC | KTC 95%        |
|:----------------------------|---------:|:---------------|
| luật tầng 1                 |    0.181 | [0.152; 0.220] |
| z-score                     |    0.134 | [0.112; 0.163] |
| isolation forest            |    0.597 | [0.523; 0.669] |
| dbscan                      |    0.704 | [0.651; 0.755] |
| autoencoder                 |    0.507 | [0.466; 0.550] |
| Δ dbscan − isolation forest |    0.107 | [0.073; 0.137] |
