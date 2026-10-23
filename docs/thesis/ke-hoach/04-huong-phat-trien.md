# 4. Hướng phát triển

## A. Mở rộng trong thời gian đồ án (nếu dư thời gian)

Chỉ làm sau khi T7 và T8 đã chạy, theo thứ tự ưu tiên:

| # | Việc | Giá trị cho đồ án | Công sức |
|---|---|---|---|
| A1 | Kiểm định Wilcoxon / Diebold–Mariano cho M1 (nếu T8.4 chưa đủ) | Kết luận RQ1 có ý nghĩa thống kê | Nhỏ |
| A2 | Dò siêu tham số LSTM (cửa sổ, số nút, dropout) | Trả lời RQ1 công bằng hơn | Nhỏ |
| A3 | Thêm `GeofenceEvent` vào bộ mô phỏng, đánh giá nhóm đặc trưng vị trí | Hoàn thiện phân tích loại bỏ | Vừa |
| A4 | Chạy M1 trên Tsinghua App Usage | Thêm một bộ dữ liệu công khai | Vừa |
| A5 | Huấn luyện lại M2 bằng nhãn phản hồi thật (bán giám sát) | Mở rộng RQ5 | Vừa |
| A6 | Apriori cho M3 (đã bỏ khỏi bản gọn) | Đủ phạm vi M3 như đề xuất gốc | Vừa |

## B. Sau đồ án (đưa vào chương "Hướng phát triển" của báo cáo)

1. **Dữ liệu thật quy mô lớn:** hợp tác trường học hoặc nhóm phụ huynh để có vài trăm trẻ, đánh giá lại M1/M2 trên
   trẻ em thật thay vì mô phỏng và người lớn.
2. **Mô hình nhẹ trên máy:** đưa một phần M2 (Autoencoder nhỏ hoặc z-score theo nhóm app) xuống điện thoại bằng
   TensorFlow Lite, giảm phụ thuộc vào server.
3. **Học liên kết (federated learning):** huấn luyện chung trên nhiều gia đình mà dữ liệu không rời máy.
4. **Cá nhân hoá sâu hơn:** mô hình riêng cho từng trẻ khi đủ dữ liệu, chuyển dần từ mô hình chung sang riêng.
5. **Phát hiện trôi hành vi:** tự nhận biết khi thói quen đổi theo mùa (nghỉ hè, mùa thi) để cập nhật ngưỡng.
6. **Mở rộng nền tảng:** iOS (Screen Time API), máy tính bảng dùng chung nhiều trẻ.
7. **Gợi ý thông minh hơn cho M4:** đánh giá gợi ý có giúp giảm vượt giới hạn thật hay không (thử A/B).
8. **Ứng dụng cho nhà trường:** quản lý thiết bị học tập theo lớp, cảnh báo theo nhóm.
9. **Công bố:** viết lại thành bài báo hội nghị trong nước (bộ sinh dữ liệu trẻ em VN là đóng góp có thể dùng lại).
