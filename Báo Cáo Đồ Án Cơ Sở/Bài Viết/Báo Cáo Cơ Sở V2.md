

| ![][image1] |  BỘ GIÁO DỤC VÀ ĐÀO TẠO TRƯỜNG ĐẠI HỌC CÔNG NGHỆ TP. HCM |
| :---: | :---: |

**ĐỒ ÁN CƠ SỞ**

**ỨNG DỤNG KIỂM SOÁT THỜI GIAN SỬ DỤNG THIẾT BỊ ĐIỆN TỬ CỦA TRẺ EM \- KIDFUN**

Ngành: 	**CÔNG NGHỆ THÔNG TIN**  
Chuyên ngành: 	**CÔNG NGHỆ PHẦN MỀM**

Giảng viên hướng dẫn	: ThS. Dương Thành Phết  
Sinh viên thực hiện	: Cao Duy Quốc Khánh  
MSSV: 2380601019	Lớp: 23DTHC1  
Sinh viên thực hiện	: Đinh Bùi Tuấn Anh  
MSSV: 	Lớp: 23DTHC1 

TP. Hồ Chí Minh, 2026  
**PHẦN ĐẦU — LỜI CẢM ƠN & CAM ĐOAN**

 **LỜI CẢM ƠN**

Để hoàn thành đồ án cơ sở này, nhóm nghiên cứu xin bày tỏ lòng biết ơn sâu sắc đến quý thầy/cô và các cá nhân đã đồng hành, hỗ trợ trong suốt quá trình thực hiện.

Trước tiên, nhóm xin chân thành cảm ơn Thầy Ths. Dương Thành Phết, Giảng viên hướng dẫn đồ án đã tận tình chỉ dẫn, góp ý và định hướng về cả nội dung lẫn phương pháp tiếp cận từ những buổi đầu lên ý tưởng cho đến khi sản phẩm được hoàn thiện. Những nhận xét thẳng thắn, kịp thời của Thầy đã giúp nhóm nhận ra nhiều thiếu sót và điều chỉnh đúng hướng.

Nhóm cũng xin gửi lời cảm ơn đến Khoa Công nghệ Thông tin — Trường Đại học Công nghệ Thành phố Hồ Chí Minh (HUTECH) đã tạo điều kiện học tập, cung cấp cơ sở vật chất, tài liệu và môi trường nghiên cứu thuận lợi trong suốt quá trình học tập của chúng tôi.

Chân thành cảm ơn gia đình và bạn bè đã luôn động viên, ủng hộ tinh thần trong những thời điểm khó khăn nhất.

Mặc dù đã cố gắng hết sức, song đây là lần đầu tiên nhóm triển khai một hệ thống phần mềm có quy mô tương đối lớn, nên không tránh khỏi những thiếu sót. Nhóm rất mong nhận được sự đóng góp, chỉ dẫn thêm từ quý thầy/cô và người đọc để sản phẩm có thể được cải thiện hoàn thiện hơn trong tương lai.

Trân trọng cảm ơn\!

Nhóm sinh viên thực hiện: Nhóm 8

**CAM ĐOAN**

Nhóm nghiên cứu xin cam đoan rằng:

1\. Đồ án cơ sở "KidFun — Hệ thống Quản lý và Giám sát Thời gian Sử dụng Thiết bị Thông minh dành cho Trẻ em" là công trình nghiên cứu và thực hiện của nhóm dưới sự hướng dẫn của Thầy Dương Thành Phết.

2\. Toàn bộ nội dung, kết quả phân tích, thiết kế và cài đặt trong báo cáo là do nhóm tự thực hiện, không sao chép từ bất kỳ công trình nào khác dưới bất kỳ hình thức nào nếu không được trích dẫn rõ ràng.

3\. Các số liệu, kết quả kiểm thử trình bày trong báo cáo là trung thực và chưa từng được công bố trong bất kỳ công trình nào khác.

4\. Mã nguồn của hệ thống do nhóm tự viết, ngoại trừ các thư viện, framework mã nguồn mở đã được khai báo rõ ràng trong phần Tài liệu tham khảo.

Nếu có bất kỳ gian lận nào, nhóm xin hoàn toàn chịu trách nhiệm trước Hội đồng và Nhà trường.

# **MỤC LỤC** {#mục-lục}

[**MỤC LỤC	3**](#mục-lục)

[**CHƯƠNG 1: MỞ ĐẦU	11**](#chương-1:-mở-đầu)

[1.1. Lý do chọn đề tài	11](#1.1.-lý-do-chọn-đề-tài)

[1.2. Mục tiêu đề tài	12](#1.2.-mục-tiêu-đề-tài)

[1.3. Phạm vi và đối tượng nghiên cứu	13](#1.3.-phạm-vi-và-đối-tượng-nghiên-cứu)

[1.4. Phương pháp thực hiện	14](#1.4.-phương-pháp-thực-hiện)

[1.5. Cấu trúc báo cáo	14](#1.5.-cấu-trúc-báo-cáo)

[**CHƯƠNG 2: CƠ SỞ LÝ THUYẾT	16**](#chương-2:-cơ-sở-lý-thuyết)

[2.1. Tổng quan kiến trúc	16](#2.1.-tổng-quan-kiến-trúc)

[2.2. Công nghệ phía Mobile (thành phần chính của đồ án)	16](#2.2.-công-nghệ-phía-mobile-\(thành-phần-chính-của-đồ-án\))

[2.2.1. Flutter và ngôn ngữ Dart	16](#2.2.1.-flutter-và-ngôn-ngữ-dart)

[2.2.2. Riverpod — Quản lý trạng thái	17](#2.2.2.-riverpod-—-quản-lý-trạng-thái)

[2.2.3. go\_router — Điều hướng	17](#2.2.3.-go_router-—-điều-hướng)

[2.2.4. Dio — HTTP client	17](#2.2.4.-dio-—-http-client)

[2.2.5. flutter\_secure\_storage	18](#2.2.5.-flutter_secure_storage)

[2.2.6. Socket.IO Client cho Flutter	18](#2.2.6.-socket.io-client-cho-flutter)

[2.2.7. Firebase Cloud Messaging (FCM) trên Flutter	18](#2.2.7.-firebase-cloud-messaging-\(fcm\)-trên-flutter)

[2.2.8. Mapbox Maps Flutter	18](#2.2.8.-mapbox-maps-flutter)

[2.2.9. fl\_chart — Biểu đồ thống kê	19](#2.2.9.-fl_chart-—-biểu-đồ-thống-kê)

[2.2.10. Các thư viện Flutter khác	19](#2.2.10.-các-thư-viện-flutter-khác)

[2.3. Kotlin Native và API đặc quyền của Android	19](#2.3.-kotlin-native-và-api-đặc-quyền-của-android)

[2.3.1. UsageStatsManager	20](#2.3.1.-usagestatsmanager)

[2.3.2. AccessibilityService	20](#2.3.2.-accessibilityservice)

[2.3.3. DevicePolicyManager và Device Admin	20](#2.3.3.-devicepolicymanager-và-device-admin)

[2.3.4. ForegroundService	21](#2.3.4.-foregroundservice)

[2.3.5. VpnService (Web Filtering)	21](#2.3.5.-vpnservice-\(web-filtering\))

[2.3.6. NotificationListenerService	21](#2.3.6.-notificationlistenerservice)

[2.3.7. BootReceiver	21](#2.3.7.-bootreceiver)

[2.3.8. MethodChannel — Cầu nối Flutter ↔ Kotlin	22](#2.3.8.-methodchannel-—-cầu-nối-flutter-↔-kotlin)

[2.4. Công nghệ phía Backend	22](#2.4.-công-nghệ-phía-backend)

[2.4.1. Node.js và Express.js	22](#2.4.1.-node.js-và-express.js)

[2.4.2. Prisma ORM và PostgreSQL	22](#2.4.2.-prisma-orm-và-postgresql)

[2.4.3. Socket.IO	23](#2.4.3.-socket.io)

[2.4.4. JSON Web Token (JWT) và bcryptjs	24](#2.4.4.-json-web-token-\(jwt\)-và-bcryptjs)

[2.4.5. Firebase Cloud Messaging (FCM) — Admin SDK	24](#2.4.5.-firebase-cloud-messaging-\(fcm\)-—-admin-sdk)

[2.4.6. Triển khai (Deployment)	24](#2.4.6.-triển-khai-\(deployment\))

[2.5. Trí tuệ nhân tạo — Llama 4 Scout qua Groq Cloud \+ OpenRouter	24](#2.5.-trí-tuệ-nhân-tạo-—-llama-4-scout-qua-groq-cloud-+-openrouter)

[2.6. Quy trình phát triển phần mềm — Agile/Scrum	25](#2.6.-quy-trình-phát-triển-phần-mềm-—-agile/scrum)

[2.6.1. Mô hình Agile	25](#2.6.1.-mô-hình-agile)

[2.6.2. Scrum Framework	26](#2.6.2.-scrum-framework)

[2.6.3. Quản lý mã nguồn với Git và GitHub	26](#2.6.3.-quản-lý-mã-nguồn-với-git-và-github)

[**CHƯƠNG 3: PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG	28**](#chương-3:-phân-tích-và-thiết-kế-hệ-thống)

[3.1. Khảo sát hiện trạng và yêu cầu hệ thống	28](#3.1.-khảo-sát-hiện-trạng-và-yêu-cầu-hệ-thống)

[3.1.1. Khảo sát hiện trạng	28](#3.1.1.-khảo-sát-hiện-trạng)

[3.1.2. Yêu cầu chức năng (Functional Requirements)	29](#3.1.2.-yêu-cầu-chức-năng-\(functional-requirements\))

[3.1.3. Yêu cầu phi chức năng (Non-functional Requirements)	31](#3.1.3.-yêu-cầu-phi-chức-năng-\(non-functional-requirements\))

[3.2. Sơ đồ trường hợp sử dụng (Use Case Diagram)	32](#3.2.-sơ-đồ-trường-hợp-sử-dụng-\(use-case-diagram\))

[3.2.1. Tổng quan Actor	32](#3.2.1.-tổng-quan-actor)

[3.2.2. Danh sách Use Case	32](#3.2.2.-danh-sách-use-case)

[3.3. Use Case chi tiết các chức năng cốt lõi	34](#3.3.-use-case-chi-tiết-các-chức-năng-cốt-lõi)

[3.3.1. UC-02: Đăng nhập hệ thống	34](#3.3.1.-uc-02:-đăng-nhập-hệ-thống)

[3.3.2. UC-06 \+ UC-07: Liên kết thiết bị qua QR Code	35](#3.3.2.-uc-06-+-uc-07:-liên-kết-thiết-bị-qua-qr-code)

[3.3.3. UC-08: Cài đặt giới hạn thời gian	37](#3.3.3.-uc-08:-cài-đặt-giới-hạn-thời-gian)

[3.3.4. UC-09: Chặn ứng dụng	38](#3.3.4.-uc-09:-chặn-ứng-dụng)

[3.3.5. UC-20 \+ UC-24: Cảnh báo mềm và Khóa thiết bị (USP)	39](#3.3.5.-uc-20-+-uc-24:-cảnh-báo-mềm-và-khóa-thiết-bị-\(usp\))

[3.3.6. UC-21 \+ UC-12: Yêu cầu thêm giờ real-time (USP)	40](#3.3.6.-uc-21-+-uc-12:-yêu-cầu-thêm-giờ-real-time-\(usp\))

[3.3.7. UC-22: Kích hoạt SOS	41](#3.3.7.-uc-22:-kích-hoạt-sos)

[3.4. Sơ đồ tuần tự (Sequence Diagram) cho các luồng cốt lõi	43](#3.4.-sơ-đồ-tuần-tự-\(sequence-diagram\)-cho-các-luồng-cốt-lõi)

[3.4.1. Luồng 1: Đăng nhập và khởi tạo phiên làm việc	43](#3.4.1.-luồng-1:-đăng-nhập-và-khởi-tạo-phiên-làm-việc)

[3.4.2. Luồng 2: Liên kết thiết bị qua QR Code	43](#3.4.2.-luồng-2:-liên-kết-thiết-bị-qua-qr-code)

[3.4.3. Luồng 3: Cảnh báo mềm và Khóa thiết bị (USP)	44](#3.4.3.-luồng-3:-cảnh-báo-mềm-và-khóa-thiết-bị-\(usp\))

[3.4.4. Luồng 4: Yêu cầu thêm giờ real-time (USP)	45](#3.4.4.-luồng-4:-yêu-cầu-thêm-giờ-real-time-\(usp\))

[3.4.5. Luồng 5: Phát hiện và chặn ứng dụng (Android Native)	46](#3.4.5.-luồng-5:-phát-hiện-và-chặn-ứng-dụng-\(android-native\))

[3.4.6. Luồng 6: Cảnh báo SOS khẩn cấp	47](#3.4.6.-luồng-6:-cảnh-báo-sos-khẩn-cấp)

[3.5. Sơ đồ hoạt động (Activity Diagram) cho các luồng cốt lõi	48](#3.5.-sơ-đồ-hoạt-động-\(activity-diagram\)-cho-các-luồng-cốt-lõi)

[3.5.1. Hoạt động 1: Liên kết thiết bị Child với hồ sơ qua QR	48](#3.5.1.-hoạt-động-1:-liên-kết-thiết-bị-child-với-hồ-sơ-qua-qr)

[3.5.2. Hoạt động 2: Vòng lặp kiểm soát thời gian (KidFunService) – CORE	49](#3.5.2.-hoạt-động-2:-vòng-lặp-kiểm-soát-thời-gian-\(kidfunservice\)-–-core)

[3.5.3. Hoạt động 3: Xử lý yêu cầu thêm giờ end-to-end (USP)	50](#3.5.3.-hoạt-động-3:-xử-lý-yêu-cầu-thêm-giờ-end-to-end-\(usp\))

[3.5.4. Hoạt động 4: Phát hiện và chặn ứng dụng (App Blocking)	51](#3.5.4.-hoạt-động-4:-phát-hiện-và-chặn-ứng-dụng-\(app-blocking\))

[3.5.5. Hoạt động 5: Kích hoạt SOS	52](#3.5.5.-hoạt-động-5:-kích-hoạt-sos)

[3.6. Thiết kế giao diện mobile	53](#3.6.-thiết-kế-giao-diện-mobile)

[3.6.1. Nguyên tắc thiết kế	53](#3.6.1.-nguyên-tắc-thiết-kế)

[3.6.2. Wireframe các màn hình mobile chính	53](#3.6.2.-wireframe-các-màn-hình-mobile-chính)

[3.7. Sơ đồ lớp (Class Diagram)	55](#3.7.-sơ-đồ-lớp-\(class-diagram\))

[3.7.1. Nhóm lõi — Tài khoản và Định danh	55](#3.7.1.-nhóm-lõi-—-tài-khoản-và-định-danh)

[3.7.2. Nhóm kiểm soát thời gian	56](#3.7.2.-nhóm-kiểm-soát-thời-gian)

[3.7.3. Nhóm chặn ứng dụng và website	57](#3.7.3.-nhóm-chặn-ứng-dụng-và-website)

[3.7.4. Nhóm theo dõi hoạt động	58](#3.7.4.-nhóm-theo-dõi-hoạt-động)

[3.7.5. Nhóm vị trí và khẩn cấp	59](#3.7.5.-nhóm-vị-trí-và-khẩn-cấp)

[3.7.6. Nhóm chế độ học (School Mode — Sprint 8\)	59](#3.7.6.-nhóm-chế-độ-học-\(school-mode-—-sprint-8\))

[3.7.7. Nhóm YouTube và AI (Sprint 9\)	60](#3.7.7.-nhóm-youtube-và-ai-\(sprint-9\))

[3.7.8. Đối ứng phía Flutter	61](#3.7.8.-đối-ứng-phía-flutter)

[3.8. Thiết kế cơ sở dữ liệu (ERD — Entity Relationship Diagram)	61](#3.8.-thiết-kế-cơ-sở-dữ-liệu-\(erd-—-entity-relationship-diagram\))

[3.8.1. Tổng quan schema	61](#3.8.1.-tổng-quan-schema)

[3.8.2. Danh sách bảng theo nhóm chức năng	61](#3.8.2.-danh-sách-bảng-theo-nhóm-chức-năng)

[3.8.3. Mối quan hệ giữa các bảng	64](#3.8.3.-mối-quan-hệ-giữa-các-bảng)

[3.8.4. Quy ước ràng buộc và Index	65](#3.8.4.-quy-ước-ràng-buộc-và-index)

[**CHƯƠNG 4: CÀI ĐẶT VÀ KIỂM THỬ	67**](#chương-4:-cài-đặt-và-kiểm-thử)

[4.1. Môi trường phát triển	67](#4.1.-môi-trường-phát-triển)

[4.1.1. Phần cứng	67](#4.1.1.-phần-cứng)

[4.1.2. Phần mềm và công cụ phát triển	67](#4.1.2.-phần-mềm-và-công-cụ-phát-triển)

[4.1.3. Dịch vụ đám mây	68](#4.1.3.-dịch-vụ-đám-mây)

[4.1.4. Cấu hình môi trường	69](#4.1.4.-cấu-hình-môi-trường)

[4.2. Hướng dẫn cài đặt và build ứng dụng	69](#4.2.-hướng-dẫn-cài-đặt-và-build-ứng-dụng)

[4.2.1. Clone và cài đặt dependencies	69](#4.2.1.-clone-và-cài-đặt-dependencies)

[4.2.2. Khởi tạo database	70](#4.2.2.-khởi-tạo-database)

[4.2.3. Chạy backend ở chế độ phát triển	70](#4.2.3.-chạy-backend-ở-chế-độ-phát-triển)

[4.2.4. Chạy app mobile trên thiết bị Android thật	70](#4.2.4.-chạy-app-mobile-trên-thiết-bị-android-thật)

[4.2.5. Build APK release đã ký	70](#4.2.5.-build-apk-release-đã-ký)

[4.3. Các chức năng chính của ứng dụng mobile	71](#4.3.-các-chức-năng-chính-của-ứng-dụng-mobile)

[4.3.1. Đăng ký và đăng nhập tài khoản	71](#4.3.1.-đăng-ký-và-đăng-nhập-tài-khoản)

[4.3.2. Chọn chế độ Parent / Child	71](#4.3.2.-chọn-chế-độ-parent-/-child)

[4.3.3. Quản lý hồ sơ con (Parent)	71](#4.3.3.-quản-lý-hồ-sơ-con-\(parent\))

[4.3.4. Liên kết thiết bị qua QR Code	72](#4.3.4.-liên-kết-thiết-bị-qua-qr-code)

[4.3.5. Cấp quyền đặc biệt cho Child Device	72](#4.3.5.-cấp-quyền-đặc-biệt-cho-child-device)

[4.3.6. Cài đặt giới hạn thời gian	72](#4.3.6.-cài-đặt-giới-hạn-thời-gian)

[4.3.7. Child Dashboard và Cảnh báo mềm	73](#4.3.7.-child-dashboard-và-cảnh-báo-mềm)

[4.3.8. Lock Screen (Kiosk Mode) khi hết giờ	73](#4.3.8.-lock-screen-\(kiosk-mode\)-khi-hết-giờ)

[4.3.9. Yêu cầu thêm giờ và phê duyệt real-time	74](#4.3.9.-yêu-cầu-thêm-giờ-và-phê-duyệt-real-time)

[4.3.10. Chặn ứng dụng	74](#4.3.10.-chặn-ứng-dụng)

[4.3.11. Theo dõi vị trí và Geofencing	74](#4.3.11.-theo-dõi-vị-trí-và-geofencing)

[4.3.12. Cảnh báo SOS khẩn cấp	75](#4.3.12.-cảnh-báo-sos-khẩn-cấp)

[4.3.13. Chế độ học (School Mode)	75](#4.3.13.-chế-độ-học-\(school-mode\))

[4.3.14. Giám sát YouTube \+ AI	75](#4.3.14.-giám-sát-youtube-+-ai)

[4.3.15. Báo cáo và thống kê	76](#4.3.15.-báo-cáo-và-thống-kê)

[4.4. Kiểm thử phần mềm	76](#4.4.-kiểm-thử-phần-mềm)

[4.4.1. Chiến lược kiểm thử	76](#4.4.1.-chiến-lược-kiểm-thử)

[4.4.2. Kết quả Unit Test Backend	77](#4.4.2.-kết-quả-unit-test-backend)

[4.4.3. Tổng kết kiểm thử	83](#4.4.3.-tổng-kết-kiểm-thử)

[4.5. Triển khai sản phẩm	83](#4.5.-triển-khai-sản-phẩm)

[**CHƯƠNG 5: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN	85**](#chương-5:-kết-luận-và-hướng-phát-triển)

[5.1. Kết quả đạt được	85](#5.1.-kết-quả-đạt-được)

[5.1.1. Về sản phẩm	85](#5.1.1.-về-sản-phẩm)

[5.1.2. Về chức năng	85](#5.1.2.-về-chức-năng)

[5.1.3. Về kiến trúc và kỹ thuật	86](#5.1.3.-về-kiến-trúc-và-kỹ-thuật)

[5.1.4. Về kiểm thử	87](#5.1.4.-về-kiểm-thử)

[5.1.5. Về quy trình phát triển	87](#5.1.5.-về-quy-trình-phát-triển)

[5.2. Hạn chế của đồ án	87](#5.2.-hạn-chế-của-đồ-án)

[5.3. Hướng phát triển trong tương lai	89](#5.3.-hướng-phát-triển-trong-tương-lai)

[5.4. Nhận xét tổng kết	90](#5.4.-nhận-xét-tổng-kết)

[**TÀI LIỆU THAM KHẢO	91**](#tài-liệu-tham-khảo)

[**PHỤ LỤC	96**](#phụ-lục)

# 

**DANH MỤC TỪ VIẾT TẮT**

| Từ viết tắt | Diễn giải đầy đủ |
| :---- | :---- |
| **AI** | Artificial Intelligence — Trí tuệ nhân tạo |
| **API** | Application Programming Interface — Giao diện lập trình ứng dụng |
| **CRUD** | Create, Read, Update, Delete — Các thao tác dữ liệu cơ bản |
| **ERD** | Entity Relationship Diagram — Sơ đồ quan hệ thực thể |
| **FCM** | Firebase Cloud Messaging — Dịch vụ gửi thông báo đẩy của Google |
| **GPS** | Global Positioning System — Hệ thống định vị toàn cầu |
| **GVHD** | Giảng Viên Hướng Dẫn |
| **HTTP** | HyperText Transfer Protocol — Giao thức truyền siêu văn bản |
| **HTTPS** | HTTP Secure — HTTP bảo mật |
| **HUTECH** | Trường Đại học Công nghệ Thành phố Hồ Chí Minh |
| **JWT** | JSON Web Token — Chuẩn xác thực dựa trên token JSON |
| **LAN** | Local Area Network — Mạng cục bộ |
| **MSSV** | Mã Số Sinh Viên |
| **MVC** | Model-View-Controller — Mô hình kiến trúc phần mềm |
| **ORM** | Object-Relational Mapping — Ánh xạ đối tượng quan hệ |
| **REST** | Representational State Transfer — Kiến trúc dịch vụ web |
| **SOS** | Save Our Souls — Tín hiệu khẩn cấp |
| **SQL** | Structured Query Language — Ngôn ngữ truy vấn có cấu trúc |
| **UC** | Use Case — Trường hợp sử dụng |
| **UI** | User Interface — Giao diện người dùng |
| **UX** | User Experience — Trải nghiệm người dùng |
| **VPN** | Virtual Private Network — Mạng riêng ảo |

**DANH MỤC HÌNH ẢNH**  
**DANH MỤC BẢNG BIỂU**

# **CHƯƠNG 1: MỞ ĐẦU** {#chương-1:-mở-đầu}

## **1.1. Lý do chọn đề tài** {#1.1.-lý-do-chọn-đề-tài}

Trong thập kỷ vừa qua, sự phổ biến của điện thoại thông minh, máy tính bảng và các thiết bị điện tử kết nối Internet đã tạo ra một cuộc cách mạng trong cách con người tiếp cận các thiết bị điện tử, đặc biệt là trẻ em trong việc tiếp cận thông tin và giải trí. Theo thống kê của Tổ chức Y tế Thế giới (WHO) và nhiều nghiên cứu độc lập, tỷ lệ trẻ em từ 3 đến 15 tuổi sử dụng thiết bị điện tử hơn 4 giờ mỗi ngày đang tăng nhanh ở các quốc gia đang phát triển, trong đó có Việt Nam. Báo cáo của UNICEF Việt Nam năm 2022 chỉ ra rằng trẻ em trong độ tuổi tiểu học và trung học cơ sở dành trung bình từ 3 đến 6 giờ mỗi ngày trước các màn hình thiết bị, bao gồm việc xem video trực tuyến, chơi game và sử dụng mạng xã hội.

Tình trạng sử dụng thiết bị không được kiểm soát đặt ra nhiều lo ngại nghiêm trọng về sức khỏe và sự phát triển toàn diện của trẻ:

\- Sức khỏe thể chất: Tiếp xúc màn hình kéo dài gây suy giảm thị lực, rối loạn giấc ngủ (đặc biệt khi dùng thiết bị vào ban đêm), và giảm hoạt động thể chất dẫn đến thừa cân béo phì.  
\- Sức khỏe tâm thần: Nghiện game, nghiện mạng xã hội và các rối loạn hành vi liên quan là những hệ quả được ghi nhận rõ rệt ở trẻ em thiếu sự giám sát.  
\- An toàn trực tuyến: Trẻ em có thể vô tình tiếp cận nội dung không phù hợp với lứa tuổi trên YouTube, mạng xã hội hoặc các trang web có hại, gây ra những tác động tâm lý tiêu cực.  
\- Học tập và phát triển: Thói quen sử dụng thiết bị quá mức cản trở việc học bài, đọc sách, và các hoạt động phát triển kỹ năng thiết yếu.

Trước những thực trạng đó, nhiều bậc phụ huynh mong muốn có một công cụ hiệu quả để kiểm soát và giám sát thời gian con trẻ sử dụng thiết bị, nhưng vẫn tôn trọng sự tự chủ của trẻ thay vì áp đặt một cách cứng nhắc. Các giải pháp parental control hiện có trên thị trường (Google Family Link, Kaspersky Safe Kids, Qustodio) chủ yếu hướng đến người dùng quốc tế, giao diện tiếng Anh, phức tạp trong cấu hình, và thường yêu cầu phí đăng ký hàng tháng tạo ra rào cản lớn với phụ huynh Việt Nam.

Xuất phát từ nhu cầu thực tế đó, nhóm chúng tôi đề xuất và xây dựng KidFun một ứng dụng di động Android kiểm soát thời gian sử dụng thiết bị thông minh dành riêng cho thị trường Việt Nam. KidFun là một ứng dụng duy nhất, cài đặt được trên cả thiết bị của phụ huynh và thiết bị của trẻ em, với hai chế độ tương ứng (Parent mode và Child mode) chọn sau khi đăng nhập. Ứng dụng được thiết kế với triết lý "Soft Warning" (cảnh báo mềm): thay vì đột ngột cắt quyền truy cập của trẻ, hệ thống tiếp cận dần dần thông qua các lớp cảnh báo được cá nhân hóa, khuyến khích trẻ tự quản lý thời gian và tạo điều kiện cho phụ huynh tương tác hai chiều với con thay vì chỉ áp đặt. Ứng dụng hỗ trợ giao tiếp theo thời gian thực giữa thiết bị di động của phụ huynh và thiết bị di động của trẻ, giúp phụ huynh linh hoạt trong việc phê duyệt hoặc từ chối yêu cầu thêm giờ ngay trên điện thoại của mình, đồng thời cung cấp báo cáo chi tiết về hành vi sử dụng thiết bị

## **1.2. Mục tiêu đề tài** {#1.2.-mục-tiêu-đề-tài}

Đề tài hướng đến xây dựng một ứng dụng di động Android hoàn chỉnh kèm theo hạ tầng máy chủ hỗ trợ, gồm hai thành phần được tích hợp chặt chẽ với nhau:

1\. Ứng dụng di động KidFun (Android)

Đây là sản phẩm chính của đồ án một ứng dụng Flutter chạy trên hệ điều hành Android, sau khi đăng nhập sẽ cho phép chọn chế độ:

\- Chế độ Phụ huynh (Parent mode): Phụ huynh quản lý tài khoản, hồ sơ con, thiết bị, cấu hình giới hạn thời gian, danh sách chặn ứng dụng và website, theo dõi vị trí GPS, xem báo cáo thống kê, nhận và xử lý yêu cầu thêm giờ từ con, nhận cảnh báo SOS và cảnh báo AI về nội dung không phù hợp tất cả ngay trên điện thoại Android của mình.

\- Chế độ Trẻ em (Child mode): Sau khi liên kết với hồ sơ của phụ huynh qua quét mã QR, ứng dụng chạy nền liên tục, thu thập dữ liệu sử dụng các ứng dụng khác trên máy, hiển thị thời gian còn lại theo dạng đồng hồ đếm ngược, phát cảnh báo mềm ở các mốc 30/15/5 phút, khóa màn hình (kiosk mode) khi hết giờ, cho phép trẻ gửi yêu cầu thêm giờ kèm lý do, và cung cấp nút SOS khẩn cấp.

Để thực hiện được các tính năng giám sát đặc thù, ứng dụng tích hợp các API đặc quyền của Android được viết bằng Kotlin native: \`UsageStatsManager\` (đọc thống kê thời gian sử dụng), \`AccessibilityService\` (phát hiện và chặn ứng dụng), \`DevicePolicyManager\` (khóa thiết bị), \`ForegroundService\` (chạy nền 24/7), \`VpnService\` (lọc nội dung web) và \`NotificationListenerService\` (theo dõi thông báo).

2\. Backend API Server

Máy chủ trung tâm hỗ trợ ứng dụng di động, xử lý toàn bộ logic nghiệp vụ:  
\- Xác thực và phân quyền người dùng bằng JWT.  
\- Lưu trữ và đồng bộ cấu hình, nhật ký hoạt động qua cơ sở dữ liệu PostgreSQL.  
\- Giao tiếp thời gian thực với ứng dụng di động ở cả hai thiết bị (phụ huynh và trẻ) thông qua Socket.IO.  
\- Gửi thông báo đẩy (push notification) qua Firebase Cloud Messaging (FCM) khi ứng dụng chạy nền hoặc đã đóng.  
\- Phân tích nội dung (tiêu đề, kênh) các video YouTube mà trẻ đã xem bằng mô hình AI Llama 4 Scout (qua Groq Cloud và OpenRouter) để phát hiện nội dung không an toàn.

## **1.3. Phạm vi và đối tượng nghiên cứu** {#1.3.-phạm-vi-và-đối-tượng-nghiên-cứu}

Phạm vi nghiên cứu:

\- Ứng dụng tập trung vào nền tảng Android (phiên bản 8.0 Oreo / API 26 trở lên), do Android cho phép truy cập các API giám sát hệ thống (\`UsageStatsManager\`, \`AccessibilityService\`, \`DevicePolicyManager\`, \`VpnService\`, \`NotificationListenerService\`) cần thiết cho tính năng kiểm soát thiết bị mà nền tảng iOS không cung cấp tương đương ở cấp độ ứng dụng bên thứ ba.

\- Ứng dụng được phát triển bằng Flutter (Dart) cho phần giao diện và logic nghiệp vụ chung; phần tương tác với API hệ thống Android được viết bằng Kotlin native, kết nối với Flutter qua \`MethodChannel\`/\`EventChannel\`.

\- Trong khuôn khổ đồ án, nhóm chưa phát triển phiên bản iOS (do giới hạn về API parental control bên thứ ba của Apple) và không phát triển giao diện web/desktop.

\- Tính năng AI giám sát YouTube được tích hợp ở mức cơ bản (phân tích metadata tiêu đề, kênh video) sử dụng mô hình Llama 4 Scout (Meta) truy cập qua Groq Cloud (provider chính) và OpenRouter (provider dự phòng).

\- Backend được triển khai trên môi trường cloud (Railway kết hợp PostgreSQL trên Supabase) phục vụ cho mục đích demo và bảo vệ; chưa nghiên cứu quy mô production với hàng triệu người dùng.

Đối tượng nghiên cứu:

\- Người dùng phụ huynh: Các bậc cha mẹ hoặc người giám hộ tại Việt Nam có nhu cầu quản lý thời gian sử dụng thiết bị di động của trẻ em trong gia đình.  
\- Người dùng trẻ em: Trẻ em trong độ tuổi từ 5 đến 15 tuổi đang sử dụng thiết bị Android cá nhân.  
\- Công nghệ nghiên cứu: Framework Flutter cho giao diện đa nền tảng, ngôn ngữ Kotlin và các API đặc quyền của Android, kiến trúc REST API với Node.js/Express, giao tiếp thời gian thực qua Socket.IO, xác thực JWT, quản lý dữ liệu quan hệ với Prisma ORM và PostgreSQL, push notification với Firebase Cloud Messaging, và ứng dụng AI (mô hình Llama 4 Scout qua Groq Cloud) trong phân tích nội dung.

## **1.4. Phương pháp thực hiện** {#1.4.-phương-pháp-thực-hiện}

Nhóm áp dụng quy trình phát triển phần mềm Agile/Scrum với 10 sprint, mỗi sprint kéo dài khoảng một tuần:

\- Khảo sát và phân tích yêu cầu (Sprint 1): Nghiên cứu thực trạng, tham khảo tài liệu kỹ thuật về API Android, xây dựng danh sách yêu cầu chức năng và phi chức năng, lựa chọn công nghệ.

\- Thiết kế hệ thống (Sprint 1–2): Thiết kế kiến trúc tổng thể, sơ đồ cơ sở dữ liệu, thiết kế API contract giữa mobile và backend, wireframe các màn hình ứng dụng di động.

\- Cài đặt (Sprint 2–9): Phát triển từng tính năng theo thứ tự ưu tiên, bắt đầu từ lõi (xác thực, quản lý hồ sơ, giới hạn thời gian) đến các tính năng nâng cao (vị trí GPS, SOS, AI, báo cáo). Mỗi sprint backend và mobile được phát triển song song với API contract làm điểm đồng bộ.

\- Kiểm thử (Song song với cài đặt và Sprint 10): Viết unit test, integration test cho backend; kiểm thử thủ công ứng dụng di động trên thiết bị Android thật ở nhiều cấu hình khác nhau; kiểm thử end-to-end theo kịch bản người dùng thực tế.

\- Hoàn thiện và triển khai (Sprint 10): Sửa lỗi, tối ưu hiệu năng, build APK release đã ký, chuẩn bị dữ liệu demo cho buổi bảo vệ.

## **1.5. Cấu trúc báo cáo** {#1.5.-cấu-trúc-báo-cáo}

Báo cáo được tổ chức thành 5 chương như sau:

\- Chương 1  Mở đầu: Trình bày lý do chọn đề tài, mục tiêu, phạm vi nghiên cứu và phương pháp thực hiện.

\- Chương 2  Cơ sở lý thuyết: Giới thiệu các công nghệ, framework, thư viện và API đặc quyền được sử dụng trong ứng dụng di động Android KidFun; trình bày nền tảng lý thuyết về quy trình phát triển phần mềm Agile/Scrum.  
\- Chương 3  Phân tích và Thiết kế hệ thống: Phân tích yêu cầu chức năng và phi chức năng; trình bày các sơ đồ UML (Use Case, Class, Sequence, Activity); thiết kế cơ sở dữ liệu (ERD); thiết kế giao diện màn hình mobile cho cả hai chế độ Parent và Child.

\- Chương 4  Cài đặt và Kiểm thử: Mô tả môi trường phát triển Flutter \+ Android Studio; giới thiệu các chức năng chính của ứng dụng qua hình ảnh chụp màn hình điện thoại; trình bày kết quả kiểm thử theo bảng test case.

\- Chương 5 Kết luận và Hướng phát triển: Đánh giá kết quả đạt được, nêu hạn chế và đề xuất hướng phát triển tiếp theo.

# **CHƯƠNG 2: CƠ SỞ LÝ THUYẾT** {#chương-2:-cơ-sở-lý-thuyết}

## **2.1. Tổng quan kiến trúc** {#2.1.-tổng-quan-kiến-trúc}

KidFun là một ứng dụng di động Android có kiến trúc client–server, gồm hai thành phần chính:  
1\. **Mobile Client:** Ứng dụng Android phát triển bằng **Flutter** (Dart) cho phần giao diện và logic chung; **Kotlin native** cho các tính năng đặc thù cần truy cập API hệ thống Android. Flutter và Kotlin trao đổi dữ liệu thông qua MethodChannel và EventChannel.  
2\. **Backend Server:** RESTful API được xây dựng bằng **Node.js \+ Express**, sử dụng **Prisma ORM** thao tác với cơ sở dữ liệu **PostgreSQL** (hosted trên Supabase), tích hợp **Socket.IO** cho giao tiếp thời gian thực và **Firebase Cloud Messaging** cho thông báo đẩy.

## **2.2. Công nghệ phía Mobile (thành phần chính của đồ án)** {#2.2.-công-nghệ-phía-mobile-(thành-phần-chính-của-đồ-án)}

### *2.2.1. Flutter và ngôn ngữ Dart* {#2.2.1.-flutter-và-ngôn-ngữ-dart}

**Flutter** là framework UI mã nguồn mở do Google phát triển và phát hành lần đầu năm 2017, cho phép xây dựng ứng dụng native trên Android, iOS và nhiều nền tảng khác từ một codebase duy nhất viết bằng ngôn ngữ **Dart**. Khác với các framework cross-platform truyền thống dựa trên WebView hoặc bridge JavaScript, Flutter biên dịch trực tiếp ra mã native ARM/x86 và sử dụng engine rendering riêng (**Skia/Impeller**) để vẽ giao diện trực tiếp lên canvas, đảm bảo tốc độ khung hình ổn định 60–120FPS và giao diện đồng nhất giữa các phiên bản Android.

**Dart** là ngôn ngữ lập trình hướng đối tượng, type-safe, hỗ trợ cả lập trình đồng bộ và bất đồng bộ (async/await), hot reload trong khi phát triển, giúp rút ngắn đáng kể chu kỳ thử nghiệm UI.

Dự án KidFun sử dụng **Flutter SDK 3.x** với **Dart SDK 3.x** để xây dựng toàn bộ giao diện ứng dụng cho cả hai chế độ Parent và Child trong cùng một APK.

### *2.2.2. Riverpod — Quản lý trạng thái* {#2.2.2.-riverpod-—-quản-lý-trạng-thái}

**Riverpod** là thư viện quản lý trạng thái (state management) thế hệ mới cho Flutter, được phát triển bởi Remi Rousselet (tác giả của Provider). Riverpod khắc phục các nhược điểm của Provider, không phụ thuộc vào BuildContext, hỗ trợ compile-time safety, dễ kiểm thử và dễ kết hợp nhiều provider thành cây phụ thuộc rõ ràng.

KidFun sử dụng flutter\_riverpod kết hợp riverpod\_annotation \+ riverpod\_generator để tự sinh code các provider, với các loại provider chính:  
\- StateNotifierProvider quản lý trạng thái xác thực (AuthState), trạng thái hồ sơ đang chọn.  
\- AsyncNotifierProvider cho các dữ liệu lấy bất đồng bộ từ API (danh sách hồ sơ, danh sách thiết bị, lịch sử vị trí).  
\- StreamProvider cho các luồng dữ liệu real-time từ Socket.IO (thời gian còn lại, yêu cầu thêm giờ).

### *2.2.3. go\_router — Điều hướng* {#2.2.3.-go_router-—-điều-hướng}

**go\_router** là thư viện điều hướng (navigation) khai báo (declarative) chính thức do Flutter team duy trì, dựa trên Navigator 2.0. So với cách điều hướng truyền thống bằng Navigator.push, go\_router cho phép định nghĩa toàn bộ cây route ở một chỗ, hỗ trợ deep link và xử lý back stack rõ ràng. KidFun dùng go\_router để điều hướng giữa các màn hình: Splash → Login → Mode Selection → Parent/Child Dashboard → các màn hình chức năng.

### *2.2.4. Dio — HTTP client* {#2.2.4.-dio-—-http-client}

**Dio** là thư viện HTTP client mạnh mẽ cho Dart, hỗ trợ interceptor, FormData, upload/download tiến trình, hủy request và retry tự động. KidFun cấu hình một instance Dio singleton với:  
\- **Base URL** trỏ về backend Railway.  
\- **Authorization Interceptor** tự động đính kèm JWT token từ flutter\_secure\_storage vào header Authorization: Bearer cho mỗi request.  
\- **Error Interceptor** xử lý lỗi 401 (token hết hạn → tự động đăng xuất và chuyển về màn hình Login) và lỗi mạng (hiển thị snackbar thông báo).

### *2.2.5. flutter\_secure\_storage* {#2.2.5.-flutter_secure_storage}

Thư viện lưu trữ key–value được mã hóa, sử dụng **Keystore** trên Android. KidFun dùng flutter\_secure\_storage để lưu JWT token, refresh token và thông tin nhạy cảm khác, đảm bảo dữ liệu xác thực không bị truy cập bởi ứng dụng khác hoặc bị đọc khi thiết bị bị mất.

### *2.2.6. Socket.IO Client cho Flutter* {#2.2.6.-socket.io-client-cho-flutter}

**socket\_io\_client** là gói Dart kết nối với máy chủ Socket.IO. KidFun dùng để:  
\- **Parent mode:** Kết nối room family\_{userId}, nhận event timeExtensionRequest khi trẻ xin thêm giờ, sosAlert khi trẻ kích hoạt SOS, deviceOnline/deviceOffline để cập nhật trạng thái thiết bị con.  
\- **Child mode:** Gửi event joinDevice khi khởi động, nhận policyUpdate khi phụ huynh thay đổi cấu hình, nhận timeExtensionResponse khi yêu cầu được duyệt/từ chối, nhận lockDevice khi hết giờ.

### *2.2.7. Firebase Cloud Messaging (FCM) trên Flutter* {#2.2.7.-firebase-cloud-messaging-(fcm)-trên-flutter}

KidFun tích hợp firebase\_core và firebase\_messaging để nhận push notification ngay cả khi ứng dụng đang ở chế độ background hoặc đã bị đóng. Token FCM của mỗi thiết bị được đăng ký lên backend qua endpoint POST /api/fcm-tokens. Khi có sự kiện quan trọng (trẻ xin thêm giờ, cảnh báo SOS, cảnh báo AI), backend gửi thông báo qua Firebase Admin SDK → FCM → thiết bị di động. Trên thiết bị, flutter\_local\_notifications hiển thị notification với hành động (Approve/Reject) trực tiếp trong khay thông báo.

### *2.2.8. Mapbox Maps Flutter* {#2.2.8.-mapbox-maps-flutter}

KidFun dùng mapbox\_maps\_flutter để hiển thị bản đồ trong các tính năng:  
\- **Theo dõi vị trí GPS:** Hiển thị vị trí hiện tại và lịch sử di chuyển của thiết bị trẻ trên bản đồ.  
\- **Quản lý Geofence:** Cho phép phụ huynh vẽ vùng an toàn (hình tròn) trên bản đồ bằng cách chạm chọn tâm và kéo chỉnh bán kính.  
\- **Hiển thị cảnh báo SOS:** Hiển thị marker tại vị trí trẻ kích hoạt SOS.

### *2.2.9. fl\_chart — Biểu đồ thống kê* {#2.2.9.-fl_chart-—-biểu-đồ-thống-kê}

fl\_chart là thư viện vẽ biểu đồ thuần Dart cho Flutter, hỗ trợ BarChart, LineChart, PieChart, RadarChart với hiệu năng cao và tùy biến mạnh. KidFun dùng để hiển thị báo cáo:  
\- Thời gian sử dụng theo từng ngày trong tuần (BarChart).  
\- Phân bổ thời gian theo từng ứng dụng (PieChart).  
\- Xu hướng sử dụng trong 30 ngày qua (LineChart).

### *2.2.10. Các thư viện Flutter khác* {#2.2.10.-các-thư-viện-flutter-khác}

| Thư viện | Mục đích |
| ----- | ----- |
| qr\_flutter | Sinh mã QR (Parent mode) để hiển thị mã liên kết thiết bị |
| mobile\_scanner | Quét mã QR bằng camera (Child mode) khi liên kết thiết bị |
| geolocator | Truy cập GPS để lấy tọa độ hiện tại |
| permission\_handler | Yêu cầu và kiểm tra quyền (camera, GPS, microphone, notification) |
| record | Ghi âm trong tính năng SOS (ghi 5 giây âm thanh gửi kèm) |
| audioplayers | Phát âm thanh cảnh báo mềm |
| google\_sign\_in | Đăng nhập Google OAuth 2.0 |
| google\_fonts | Tải font Google trực tiếp trong app |
| flutter\_dotenv | Đọc biến môi trường (API URL, Mapbox token) từ file .env |
| intl | Định dạng ngày giờ và số theo locale Vietnamese |

## **2.3. Kotlin Native và API đặc quyền của Android** {#2.3.-kotlin-native-và-api-đặc-quyền-của-android}

Ngoài Flutter, KidFun sử dụng **Kotlin** để viết các thành phần native của Android. Kotlin là ngôn ngữ chính thức của Android từ năm 2019, tương thích 100% với Java, có cú pháp ngắn gọn và an toàn null. Các thành phần Kotlin chạy ngoài "main isolate" của Flutter và giao tiếp với Dart code qua MethodChannel (gọi hàm hai chiều) và EventChannel (luồng sự kiện một chiều).

### *2.3.1. UsageStatsManager* {#2.3.1.-usagestatsmanager}

UsageStatsManager là API hệ thống của Android (yêu cầu quyền đặc biệt PACKAGE\_USAGE\_STATS) cho phép đọc thống kê thời gian sử dụng tất cả các ứng dụng trên thiết bị. KidFun sử dụng API này trong file UsageStatsHelper.kt để:  
\- Tính tổng thời gian thiết bị được sử dụng trong ngày (getTodayUsage).  
\- Tính thời gian sử dụng từng ứng dụng theo package name (getAppUsage).  
\- Gửi dữ liệu thống kê này về backend mỗi phút để phục vụ tính năng báo cáo và per-app time limit.

### *2.3.2. AccessibilityService* {#2.3.2.-accessibilityservice}

Dịch vụ trợ năng của Android cho phép ứng dụng theo dõi và phản ứng với các sự kiện giao diện hệ thống (window state changed, content changed). KidFun triển khai AppBlockerService.kt kế thừa \`AccessibilityService để:  
\- Theo dõi sự kiện TYPE\_WINDOW\_STATE\_CHANGED để phát hiện ứng dụng nào đang được mở (foreground app).  
\- Khi trẻ mở một ứng dụng nằm trong danh sách bị chặn, lập tức gọi performGlobalAction(GLOBAL\_ACTION\_HOME) để đưa về màn hình chính, kèm thông báo "Ứng dụng này đã bị phụ huynh chặn".  
\- Trong file YouTubeTracker.kt, AccessibilityService cũng được dùng để đọc tiêu đề video và tên kênh YouTube mà trẻ đang xem (thông qua việc duyệt cây AccessibilityNodeInfo).

### *2.3.3. DevicePolicyManager và Device Admin* {#2.3.3.-devicepolicymanager-và-device-admin}

DevicePolicyManager cho phép ứng dụng được cài đặt với quyền **Device Admin** thực hiện các thao tác bảo mật cấp hệ thống. KidFun đăng ký KidFunDeviceAdminReceiver.kt để:  
\- Khóa màn hình ngay lập tức khi trẻ hết giờ sử dụng (lockNow()).  
\- Ngăn người dùng tự gỡ cài đặt ứng dụng KidFun mà chưa có sự đồng ý của phụ huynh.

### *2.3.4. ForegroundService* {#2.3.4.-foregroundservice}

Để duy trì hoạt động liên tục 24/7 và tránh bị Android tắt khi hệ thống thiếu bộ nhớ, KidFun triển khai KidFunService.kt là một **Foreground Service** với thông báo thường trú trên thanh thông báo. Service này chịu trách nhiệm:  
\- Đếm thời gian sử dụng theo thời gian thực.  
\- Định kỳ thu thập dữ liệu từ UsageStatsManager và gửi heartbeat về server qua HTTP.  
\- Duy trì kết nối Socket.IO nền để nhận lệnh real-time từ phụ huynh.  
\- Phát cảnh báo mềm ở các mốc thời gian được cấu hình.

### *2.3.5. VpnService (Web Filtering)* {#2.3.5.-vpnservice-(web-filtering)}

VpnService của Android cho phép ứng dụng tạo một VPN cục bộ chặn lưu lượng mạng mà không cần root thiết bị. KidFun dùng kỹ thuật này (lớp con VpnFilterService) để:  
\- Bắt tất cả lưu lượng DNS đi qua VPN.  
\- Đối chiếu mỗi domain được truy cập với danh sách BlockedWebsite và BlockedCategory đã cấu hình.  
\- Trả về địa chỉ IP loopback (127.0.0.1) cho các domain bị chặn, khiến trình duyệt không tải được trang.

### *2.3.6. NotificationListenerService* {#2.3.6.-notificationlistenerservice}

Dịch vụ cho phép ứng dụng đọc tất cả thông báo đến trên thiết bị (cần phụ huynh cấp quyền BIND\_NOTIFICATION\_LISTENER\_SERVICE). KidFun dùng để:  
\- Phát hiện thông báo từ các ứng dụng nhắn tin (Messenger, Zalo, SMS) để cảnh báo phụ huynh khi trẻ nhận tin từ người lạ.  
\- Phối hợp với AI để phân tích nội dung thông báo và phát hiện nguy cơ bắt nạt qua mạng.

### *2.3.7. BootReceiver* {#2.3.7.-bootreceiver}

BootReceiver.kt là một BroadcastReceiver đăng ký sự kiện BOOT\_COMPLETED để tự động khởi động lại KidFunService ngay sau khi điện thoại bật, đảm bảo việc giám sát không bị gián đoạn khi trẻ tắt máy rồi bật lại.

### *2.3.8. MethodChannel — Cầu nối Flutter ↔ Kotlin* {#2.3.8.-methodchannel-—-cầu-nối-flutter-↔-kotlin}

KidFun định nghĩa các MethodChannel theo namespace com.kidfun.mobile/\<feature\>, ví dụ:  
\- com.kidfun.mobile/usage\_stats: Flutter gọi để lấy số liệu sử dụng từng app.  
\- com.kidfun.mobile/app\_blocker: Flutter gọi để bật/tắt chặn app, cập nhật danh sách chặn.  
\- com.kidfun.mobile/device\_admin: Flutter gọi để khóa thiết bị.  
\- com.kidfun.mobile/service\_control: Flutter gọi để khởi động/dừng KidFunService.

## **2.4. Công nghệ phía Backend** {#2.4.-công-nghệ-phía-backend}

### *2.4.1. Node.js và Express.js* {#2.4.1.-node.js-và-express.js}

**Node.js** (phiên bản 20 LTS) là môi trường chạy JavaScript phía máy chủ dựa trên V8 Engine, sử dụng mô hình **event-driven, non-blocking I/O**, phù hợp với ứng dụng nhiều kết nối đồng thời, ít CPU-bound như KidFun.

**Express.js** là framework web tối giản cho Node.js, cung cấp hệ thống middleware linh hoạt để xây dựng REST API. KidFun có hơn 60 endpoint REST được chia theo các nhóm route (/api/auth, /api/profiles, /api/devices, /api/child, /api/location, /api/sos, /api/youtube, v.v.). Các middleware tích hợp gồm: Helmet (security headers), CORS, Morgan (logging), express-rate-limit (giới hạn tốc độ chống brute force), express-validator (kiểm tra dữ liệu đầu vào).

### *2.4.2. Prisma ORM và PostgreSQL* {#2.4.2.-prisma-orm-và-postgresql}

**Prisma** là ORM thế hệ mới type-safe cho Node.js, gồm Prisma Schema (DSL khai báo mô hình), Prisma Migrate (quản lý lịch sử migration) và Prisma Client (API truy vấn auto-generated). KidFun có hơn **30 model** trong schema.prisma, bao gồm: User, Profile, Device, TimeLimit, UsageSession, TimeExtensionRequest, BlockedApp, BlockedWebsite, LocationLog, Geofence, SOSAlert, SchoolSchedule, YouTubeLog, AIAlert, Notification, FCMToken, v.v.

**PostgreSQL** là hệ quản trị cơ sở dữ liệu quan hệ mã nguồn mở mạnh mẽ. KidFun triển khai PostgreSQL trên **Supabase** — nền tảng Backend-as-a-Service cung cấp PostgreSQL quản lý, có connection pooling sẵn (PgBouncer), dashboard trực quan và sao lưu tự động.

### *2.4.3. Socket.IO* {#2.4.3.-socket.io}

**Socket.IO** là thư viện cho phép giao tiếp **bidirectional, event-based** thời gian thực giữa server và client, xây dựng trên WebSocket với fallback HTTP long-polling. KidFun dùng Socket.IO để đồng bộ trạng thái giữa thiết bị di động của phụ huynh và trẻ:

| Sự kiện | Hướng | Mô tả |
| ----- | ----- | ----- |
| joinDevice | Child Mobile → Server | Thiết bị trẻ tham gia room |
| joinParent | Parent Mobile → Server | Thiết bị phụ huynh tham gia room |
| timeUpdate | Server → Child Mobile | Đẩy thời gian còn lại |
| policyUpdate | Server → Child Mobile | Cập nhật cấu hình giới hạn |
| requestTimeExtension | Child Mobile → Server | Trẻ xin thêm giờ |
| timeExtensionRequest | Server → Parent Mobile | Chuyển tiếp yêu cầu đến phụ huynh |
| respondTimeExtension | Parent Mobile → Server | Phụ huynh phê duyệt/từ chối |
| timeExtensionResponse | Server → Child Mobile | Chuyển kết quả về trẻ |
| sosAlert | Child Mobile → Server → Parent Mobile | Cảnh báo SOS khẩn cấp |
| deviceOnline/deviceOffline | Server → Parent Mobile | Cập nhật trạng thái thiết bị con |

Tất cả thành viên trong cùng một gia đình tham gia chung **room** family\_{userId} để mọi sự kiện chỉ phát tán trong phạm vi gia đình đó.

### *2.4.4. JSON Web Token (JWT) và bcryptjs* {#2.4.4.-json-web-token-(jwt)-và-bcryptjs}

**JWT** (RFC 7519\) là chuẩn mở định nghĩa cách trao đổi thông tin an toàn dưới dạng JSON được ký số. KidFun cấp JWT thời hạn 24 giờ sau khi đăng nhập thành công, đính kèm vào header Authorization: Bearer cho mọi API yêu cầu xác thực. Middleware authenticate xác minh chữ ký và thời hạn; middleware authorizeParent đảm bảo chỉ phụ huynh sở hữu hồ sơ mới được phép sửa cấu hình.

**bcryptjs** băm mật khẩu với salt factor 10 trước khi lưu vào database, đảm bảo mật khẩu không thể bị khôi phục ngược kể cả khi database bị lộ.

### *2.4.5. Firebase Cloud Messaging (FCM) — Admin SDK* {#2.4.5.-firebase-cloud-messaging-(fcm)-—-admin-sdk}

Trên backend, KidFun dùng **Firebase Admin SDK** để gửi push notification đến thiết bị di động của phụ huynh khi:  
\- Trẻ gửi yêu cầu thêm giờ (kể cả khi app phụ huynh đang đóng).  
\- Trẻ kích hoạt SOS (priority: high — hiển thị ngay trên màn hình khóa).  
\- AI Worker phát hiện nội dung video YouTube nguy hiểm.  
\- Sự kiện geofence (trẻ ra/vào vùng an toàn).

### *2.4.6. Triển khai (Deployment)* {#2.4.6.-triển-khai-(deployment)}

Backend được deploy trên **Railway**, nền tảng Platform-as-a-Service hỗ trợ auto-deploy từ GitHub mỗi khi có commit mới vào nhánh main/develop. Railway tự động cấp HTTPS, hỗ trợ WebSocket cho Socket.IO và quản lý biến môi trường qua dashboard trực quan. Cơ sở dữ liệu PostgreSQL chạy trên **Supabase** với connection pool PgBouncer. Ngoài ra, nhóm cũng cấu hình sẵn một bản triển khai dự phòng trên Oracle Cloud VM (ARM Always Free) để đảm bảo dịch vụ không bị gián đoạn khi Railway xảy ra sự cố.

## **2.5. Trí tuệ nhân tạo — Llama 4 Scout qua Groq Cloud \+ OpenRouter** {#2.5.-trí-tuệ-nhân-tạo-—-llama-4-scout-qua-groq-cloud-+-openrouter}

KidFun sử dụng mô hình ngôn ngữ lớn mã nguồn mở **Llama 4 Scout** của Meta (kiến trúc Mixture-of-Experts 17 tỉ tham số kích hoạt, hỗ trợ đa ngôn ngữ bao gồm tiếng Việt) để phân tích nội dung video YouTube. Mô hình được truy cập qua hai nhà cung cấp inference với cơ chế fallback:  
\- **Groq Cloud (provider chính):** Sử dụng SDK groq-sdk với model meta-llama/llama-4-scout-17b-16e-instruct. Groq nổi bật với tốc độ inference cực nhanh nhờ kiến trúc phần cứng LPU (Language Processing Unit), thường trả về kết quả trong vòng 1–2 giây.  
\- **OpenRouter (provider dự phòng):** Sử dụng SDK openai (tương thích chuẩn OpenAI API) với model meta-llama/llama-4-scout:free để gọi qua endpoint OpenRouter. Khi Groq gặp lỗi hoặc quota tạm hết, AI Worker tự động chuyển sang OpenRouter.

**Luồng xử lý AI Worker:**  
1\. AI Worker chạy theo lịch định kỳ (cron hoặc node-schedule), truy vấn các bản ghi YouTubeLog với isAnalyzed \= false.  
2\. Với mỗi video, worker gọi API của Groq (hoặc OpenRouter nếu Groq fail) với prompt tiếng Việt yêu cầu phân loại theo các danh mục: SAFE, BULLY, SEXUAL, DRUG, VIOLENCE, SELF\_HARM, DISTURBING và mức độ nguy hiểm dangerLevel từ 1–5.  
3\. Worker parse phản hồi JSON từ AI, lưu kết quả vào YouTubeLog (dangerLevel, category, aiSummary) và đặt isAnalyzed \= true.  
4\. Nếu dangerLevel \> 3: tạo bản ghi AIAlert và gửi FCM push notification cảnh báo đến thiết bị di động của phụ huynh.

## **2.6. Quy trình phát triển phần mềm — Agile/Scrum** {#2.6.-quy-trình-phát-triển-phần-mềm-—-agile/scrum}

### *2.6.1. Mô hình Agile* {#2.6.1.-mô-hình-agile}

Agile là tập hợp các nguyên tắc phát triển phần mềm được công bố trong **Agile Manifesto** (2001), nhấn mạnh:  
\- **Cá nhân và tương tác** hơn quy trình và công cụ.  
\- **Phần mềm chạy được** hơn tài liệu đầy đủ.  
\- **Hợp tác với khách hàng** hơn đàm phán hợp đồng.  
\- **Phản ứng với thay đổi** hơn tuân theo kế hoạch.

### *2.6.2. Scrum Framework* {#2.6.2.-scrum-framework}

Scrum tổ chức công việc theo các **Sprint** ngắn (1–4 tuần). Nhóm KidFun áp dụng Scrum với các nghi thức:  
\- **Product Backlog:** Danh sách tính năng sắp xếp theo độ ưu tiên (P0 must-have, P1 should-have, P2 nice-to-have).  
\- **Sprint Planning:** Đầu mỗi sprint, nhóm chọn task từ backlog vào Sprint Backlog.  
\- **Daily Standup:** Cập nhật tiến độ hàng ngày qua nhóm chat.  
\- **Sprint Review:** Demo sản phẩm cuối sprint.  
\- **Sprint Retrospective:** Rút kinh nghiệm và cải tiến cho sprint sau.

Dự án KidFun được chia thành **10 sprint**:

| Sprint | Nội dung chính |
| ----- | ----- |
| 1 | Setup nền tảng (Backend Railway \+ Supabase, Flutter project) |
| 2 | Auth \+ Quản lý hồ sơ (mobile \+ backend) |
| 3 | Quản lý thiết bị \+ QR liên kết \+ Socket.IO |
| 4 | Giới hạn thời gian \+ Soft Warning \+ Xin thêm giờ ★ |
| 5 | Native Android (UsageStats, Accessibility, DevicePolicy) \+ Lock Screen |
| 6 | Demo giữa kỳ & Checkpoint với GVHD |
| 7 | GPS \+ Geofencing \+ SOS |
| 8 | Web Filter (VPN) \+ School Mode \+ Per-app Time Limit |
| 9 | Reports \+ AI YouTube \+ Notification Monitoring |
| 10 | Polish \+ Testing \+ Build APK release \+ Báo cáo |

### *2.6.3. Quản lý mã nguồn với Git và GitHub* {#2.6.3.-quản-lý-mã-nguồn-với-git-và-github}

Nhóm sử dụng **Git** và **GitHub** theo **Feature Branch Workflow**:  
1\. Mỗi task/tính năng phát triển trên một branch riêng (feat/mobile/lock-screen, feat/backend/sos-api).  
2\. Hoàn thành → tạo **Pull Request (PR)** về develop.  
3\. Thành viên khác review code, comment, approve.  
4\. Merge sau khi được approve.  
5\. Định kỳ merge develop → main sau khi kiểm thử toàn diện.  
Quy ước commit theo chuẩn **Conventional Commits**: feat(area): mô tả, fix(area): mô tả, chore(area): mô tả.

# 

# **CHƯƠNG 3: PHÂN TÍCH VÀ THIẾT KẾ HỆ THỐNG** {#chương-3:-phân-tích-và-thiết-kế-hệ-thống}

## **3.1. Khảo sát hiện trạng và yêu cầu hệ thống** {#3.1.-khảo-sát-hiện-trạng-và-yêu-cầu-hệ-thống}

### *3.1.1. Khảo sát hiện trạng* {#3.1.1.-khảo-sát-hiện-trạng}

Hiện nay trên thị trường có một số ứng dụng parental control phổ biến như **Google Family Link**, **Kaspersky Safe Kids**, **Qustodio**, **Bark**. Qua quá trình khảo sát và tham khảo phản hồi của người dùng, nhóm nhận thấy các hạn chế sau:

- **Giao diện và ngôn ngữ:** Hầu hết các sản phẩm dùng tiếng Anh, không phù hợp với phụ huynh Việt Nam ít tiếp xúc với công nghệ.  
- **Chi phí:** Qustodio, Bark yêu cầu gói đăng ký 5–15 USD/tháng — quá đắt so với thu nhập trung bình tại Việt Nam.  
- **Cứng nhắc trong kiểm soát:** Đa số sản phẩm chặn truy cập đột ngột khi hết giờ, không có giai đoạn cảnh báo mềm, gây căng thẳng cho trẻ và xung đột trong gia đình.  
- **Thiếu tương tác hai chiều:** Ít sản phẩm hỗ trợ trẻ xin thêm giờ và phụ huynh phê duyệt linh hoạt theo thời gian thực.  
- **Tách rời nhiều app:** Một số sản phẩm yêu cầu cài hai ứng dụng riêng cho phụ huynh và trẻ — gây phức tạp cho người dùng phổ thông.

KidFun giải quyết tất cả các vấn đề trên trong **một ứng dụng di động duy nhất** với giao diện tiếng Việt, miễn phí (hoặc chi phí rất thấp), cảnh báo mềm thông minh và tương tác real-time giữa phụ huynh và con cái. 

### *3.1.2. Yêu cầu chức năng (Functional Requirements)* {#3.1.2.-yêu-cầu-chức-năng-(functional-requirements)}

Nhóm chức năng Phụ huynh (Parent Mode trên app mobile):

| Mã | Tên chức năng | Mô tả |
| :---- | :---- | :---- |
| **FR-01** | Đăng ký tài khoản | Tạo tài khoản bằng email/mật khẩu hoặc Google Sign-In ngay trên app mobile |
| **FR-02** | Đăng nhập | Xác thực tài khoản, nhận JWT token, lưu vào \`flutter\_secure\_storage\` |
| **FR-03** | Quên mật khẩu | Nhận OTP qua email để đặt lại mật khẩu |
| **FR-04** | Chọn chế độ Parent | Sau khi đăng nhập lần đầu, chọn vai trò "Phụ huynh" |
| **FR-05** | Quản lý hồ sơ con | Tạo, sửa, xóa nhiều hồ sơ con (avatar, tên, ngày sinh) |
| **FR-06** | Tạo mã QR liên kết thiết bị | Sinh mã QR và mã 8 ký tự cho trẻ quét để liên kết |
| **FR-07** | Quản lý thiết bị | Xem danh sách thiết bị, trạng thái online/offline, xóa thiết bị |
| **FR-08** | Cài đặt giới hạn thời gian | Đặt giới hạn theo từng ngày trong tuần cho mỗi hồ sơ |
| **FR-09** | Chặn ứng dụng | Thêm/xóa app vào danh sách chặn theo package name |
| **FR-10** | Giới hạn thời gian theo app | Đặt giới hạn riêng cho từng app cụ thể |
| **FR-11** | Chặn website | Chặn theo domain hoặc danh mục (adult, gambling, violence, ...) |
| **FR-12** | Phê duyệt yêu cầu thêm giờ | Nhận push notification \+ xử lý real-time trên app |
| **FR-13** | Xem lịch sử hoạt động | Xem log app/website đã dùng |
| **FR-14** | Xem báo cáo thống kê | Biểu đồ sử dụng theo ngày/tuần (\`fl\_chart\`) |
| **FR-15** | Theo dõi vị trí GPS | Xem vị trí real-time và lịch sử di chuyển trên Mapbox |
| **FR-16** | Quản lý geofence | Tạo/sửa/xóa vùng an toàn bằng cách chạm trên bản đồ |
| **FR-17** | Nhận cảnh báo SOS | Nhận push notification ưu tiên cao \+ xem vị trí \+ nghe ghi âm |
| **FR-18** | Cấu hình chế độ học | Đặt lịch học theo ngày/giờ \+ danh sách app được phép |
| **FR-19** | Giám sát YouTube | Xem lịch sử video con đã xem \+ kết quả AI phân tích |
| **FR-20** | Xem cảnh báo AI | Nhận thông báo khi AI phát hiện nội dung nguy hiểm |

Nhóm chức năng Trẻ em (Child Mode trên cùng app mobile):

| Mã | Tên chức năng | Mô tả |
| :---- | :---- | :---- |
| **FR-21** | Liên kết thiết bị qua QR | Mở camera quét mã QR từ thiết bị của phụ huynh |
| **FR-22** | Xem thời gian còn lại | Đồng hồ đếm ngược cập nhật real-time từ Socket.IO |
| **FR-23** | Nhận cảnh báo mềm | Popup \+ rung \+ âm thanh tại mốc 30, 15, 5 phút |
| **FR-24** | Xin thêm giờ | Form nhập lý do, gửi qua Socket.IO đến phụ huynh |
| **FR-25** | Xem phản hồi thêm giờ | Nhận kết quả phê duyệt/từ chối real-time |
| **FR-26** | Màn hình khóa | Kiosk mode fullscreen khi hết giờ, không thoát được |
| **FR-27** | Kích hoạt SOS | Nhấn giữ 2 giây → gửi vị trí \+ ghi âm 5 giây |
| **FR-28** | Tự động khởi động sau reboot | BootReceiver tự bật lại KidFunService |

### *3.1.3. Yêu cầu phi chức năng (Non-functional Requirements)* {#3.1.3.-yêu-cầu-phi-chức-năng-(non-functional-requirements)}

| Mã | Nhóm | Yêu cầu |
| :---- | :---- | :---- |
| **NFR-01** | Hiệu năng | API trả về trong \< 500ms cho 95% request; Socket.IO event đến \< 200ms |
| **NFR-02** | Bảo mật | Mật khẩu băm bcrypt (salt=10); JWT thời hạn 24h; JWT lưu trong Android Keystore qua \`flutter\_secure\_storage\`; rate limiting chống brute force |
| **NFR-03** | Tính khả dụng | Backend trên Railway duy trì uptime ≥ 99% (có bản dự phòng trên Oracle Cloud VM khi cần); ForegroundService tự restart sau khi bị Android tắt |
| **NFR-04** | Khả năng mở rộng | JWT stateless cho phép scale horizontal; Socket.IO room độc lập theo gia đình |
| **NFR-05** | Tính dễ sử dụng | Giao diện mobile Material Design tối đa 3 chạm để đến mọi tính năng; chế độ Child dùng icon lớn, màu sắc tươi sáng |
| **NFR-06** | Độ tin cậy | Cảnh báo mềm gửi đúng mốc thời gian (sai số \< 30 giây) ngay cả khi mất kết nối tạm thời |
| **NFR-07** | Tương thích | Android 8.0 (API 26\) trở lên; tối ưu cho cả màn hình điện thoại và máy tính bảng |
| **NFR-08** | Tiêu thụ pin | ForegroundService tiêu thụ \< 5% pin mỗi giờ trong điều kiện sử dụng thông thường |
| **NFR-09** | Bảo trì | Mã Flutter theo lint chuẩn \`flutter\_lints\`; mã backend theo chuẩn ESLint; test coverage \> 85% cho module backend quan trọng |

## **3.2. Sơ đồ trường hợp sử dụng (Use Case Diagram)** {#3.2.-sơ-đồ-trường-hợp-sử-dụng-(use-case-diagram)}

### *3.2.1. Tổng quan Actor* {#3.2.1.-tổng-quan-actor}

Hệ thống KidFun có ba actor chính:

\- Phụ huynh (Parent): Người lớn cài và sử dụng app KidFun ở chế độ Parent trên điện thoại Android của mình.  
\- Trẻ em (Child): Người dùng cài cùng app KidFun ở chế độ Child trên điện thoại Android cá nhân, được liên kết với hồ sơ phụ huynh.

\- Hệ thống (System): Các tác nhân tự động và bộ đếm giờ trong \`KidFunService\` (foreground), AI Worker phân tích YouTube, Geofence Engine kiểm tra ENTER/EXIT, Scheduler tạo báo cáo định kỳ.

\*\[Hình 3.2.1.1: Sơ đồ Use Case tổng quan — sẽ được chèn tại đây\]\*

### *3.2.2. Danh sách Use Case* {#3.2.2.-danh-sách-use-case}

| Mã | Tên Use Case | Actor | Mô tả ngắn |
| :---- | :---- | :---- | :---- |
| **UC-01** | Đăng ký tài khoản | Phụ huynh | Tạo tài khoản mới trên app mobile |
| **UC-02** | Đăng nhập hệ thống | Phụ huynh / Trẻ em | Xác thực và nhận access token |
| **UC-03** | Khôi phục mật khẩu | Phụ huynh | Nhận OTP email đặt lại mật khẩu |
| **UC-04** | Chọn chế độ Parent/Child | Phụ huynh / Trẻ em | Chọn vai trò sau khi đăng nhập |
| **UC-05** | Quản lý hồ sơ con | Phụ huynh | CRUD hồ sơ con trên app mobile |
| **UC-06** | Tạo mã QR liên kết | Phụ huynh | Sinh mã QR hiển thị trên điện thoại |
| **UC-07** | Quét QR liên kết thiết bị | Trẻ em | Quét QR bằng camera điện thoại của mình |
| **UC-08** | Cài đặt giới hạn thời gian | Phụ huynh | Đặt số phút tối đa mỗi ngày trong tuần |
| **UC-09** | Chặn ứng dụng | Phụ huynh | Chọn app từ danh sách thiết bị con để chặn |
| **UC-10** | Chặn website | Phụ huynh | Chặn domain/danh mục web |
| **UC-11** | Cấu hình chế độ học | Phụ huynh | Đặt lịch \+ whitelist app |
| **UC-12** | Xử lý yêu cầu thêm giờ | Phụ huynh | Duyệt/từ chối real-time |
| **UC-13** | Xem lịch sử \+ báo cáo | Phụ huynh | Đọc nhật ký, biểu đồ thống kê |
| **UC-14** | Theo dõi vị trí | Phụ huynh | Bản đồ Mapbox real-time |
| **UC-15** | Quản lý geofence | Phụ huynh | Vẽ vùng an toàn trên bản đồ |
| **UC-16** | Nhận cảnh báo SOS | Phụ huynh | Xử lý SOS khẩn cấp |
| **UC-17** | Giám sát YouTube | Phụ huynh | Xem video con xem \+ kết quả AI |
| **UC-18** | Xem cảnh báo AI | Phụ huynh | Đọc cảnh báo nội dung nguy hiểm |
| **UC-19** | Xem thời gian còn lại | Trẻ em | Đồng hồ đếm ngược |
| **UC-20** | Nhận cảnh báo mềm | Trẻ em | Popup tại mốc 30/15/5 phút |
| **UC-21** | Gửi yêu cầu thêm giờ | Trẻ em | Form lý do \+ gửi qua Socket.IO |
| **UC-22** | Kích hoạt SOS | Trẻ em | Nhấn giữ nút SOS |
| **UC-23** | Gửi cảnh báo mềm | Hệ thống (KidFunService) | KidFunService phát tự động |
| **UC-24** | Khóa thiết bị | Hệ thống (KidFunService) | DevicePolicyManager khóa khi hết giờ |
| **UC-25** | Phân tích AI YouTube | Hệ thống (AI Worker) | AI Worker định kỳ chạy |
| **UC-26** | Kiểm tra geofence | Hệ thống (Geofence Engine) | GeofenceEngine kiểm tra ENTER/EXIT |
| **UC-27** | Gửi push notification | Hệ thống (FCM Admin SDK) | FCM Admin SDK gửi khi có sự kiện |

## **3.3. Use Case chi tiết các chức năng cốt lõi** {#3.3.-use-case-chi-tiết-các-chức-năng-cốt-lõi}

Phần này mô tả chi tiết các Use Case cốt lõi (core) của hệ thống và những tính năng tạo nên giá trị chính của KidFun. Các Use Case còn lại (báo cáo, AI YouTube, geofencing, chế độ học, web filtering) đóng vai trò bổ trợ và không trình bày chi tiết trong báo cáo này.

### *3.3.1. UC-02: Đăng nhập hệ thống* {#3.3.1.-uc-02:-đăng-nhập-hệ-thống}

Mô tả: Người dùng (phụ huynh hoặc trẻ em) đăng nhập vào app KidFun bằng email/mật khẩu hoặc tài khoản Google để nhận JWT token, làm tiền đề cho mọi thao tác sau đó.

Actor chính: Phụ huynh / Trẻ em

Điều kiện tiên quyết: App đã được cài đặt; người dùng có tài khoản đã đăng ký.

Luồng sự kiện chính:  
1\. Người dùng mở app KidFun, màn hình Splash hiển thị trong khi app kiểm tra JWT token trong \`flutter\_secure\_storage\`. Nếu chưa có token, chuyển đến màn hình Login.  
2\. Người dùng nhập email \+ mật khẩu hoặc nhấn "Đăng nhập với Google".  
3\. App (Flutter) gọi \`POST /api/auth/login\` qua Dio (hoặc \`POST /api/auth/google\` với idToken nếu chọn Google).  
4\. Backend \`authController.login()\` truy vấn User theo email; nếu tìm thấy, dùng \`bcryptjs.compare()\` xác thực mật khẩu (hoặc xác thực idToken với Google API).  
5\. Backend ký JWT (payload: \`{userId, email}\`, hết hạn 24h) bằng \`jsonwebtoken.sign()\` và trả về \`{token, user}\`.  
6\. App lưu token vào \`flutter\_secure\_storage\` (Android Keystore), Dio interceptor sẽ tự đính kèm vào header \`Authorization: Bearer\` cho mọi request sau.  
7\. App đăng ký FCM token với backend qua \`POST /api/fcm-tokens\`.  
8\. App điều hướng: nếu lần đầu → "Chọn vai trò"; nếu đã chọn rồi → vào Dashboard tương ứng (Parent hoặc Child).

Luồng ngoại lệ:  
\- 4a. Email không tồn tại hoặc mật khẩu sai → backend trả \`401 Unauthorized\`; app hiển thị "Email hoặc mật khẩu không đúng".  
\- 4b. Quá 5 lần đăng nhập sai trong 1 phút → rate limit trả \`429 Too Many Requests\`.  
\- 5a. Mất kết nối mạng → app hiển thị SnackBar "Không có kết nối, vui lòng thử lại".

\*\[Hình 3.3.1.1: Use Case chi tiết UC-02 (Đăng nhập) — sẽ được chèn tại đây\]\*

### *3.3.2. UC-06 \+ UC-07: Liên kết thiết bị qua QR Code* {#3.3.2.-uc-06-+-uc-07:-liên-kết-thiết-bị-qua-qr-code}

Mô tả: Đây là tính năng cốt lõi để hệ thống bắt đầu giám sát. Phụ huynh tạo mã QR trên app của mình; trẻ em dùng camera điện thoại quét mã đó để liên kết thiết bị với hồ sơ.

Actor chính: Phụ huynh \+ Trẻ em

Điều kiện tiên quyết: Phụ huynh đã đăng nhập và tạo ít nhất một hồ sơ con; cả hai thiết bị có Internet.

Luồng sự kiện chính:  
1\. (Parent) Phụ huynh vào hồ sơ con → "Thêm thiết bị" → app gửi \`POST /api/devices/pairing/generate\` với \`profileId\`.  
2\. (Backend) Tạo \`pairingCode\` ngẫu nhiên 8 ký tự, lưu vào \`Device.pairingCode\` với \`pairingCodeExpiry \= now \+ 10 phút\`; trả về \`{pairingCode, qrPayload}\`.  
3\. (Parent) App hiển thị mã QR fullscreen (sinh bằng \`qr\_flutter\` từ \`qrPayload\`) kèm số đếm ngược 10 phút.  
4\. (Child) Trẻ mở KidFun, chọn "Tôi là Trẻ em" → "Quét mã QR" → app yêu cầu quyền \`CAMERA\` (lần đầu) → mở camera bằng \`mobile\_scanner\`.  
5\. (Child) Trẻ hướng camera vào màn hình điện thoại phụ huynh; \`mobile\_scanner\` decode QR → app parse \`{pairingCode, profileId, serverUrl}\`.  
6\. (Child) App lấy \`deviceName\` từ \`device\_info\_plus\`, \`osVersion\` từ \`Platform.operatingSystemVersion\`, gửi \`POST /api/devices/pairing/complete\` với \`{pairingCode, deviceName, osVersion}\`.  
7\. (Backend) Xác thực \`pairingCode\` còn hạn → tạo \`Device\` mới (gán \`profileId\`, \`userId\`), trả về \`{deviceCode, deviceJwt}\` riêng cho thiết bị Child.  
8\. (Child) App lưu \`deviceJwt\`, đăng ký FCM token, khởi động \`KidFunService\` (Kotlin ForegroundService) qua MethodChannel, chuyển vào Child Dashboard.  
9\. (Parent) Backend phát event Socket.IO \`deviceLinked\` → app Parent đóng dialog QR và hiển thị thiết bị mới với trạng thái Online trong danh sách.

Luồng ngoại lệ:  
\- 4a. Trẻ từ chối quyền camera → app hiển thị hướng dẫn vào Settings cấp quyền.  
\- 7a. Mã QR hết hạn (sau 10 phút) → backend trả \`410 Gone\`; app Child hiển thị "Mã đã hết hạn, vui lòng yêu cầu phụ huynh tạo mã mới".  
\- 7b. Mã QR đã sử dụng → trả \`409 Conflict\`; mỗi mã chỉ dùng được một lần.

\*\[Hình 3.3.2.1: Use Case chi tiết UC-06+UC-07 (Liên kết QR) — sẽ được chèn tại đây\]\*

### *3.3.3. UC-08: Cài đặt giới hạn thời gian* {#3.3.3.-uc-08:-cài-đặt-giới-hạn-thời-gian}

Mô tả: Phụ huynh cấu hình số phút sử dụng tối đa cho mỗi ngày trong tuần. Đây là dữ liệu nền tảng để hệ thống Soft Warning và Lock Screen vận hành.

Actor chính: Phụ huynh

Điều kiện tiên quyết: Phụ huynh đã đăng nhập; có ít nhất một hồ sơ con đã liên kết thiết bị.

Luồng sự kiện chính:  
1\. Phụ huynh chọn hồ sơ → "Giới hạn thời gian" → app gửi \`GET /api/profiles/:id/time-limits\`.  
2\. App hiển thị 7 hàng (Thứ 2 — Chủ nhật) với Switch bật/tắt \+ Slider số phút (0–1440 phút/ngày).  
3\. Phụ huynh chỉnh các giá trị theo nhu cầu (ví dụ: 90 phút/ngày trong tuần, 180 phút cuối tuần).  
4\. Nhấn nút "Lưu" trên AppBar → app gửi \`PUT /api/profiles/:id/time-limits\` với mảng 7 TimeLimit.  
5\. Backend upsert vào bảng \`TimeLimit\` (unique constraint \`\[profileId, dayOfWeek\]\`), trả về \`200 OK\`.  
6\. Backend phát event Socket.IO \`policyUpdate\` đến room \`family\_{userId}\`.  
7\. Thiết bị Child nhận \`policyUpdate\` → forward qua MethodChannel xuống \`KidFunService\` (Kotlin) → service cập nhật giới hạn mới ngay lập tức cho vòng lặp đếm giờ tiếp theo.  
8\. App Parent hiển thị SnackBar "Đã lưu cài đặt".

Luồng ngoại lệ:  
\- 4a. Mất kết nối mạng → app hiển thị lỗi, không lưu (không cache vì dữ liệu cấu hình cần xác nhận server).  
\- 7a. Thiết bị Child đang offline → policyUpdate được Child fetch lại qua \`GET /api/child/policy\` khi reconnect.

\*\[Hình 3.3.3.1: Use Case chi tiết UC-08 (Cài đặt thời gian) — sẽ được chèn tại đây\]\*

### *3.3.4. UC-09: Chặn ứng dụng* {#3.3.4.-uc-09:-chặn-ứng-dụng}

Mô tả: Phụ huynh chỉ định các ứng dụng (theo package name) bị chặn trên thiết bị của trẻ. Khi trẻ cố mở app bị chặn, hệ thống tự động đưa về màn hình chính.

Actor chính: Phụ huynh \+ Hệ thống (AccessibilityService)

Điều kiện tiên quyết: Thiết bị Child đã liên kết, đã cấp quyền \`Accessibility Service\` cho KidFun.

Luồng sự kiện chính:  
1\. Phụ huynh chọn hồ sơ → "Chặn ứng dụng" → app gửi \`GET /api/profiles/:id/blocked-apps\`.  
2\. App hiển thị danh sách app đã sync từ thiết bị Child (sort theo thời gian dùng nhiều nhất), mỗi item có Switch.  
3\. Phụ huynh gạt Switch để bật/tắt chặn theo \`packageName\` → app gửi \`POST /api/blocked-apps\` hoặc \`DELETE /api/blocked-apps/:id\`.  
4\. Backend lưu vào bảng \`BlockedApp\`, phát event Socket.IO \`blockedAppsUpdated\`.  
5\. Thiết bị Child nhận event → Flutter forward danh sách package mới qua MethodChannel \`com.kidfun.mobile/app\_blocker\` xuống \`AppBlockerService.kt\` (Kotlin).  
6\. \`AppBlockerService\` lưu danh sách vào SharedPreferences.  
7\. Khi trẻ mở một app, AccessibilityService nhận \`TYPE\_WINDOW\_STATE\_CHANGED\` → đối chiếu \`event.packageName\` với danh sách blocked.  
8\. Nếu match: \`BlockNotificationHelper\` hiển thị Toast "Ứng dụng này đã bị phụ huynh chặn" → service gọi \`performGlobalAction(GLOBAL\_ACTION\_HOME)\` đưa trẻ về Home Screen trong \< 500ms.

Luồng ngoại lệ:  
\- 5a. Thiết bị Child offline → khi Child mở app sau khi có mạng, gọi \`GET /api/child/policy\` để fetch danh sách blocked mới.  
\- 8a. Trẻ chưa cấp quyền Accessibility → app Child hiển thị warning thường trú và hướng dẫn vào Settings.

\*\[Hình 3.3.4.1: Use Case chi tiết UC-09 (Chặn ứng dụng) — sẽ được chèn tại đây\]\*

### *3.3.5. UC-20 \+ UC-24: Cảnh báo mềm và Khóa thiết bị (USP)* {#3.3.5.-uc-20-+-uc-24:-cảnh-báo-mềm-và-khóa-thiết-bị-(usp)}

Mô tả: Đây là tính năng đặc trưng nhất của KidFun (Soft Warning Technology). Khi thời gian sử dụng còn lại đạt các mốc 30 / 15 / 5 phút, thiết bị Child phát cảnh báo mềm để trẻ chuẩn bị tinh thần. Khi hết giờ hoàn toàn, hệ thống khóa thiết bị bằng Lock Screen Kiosk Mode.

Actor chính: Hệ thống (KidFunService) \+ Trẻ em

Điều kiện tiên quyết: Thiết bị đã liên kết, đã cấu hình \`TimeLimit\`, đã cấp đầy đủ quyền (UsageStats, Device Admin, Display over other apps).

Luồng sự kiện chính:  
1\. \`KidFunService\` (Kotlin ForegroundService) chạy nền 24/7, vòng lặp 30 giây/lần:  
   \- Đọc \`UsageStatsManager.queryUsageStats()\` để lấy \`usedMinutesToday\`.  
   \- Tính \`remainingMinutes \= TimeLimit.dailyLimitMinutes \- usedMinutesToday\`.  
   \- Emit \`remainingMinutes\` qua EventChannel \`com.kidfun.mobile/usage\_stats\` → Flutter cập nhật đồng hồ đếm ngược.  
2\. Cảnh báo mềm tại mốc 30 phút:  
   \- Service phát hiện \`remainingMinutes\` chuyển từ \> 30 sang ≤ 30\.  
   \- Hiển thị Notification \+ rung thiết bị \+ phát chuông qua \`RingtoneManager\`.  
   \- Flutter hiện AlertDialog "Còn 30 phút sử dụng, hãy chuẩn bị tắt máy nhé\!".  
   \- Lưu bản ghi \`Warning\` (loại \`SOFT\_30\`) vào database qua API.  
3\. Cảnh báo mềm tại mốc 15 phút: Tương tự, mức độ khẩn hơn (rung 2 lần, chuông to hơn).  
4\. Cảnh báo mềm tại mốc 5 phút: Mức cao nhất (rung dài, popup không thể tắt bằng nút Back).  
5\. Khóa thiết bị khi \`remainingMinutes ≤ 0\`:  
   \- \`KidFunService\` gọi \`DevicePolicyManager.lockNow()\` để khóa màn hình hệ thống ngay lập tức.  
   \- Đánh dấu \`isLocked \= true\` trong SharedPreferences.  
   \- Khi trẻ mở khóa lại bằng PIN/vân tay, \`MainActivity\` được khởi động ở foreground với fullscreen mode (immersive sticky) hiển thị Lock Screen UI Flutter.  
   \- \`AppBlockerService\` chặn tất cả app khác ngoài KidFun trong trạng thái khóa.  
   \- Lock Screen chỉ có duy nhất một nút "Xin thêm giờ" để giao tiếp với phụ huynh.  
6\. Reset hằng ngày: Lúc 00:00, \`AppLimitChecker\` reset counter \`usedMinutesToday\` và bỏ trạng thái khóa.

Luồng ngoại lệ:  
\- 1a. UsageStatsManager bị thu hồi quyền → service hiển thị notification thường trú yêu cầu cấp quyền lại, không đếm được giờ.  
\- 5a. Thiết bị bị tắt nguồn khi đang khóa → \`BootReceiver\` khôi phục trạng thái khóa sau khi boot lại.

\*\[Hình 3.3.5.1: Use Case chi tiết UC-20+UC-24 (Soft Warning \+ Lock Screen) — sẽ được chèn tại đây\]\*

### *3.3.6. UC-21 \+ UC-12: Yêu cầu thêm giờ real-time (USP)* {#3.3.6.-uc-21-+-uc-12:-yêu-cầu-thêm-giờ-real-time-(usp)}

Mô tả: Tính năng cốt lõi cho phép trẻ thương lượng với phụ huynh thông qua Socket.IO và FCM. Đây là USP quan trọng nhất giúp KidFun khác biệt so với các sản phẩm parental control thông thường.

Actor chính: Trẻ em \+ Phụ huynh

Điều kiện tiên quyết: Cả hai thiết bị có Internet; thiết bị Child đang ở Lockscreen hoặc còn cảnh báo mềm.

Luồng sự kiện chính:  
1\. (Child) Trẻ nhấn nút "Xin thêm giờ" → màn hình form nhập lý do với \`TextField\` (validation: tối thiểu 10 ký tự, tối đa 200 ký tự) và \`Slider\` chọn số phút xin (5 / 15 / 30 / 60 phút).  
2\. (Child) Nhấn "Gửi yêu cầu" → app gửi đồng thời:  
   \- HTTP: \`POST /api/extension-requests\` với \`{profileId, deviceId, requestMinutes, reason}\`.  
   \- Socket.IO: \`emit('requestTimeExtension', {...})\`.  
3\. (Backend) Lưu \`TimeExtensionRequest\` với \`status \= PENDING\` → kiểm tra trạng thái Parent socket trong room \`family\_{userId}\`:  
   \- Nếu Parent online: \`emit('timeExtensionRequest', {...})\` đến socket Parent → app hiển thị popup ngay.  
   \- Nếu Parent offline: Truy vấn \`FCMToken\` của Parent → gửi push notification ưu tiên cao qua Firebase Admin SDK với 2 action button "Đồng ý" / "Từ chối" trực tiếp trong khay thông báo.  
4\. (Parent) Phụ huynh xem yêu cầu (tên con, lý do, số phút trẻ xin, số phút còn lại trong ngày).  
5\. (Parent) Quyết định:  
   \- Từ chối: Nhấn "Từ chối" → app gửi \`PUT /api/extension-requests/:id/respond\` với \`{action: 'REJECT'}\`.  
   \- Đồng ý: Điều chỉnh số phút duyệt qua Slider (có thể khác số trẻ xin) → nhấn "Đồng ý" → app gửi \`{action: 'APPROVE', responseMinutes: 20}\`.  
6\. (Backend) Cập nhật \`status\`, \`responseMinutes\`, \`respondedAt\` → phát event Socket.IO \`timeExtensionResponse\` về thiết bị Child.  
7\. (Child) App nhận event:  
   \- REJECTED: Hiển thị Dialog "Phụ huynh đã từ chối yêu cầu của bạn".  
   \- APPROVED: Forward qua MethodChannel → \`KidFunService\` cộng \`responseMinutes\` vào \`bonusMinutes\`. Nếu đang ở Lock Screen, gọi \`AppLimitChecker.unlock()\` để mở khóa. Hiển thị thông báo "Phụ huynh cho thêm 20 phút, hãy sử dụng hợp lý nhé\!".

Luồng ngoại lệ:  
\- 3a. Parent app đóng \+ không có mạng → FCM giữ lại, gửi khi mạng có lại.  
\- 5a. Phụ huynh không phản hồi trong 30 phút → backend tự động đánh dấu \`EXPIRED\`, Child nhận thông báo "Phụ huynh chưa phản hồi, hãy thử lại sau".  
\- 6a. Trẻ tiếp tục dùng quá \`bonusMinutes\` → quay lại vòng lặp cảnh báo \+ khóa.

\*\[Hình 3.3.6.1: Use Case chi tiết UC-21+UC-12 (Xin thêm giờ) — sẽ được chèn tại đây\]\*

### *3.3.7. UC-22: Kích hoạt SOS* {#3.3.7.-uc-22:-kích-hoạt-sos}

Mô tả: Chức năng an toàn cho phép trẻ phát tín hiệu khẩn cấp tới phụ huynh kèm vị trí GPS và đoạn ghi âm hiện trường.

Actor chính: Trẻ em \+ Phụ huynh

Điều kiện tiên quyết: Thiết bị Child có GPS đã bật và cấp quyền \`ACCESS\_FINE\_LOCATION\`, \`RECORD\_AUDIO\`.

Luồng sự kiện chính:  
1\. (Child) Trẻ nhấn giữ nút SOS ở góc trên phải Child Dashboard trong 2 giây liên tục (tránh chạm nhầm). Vòng tiến trình tròn (CircularProgressIndicator) hiển thị thời gian giữ.  
2\. (Child) Sau 2 giây, app hiển thị màn hình "Đang gửi cảnh báo..." → thực hiện song song:  
   \- Gọi \`Geolocator.getCurrentPosition(LocationAccuracy.high)\` lấy \`{latitude, longitude}\`.  
   \- Bắt đầu ghi âm 5 giây bằng \`record\` package, lưu thành file \`.m4a\` trong \`getTemporaryDirectory()\`.  
3\. (Child) Khi cả hai hoàn tất, app gửi \`POST /api/sos\` với \`multipart/form-data\`: \`{profileId, deviceId, latitude, longitude, audio: file}\` và đồng thời \`emit('sosAlert', {...})\` qua Socket.IO.  
4\. (Backend) Lưu file audio vào storage (đường dẫn \`/uploads/sos-audio/{uuid}.m4a\`), tạo \`SOSAlert\` với \`status \= ACTIVE\` → reverse geocode tọa độ thành địa chỉ (tùy chọn).  
5\. (Backend) Gửi FCM push notification ưu tiên CAO NHẤT (\`priority: high\`, \`channelImportance: IMPORTANCE\_MAX\`) đến tất cả \`FCMToken\` của user → kèm \`sound: 'sos\_alarm'\` (chuông kéo dài 30s) → hiển thị trên màn hình khóa Parent.  
6\. \*\*(Backend)\*\* Phát Socket.IO \`sosAlert\` đến room \`family\_{userId}\` để app Parent đang mở nhận ngay.  
7\. (Parent) App hiện popup full-screen "CẢNH BÁO SOS từ \[tên con\]" với:  
   \- Địa chỉ \+ tọa độ GPS.  
   \- Nút "Mở bản đồ" → mở Mapbox với marker tại vị trí.  
   \- Nút "Nghe ghi âm" → phát file audio qua \`audioplayers\`.  
   \- Nút "Đã xem" → gửi \`PUT /api/sos/:id/acknowledge\` cập nhật \`status \= ACKNOWLEDGED\`.

Luồng ngoại lệ:  
\- 2a. GPS không lấy được (trẻ trong nhà, không có sóng) → vẫn gửi SOS với vị trí gần nhất từ \`LocationLog\`.  
\- 2b. Microphone không khả dụng → bỏ qua ghi âm, vẫn gửi vị trí GPS.  
\- 3a. Mất kết nối Internet → giữ payload trong queue, retry mỗi 10 giây cho đến khi gửi thành công.

\*\[Hình 3.3.7.1: Use Case chi tiết UC-22 (SOS) — sẽ được chèn tại đây\]\*

## **3.4. Sơ đồ tuần tự (Sequence Diagram) cho các luồng cốt lõi** {#3.4.-sơ-đồ-tuần-tự-(sequence-diagram)-cho-các-luồng-cốt-lõi}

Phần này trình bày Sequence Diagram cho các luồng nghiệp vụ cốt lõi (core) của KidFun. Mỗi luồng có sự tham gia của nhiều thành phần: Flutter UI, Kotlin Native (qua MethodChannel/EventChannel), Backend REST API và Socket.IO Server.

### *3.4.1. Luồng 1: Đăng nhập và khởi tạo phiên làm việc* {#3.4.1.-luồng-1:-đăng-nhập-và-khởi-tạo-phiên-làm-việc}

Các thành phần tham gia: User → Flutter UI → Dio HTTP Client → Backend (authController) → PostgreSQL → flutter\_secure\_storage → Socket.IO Server.

Diễn giải:  
1\. User nhập email \+ password trên Login Screen (Flutter).  
2\. Flutter Login Provider (Riverpod) gọi \`Dio.post('/api/auth/login', {email, password})\`.  
3\. Backend \`authController.login\` thực thi: \`prisma.user.findUnique({email})\` → nếu null trả \`401\`; nếu có → \`bcrypt.compare(password, user.passwordHash)\`.  
4\. Mật khẩu đúng → \`jsonwebtoken.sign({userId, email}, JWT\_SECRET, {expiresIn: '24h'})\`.  
5\. Backend trả \`200 OK\` với \`{token, user}\`.  
6\. Flutter lưu token vào \`flutter\_secure\_storage\` (Android Keystore).  
7\. Flutter khởi tạo Socket.IO Client với \`auth: {token}\` → kết nối tới server.  
8\. Backend Socket.IO middleware xác thực JWT → cho phép connect → tự \`socket.join('family\_${userId}')\`.  
9\. Flutter đăng ký FCM token qua \`POST /api/fcm-tokens\` để nhận push notification.  
10\. Flutter điều hướng vào Parent Dashboard hoặc Child Dashboard tùy chế độ đã chọn.

\*\[Hình 3.4.1.1: Sequence Diagram — Luồng đăng nhập \+ khởi tạo phiên — sẽ được chèn tại đây\]\*

### *3.4.2. Luồng 2: Liên kết thiết bị qua QR Code* {#3.4.2.-luồng-2:-liên-kết-thiết-bị-qua-qr-code}

Các thành phần tham gia: Parent UI → Backend → Child UI → Camera (mobile\_scanner) → Child Backend → Socket.IO.

Diễn giải:  
1\. Parent: Nhấn "Thêm thiết bị" → Flutter gọi \`POST /api/devices/pairing/generate\`.  
2\. Backend: Tạo \`pairingCode\` 8 ký tự (hết hạn sau 10 phút), lưu \`Device.pairingCode\` → trả \`qrPayload\` (JSON serialize).  
3\. Parent: \`qr\_flutter\` render mã QR fullscreen từ \`qrPayload\`.  
4\. Child: Trẻ mở app, chọn "Quét QR" → \`mobile\_scanner\` mở camera.  
5\. Child: Decode QR → parse \`{pairingCode, profileId, serverUrl}\`.  
6\. Child: Lấy \`deviceName\` (device\_info\_plus), gọi \`POST /api/devices/pairing/complete\` với \`{pairingCode, deviceName, osVersion}\`.  
7\. Backend: Xác minh pairingCode còn hạn → \`prisma.device.create({profileId, userId, deviceCode, pairingCode: null})\` → ký \`deviceJwt\` riêng cho Device → trả về.  
8\. Child: Lưu \`deviceJwt\`, gọi MethodChannel \`com.kidfun.mobile/service\_control\` → Kotlin khởi động \`KidFunService\` (Foreground Service).  
9\. Backend: Phát Socket.IO event \`deviceLinked\` đến room \`family\_{userId}\`.  
10\. Parent: App nhận event → đóng dialog QR → thiết bị mới xuất hiện trong danh sách với badge "Online".

\*\[Hình 3.4.2.1: Sequence Diagram — Liên kết thiết bị qua QR — sẽ được chèn tại đây\]\*

### *3.4.3. Luồng 3: Cảnh báo mềm và Khóa thiết bị (USP)* {#3.4.3.-luồng-3:-cảnh-báo-mềm-và-khóa-thiết-bị-(usp)}

Các thành phần tham gia: KidFunService (Kotlin) → UsageStatsManager → MethodChannel → Flutter UI → DevicePolicyManager → AppBlockerService.

Diễn giải (vòng lặp 30 giây/lần):  
1\. \`KidFunService.handler.postDelayed(runnable, 30000)\` chạy \`AppLimitChecker.tick()\`.  
2\. \`AppLimitChecker\` đọc \`UsageStatsManager.queryUsageStats(INTERVAL\_DAILY, midnight, now)\` → tính tổng \`usedMinutes\`.  
3\. Đọc \`TimeLimit.dailyLimitMinutes\` cho \`today.dayOfWeek\` từ SharedPreferences cache → tính \`remainingMinutes \= limit \- used \+ bonusMinutes\`.  
4\. Emit qua EventChannel \`usage\_stats\` → Flutter cập nhật đồng hồ đếm ngược trong UI.  
5\. Nhánh cảnh báo mềm:  
   \- Nếu \`remainingMinutes\` vừa chạm 30: \`BlockNotificationHelper.showSoftWarning(30)\` → Notification \+ Vibrator.vibrate \+ Ringtone.play → MethodChannel emit về Flutter → AlertDialog "Còn 30 phút\!".  
   \- Tương tự cho mốc 15 và 5 (mức độ tăng dần).  
6\. Nhánh khóa thiết bị:  
   \- Khi \`remainingMinutes ≤ 0\`: \`DevicePolicyManager.lockNow()\` khóa màn hình hệ thống.  
   \- Set \`SharedPreferences.isLocked \= true\`.  
   \- Khi user mở khóa lại bằng PIN/biometric, \`AppBlockerService\` phát hiện foreground app khác KidFun → ngay lập tức \`performGlobalAction(GLOBAL\_ACTION\_HOME)\` → mở \`MainActivity\` với cờ FLAG\_ACTIVITY\_NEW\_TASK.  
   \- Flutter route đến Lock Screen UI (immersive sticky fullscreen).  
7\. Mỗi mốc cảnh báo \+ khóa: gọi \`POST /api/warnings\` để lưu vào bảng \`Warning\` cho mục đích báo cáo.

\*\[Hình 3.4.3.1: Sequence Diagram — Soft Warning \+ Lock Screen (USP) — sẽ được chèn tại đây\]\*

### *3.4.4. Luồng 4: Yêu cầu thêm giờ real-time (USP)* {#3.4.4.-luồng-4:-yêu-cầu-thêm-giờ-real-time-(usp)}

Các thành phần tham gia:\*\* Child UI → Socket.IO Client → Backend → FCM Admin → Parent UI / Parent Notification → Backend → Child UI → Kotlin.

Diễn giải:  
1\. (Child) Trẻ nhập lý do \+ chọn số phút trên Form → nhấn "Gửi".  
2\. (Child) Flutter gọi đồng thời:  
   \- \`Dio.post('/api/extension-requests', {requestMinutes, reason})\` → trả \`requestId\`.  
   \- \`socket.emit('requestTimeExtension', {requestId, profileId, requestMinutes, reason})\`.  
3\. (Backend) \`extensionController.create\` lưu \`TimeExtensionRequest\` với \`status \= PENDING\`.  
4\. (Backend Socket Service) Kiểm tra room \`family\_{userId}\` có Parent socket online không:  
   \- Online: \`io.to(parentSocketId).emit('timeExtensionRequest', payload)\`.  
   \- Offline: \`fcmService.sendNotification(parentFcmTokens, {title: 'Con xin thêm giờ', actions: \['APPROVE', 'REJECT'\]})\`.  
5\. (Parent) App đang mở → Riverpod state thay đổi → hiện popup Dialog với tên con \+ lý do \+ số phút.  
6\. (Parent) Phụ huynh điều chỉnh \`responseMinutes\` qua Slider → nhấn "Đồng ý" hoặc "Từ chối".  
7\. (Parent) Flutter gọi \`PUT /api/extension-requests/:id/respond\` với \`{action, responseMinutes}\` \+ \`socket.emit('respondTimeExtension', payload)\`.  
8\. (Backend) Cập nhật \`TimeExtensionRequest.status \= APPROVED/REJECTED, responseMinutes, respondedAt\`.  
9\. (Backend) \`io.to('family\_${userId}').emit('timeExtensionResponse', payload)\`.  
10\. (Child) Flutter nhận event → forward qua MethodChannel \`app\_limit\` xuống Kotlin.  
11\. (Child Kotlin) \`AppLimitChecker.addBonus(responseMinutes)\` cập nhật \`bonusMinutes\`.  
12\. (Child Kotlin) Nếu đang trong trạng thái Lock Screen: \`unlock()\` → set \`isLocked \= false\`, AppBlockerService dừng chặn.  
13\. (Child UI) Hiển thị Toast "Phụ huynh cho thêm X phút".

\*\[Hình 3.4.4.1: Sequence Diagram — Xin thêm giờ end-to-end (★ USP) — sẽ được chèn tại đây\]\*

### *3.4.5. Luồng 5: Phát hiện và chặn ứng dụng (Android Native)* {#3.4.5.-luồng-5:-phát-hiện-và-chặn-ứng-dụng-(android-native)}

Các thành phần tham gia: Parent UI → Backend → Socket.IO → Child Flutter → MethodChannel → AppBlockerService → AccessibilityService Event.

Diễn giải:  
1\. (Parent) Phụ huynh bật Switch chặn TikTok → Flutter gọi \`POST /api/blocked-apps\` với \`{profileId, packageName: 'com.zhiliaoapp.musically'}\`.  
2\. (Backend) \`blockedAppController.create\` insert vào \`BlockedApp\` → phát Socket.IO \`blockedAppsUpdated\`.  
3\. (Child) Flutter Socket listener nhận event → MethodChannel \`com.kidfun.mobile/app\_blocker\` invoke \`updateBlockedList(newList)\`.  
4\. (Child Kotlin) \`AppBlockerService.updateBlockedList\` ghi danh sách vào SharedPreferences.  
5\. (Child Android System) Khi trẻ chạm icon TikTok trên Home Screen → Android phát \`AccessibilityEvent.TYPE\_WINDOW\_STATE\_CHANGED\` với \`event.packageName \= 'com.zhiliaoapp.musically'\`.  
6\. (Child Kotlin) \`AppBlockerService.onAccessibilityEvent(event)\`:  
   \- Check nếu \`packageName ∈ blockedSet\` → trả \`true\`.  
   \- Gọi \`BlockNotificationHelper.showBlockedToast(appName)\` hiển thị Toast.  
   \- Gọi \`performGlobalAction(AccessibilityService.GLOBAL\_ACTION\_HOME)\` đưa trẻ về Home Screen.  
   \- Toàn bộ quá trình từ khi mở app đến khi bị chặn về Home: \< 500ms.

\*\[Hình 3.4.5.1: Sequence Diagram — Chặn ứng dụng qua AccessibilityService — sẽ được chèn tại đây\]\*

### *3.4.6. Luồng 6: Cảnh báo SOS khẩn cấp* {#3.4.6.-luồng-6:-cảnh-báo-sos-khẩn-cấp}

Các thành phần tham gia: Child UI → Geolocator → Record → Dio Multipart → Backend → Storage → FCM Admin → Parent Notification.

Diễn giải:  
1\. (Child UI) Trẻ nhấn giữ nút SOS 2 giây → CircularProgressIndicator hoàn thành 360°.  
2\. (Child Flutter) Hiển thị Loading "Đang gửi cảnh báo..." → kích hoạt song song:  
   \- \`Geolocator.getCurrentPosition(LocationAccuracy.high)\` → trả \`{lat, lng}\`.  
   \- \`record.start(path: temp.m4a)\` → đợi 5 giây → \`record.stop()\`.  
3\. (Child Flutter) Sau khi cả hai task xong, gọi:  
   \- HTTP: \`Dio.post('/api/sos', FormData.fromMap({latitude, longitude, audio: MultipartFile}))\`.  
   \- Socket: \`socket.emit('sosAlert', {profileId, latitude, longitude})\`.  
4\. (Backend) \`sosController.create\`:  
   \- Lưu file audio vào \`/uploads/sos-audio/{uuid}.m4a\`.  
   \- Insert \`SOSAlert\` với \`status \= ACTIVE\`.  
   \- (Optional) Reverse geocode tọa độ → địa chỉ tiếng Việt.  
5\. (Backend) Lấy tất cả \`FCMToken\` của \`user\` → \`fcmService.sendCritical(tokens, {title: 'SOS từ Bé An', body: address, priority: 'high', channel: 'sos\_channel'})\`.  
6\. (Backend) Socket emit \`sosAlert\` đến room \`family\_{userId}\`.  
7\. (Parent) Thiết bị Parent:  
   \- Đang đóng: FCM hiển thị notification ưu tiên cao trên màn hình khóa \+ chuông kéo dài.  
   \- Đang mở: Riverpod state → Dialog full-screen với:  
     \- Marker Mapbox tại vị trí.  
     \- Nút "Mở Maps" → mở Google Maps app.  
     \- Nút "Nghe ghi âm" → \`audioplayers.play(audioUrl)\`.  
     \- Nút "Đã xem" → \`PUT /api/sos/:id/acknowledge\`.

\*\[Hình 3.4.6.1: Sequence Diagram — SOS khẩn cấp — sẽ được chèn tại đây\]\*

## **3.5. Sơ đồ hoạt động (Activity Diagram) cho các luồng cốt lõi** {#3.5.-sơ-đồ-hoạt-động-(activity-diagram)-cho-các-luồng-cốt-lõi}

Phần này mô tả Activity Diagram cho các luồng nghiệp vụ cốt lõi (core) dưới dạng các bước có quyết định rẽ nhánh.

### *3.5.1. Hoạt động 1: Liên kết thiết bị Child với hồ sơ qua QR* {#3.5.1.-hoạt-động-1:-liên-kết-thiết-bị-child-với-hồ-sơ-qua-qr}

\- Bắt đầu: Phụ huynh chọn hồ sơ con → nhấn "Thêm thiết bị".  
\- Sinh mã QR: Backend tạo \`pairingCode\` 8 ký tự, hết hạn sau 10 phút.  
\- Parent hiển thị QR fullscreen.  
\- Decision (đếm ngược 10 phút):  
  \- Trẻ quét được trong thời hạn → tiếp tục.  
  \- Hết hạn → hiển thị "Mã đã hết hạn" → quay về bước "Sinh mã QR" (làm lại).  
\- Child mở camera (mobile\_scanner):  
  \- Chưa có quyền → yêu cầu quyền CAMERA.  
    \- Từ chối → hiển thị hướng dẫn vào Settings → kết thúc.  
    \- Đồng ý → mở camera.  
\- Quét QR thành công → Child gửi \`POST /api/devices/pairing/complete\`.  
\- Decision (backend xác thực):  
  \- pairingCode hết hạn → trả \`410 Gone\` → Child hiển thị lỗi → kết thúc.  
  \- Hợp lệ → tạo \`Device\`, trả \`deviceJwt\` → Child lưu và khởi động \`KidFunService\`.  
\- Backend phát Socket \`deviceLinked\` → Parent nhận thông báo → đóng QR dialog.  
\- Kết thúc: Thiết bị Online trong danh sách, sẵn sàng giám sát.

\*\[Hình 3.5.1.1: Activity Diagram — Liên kết QR — sẽ được chèn tại đây\]\*

### *3.5.2. Hoạt động 2: Vòng lặp kiểm soát thời gian (KidFunService) – CORE* {#3.5.2.-hoạt-động-2:-vòng-lặp-kiểm-soát-thời-gian-(kidfunservice)-–-core}

\- Bắt đầu: \`KidFunService\` khởi động (sau khi liên kết thiết bị hoặc qua \`BootReceiver\` sau khi reboot).  
\- Kiểm tra cấu hình: Có hồ sơ \+ TimeLimit nào không?  
  \- Không → service ở trạng thái idle, lặp lại sau 60s.  
  \- Có → tiếp tục.  
\- Đọc thời gian hiện tại để xác định \`dayOfWeek\` (0-6) và lấy \`TimeLimit\` cho ngày đó.  
\- Decision: TimeLimit có active không?  
  \- Không active (ngày không giới hạn) → hiển thị "Hôm nay không giới hạn" → ngủ 1 giờ rồi check lại.  
  \- Active → tiếp tục.  
\- Vòng lặp 30 giây/lần:  
  \- Đọc \`UsageStatsManager.queryUsageStats()\` để lấy \`usedMinutes\`.  
  \- Tính \`remainingMinutes \= dailyLimitMinutes \+ bonusMinutes \- usedMinutes\`.  
  \- Emit \`remainingMinutes\` về Flutter UI qua EventChannel.  
\- Decision: remainingMinutes đạt mốc nào?  
  \- \`\> 30 phút\` → tiếp tục đếm.  
  \- \`= 30 phút (lần đầu)\` → phát Soft Warning 30 (Notification \+ Vibrate \+ Ringtone \+ AlertDialog Flutter) → lưu \`Warning(SOFT\_30)\`.  
  \- \`= 15 phút (lần đầu)\` → phát Soft Warning 15 (mức cảnh báo cao hơn) → lưu \`Warning(SOFT\_15)\`.  
  \- \`= 5 phút (lần đầu)\` → phát Soft Warning 5 (mức tối đa, popup không tắt được bằng Back) → lưu \`Warning(SOFT\_5)\`.  
  \- \`≤ 0 phút\` → \*\*kích hoạt Lock Screen:  
    \- Gọi \`DevicePolicyManager.lockNow()\`.  
    \- Set \`SharedPreferences.isLocked \= true\`.  
    \- Khi user mở khóa, \`AppBlockerService\` chặn mọi app khác KidFun.  
    \- Flutter hiển thị Lock Screen UI (immersive sticky).  
\- Sau Lock Screen: Trẻ có thể nhấn "Xin thêm giờ" → trigger luồng 3.5.3.  
\- Reset hằng ngày: Vào 00:00, \`AppLimitChecker.reset()\` đặt \`usedMinutes \= 0\`, \`bonusMinutes \= 0\`, \`isLocked \= false\`.  
\- Vòng lặp tiếp tục mãi mãi cho đến khi service bị stop.

\*\[Hình 3.5.2.1: Activity Diagram — Vòng lặp kiểm soát thời gian (★ CORE) — sẽ được chèn tại đây\]\*

### *3.5.3. Hoạt động 3: Xử lý yêu cầu thêm giờ end-to-end (USP)* {#3.5.3.-hoạt-động-3:-xử-lý-yêu-cầu-thêm-giờ-end-to-end-(usp)}

\- Bắt đầu (Child): Trẻ ở màn hình cảnh báo hoặc Lock Screen → nhấn "Xin thêm giờ".  
\- Hiển thị Form: TextField lý do \+ Slider số phút (5/15/30/60).  
\- Validation:  
  \- Lý do \< 10 ký tự → hiển thị lỗi inline, không gửi.  
  \- Hợp lệ → tiếp tục.  
\- Gửi yêu cầu: Child gọi HTTP \+ emit Socket đồng thời.  
\- Backend lưu \`TimeExtensionRequest\` (PENDING).  
\- Decision (Backend): Parent có Socket online không?  
  \- Online → emit \`timeExtensionRequest\` đến Parent socket.  
  \- Offline → gửi FCM push notification với 2 action button.  
\- Parent nhận thông báo:  
  \- Qua popup trong app, HOẶC  
  \- Qua FCM notification trên thanh thông báo.  
\- Decision (Parent): Phản hồi trong vòng 30 phút?  
  \- Không phản hồi → backend tự động set \`status \= EXPIRED\` → emit response về Child "Phụ huynh chưa phản hồi" → kết thúc.  
  \- Có phản hồi → tiếp tục.  
\- Decision (Parent): Đồng ý hay Từ chối?  
  \- Từ chối: Cập nhật \`status \= REJECTED\` → emit \`timeExtensionResponse(REJECTED)\` về Child → Child hiển thị Dialog "Phụ huynh đã từ chối" → kết thúc.  
  \- Đồng ý: Parent chỉnh số phút duyệt → cập nhật \`status \= APPROVED, responseMinutes\` → emit \`timeExtensionResponse(APPROVED, responseMinutes)\`.  
\- Child nhận response APPROVED:  
  \- MethodChannel forward về Kotlin → \`AppLimitChecker.addBonus(responseMinutes)\`.  
  \- Decision: Đang ở Lock Screen không?  
    \- Có → \`unlock()\`: set \`isLocked \= false\`, dừng AppBlockerService chặn → Flutter route khỏi Lock Screen UI về Child Dashboard.  
    \- Không → chỉ cập nhật counter, không cần mở khóa.  
  \- Hiển thị Toast "Phụ huynh cho thêm X phút".  
\- Kết thúc: Quay lại vòng lặp kiểm soát thời gian (luồng 3.5.2) với \`bonusMinutes\` mới.

\*\[Hình 3.5.3.1: Activity Diagram — Xin thêm giờ end-to-end (USP) — sẽ được chèn tại đây\]\*

### *3.5.4. Hoạt động 4: Phát hiện và chặn ứng dụng (App Blocking)* {#3.5.4.-hoạt-động-4:-phát-hiện-và-chặn-ứng-dụng-(app-blocking)}

\- Bắt đầu: \`AppBlockerService\` (AccessibilityService) đã được trẻ cấp quyền và đang chạy.  
\- Lắng nghe sự kiện: Đăng ký nhận \`AccessibilityEvent.TYPE\_WINDOW\_STATE\_CHANGED\`.  
\- Khi có sự kiện:  
  \- Lấy \`event.packageName\` (gói app trẻ vừa mở).  
  \- Lấy \`blockedSet\` từ SharedPreferences (cache danh sách \`BlockedApp\`).  
\- Decision: packageName có trong blockedSet không?  
  \- Không → cho phép app chạy → tiếp tục lắng nghe sự kiện kế tiếp.  
  \- Có → tiến hành chặn:  
    \- \`BlockNotificationHelper.showBlockedToast(appName)\` → hiển thị Toast 2 giây.  
    \- \`performGlobalAction(GLOBAL\_ACTION\_HOME)\` → đưa trẻ về Home Screen.  
    \- Log sự kiện vào server qua \`POST /api/blocked-attempts\` để Parent xem trong báo cáo.  
\- Quay lại lắng nghe sự kiện tiếp theo.  
\- Cập nhật danh sách blocked: Khi backend phát Socket \`blockedAppsUpdated\`, Flutter forward qua MethodChannel → \`AppBlockerService.updateBlockedSet(newList)\` → ghi đè SharedPreferences. Áp dụng ngay cho lần kiểm tra kế tiếp.

\*\[Hình 3.5.4.1: Activity Diagram — Chặn ứng dụng — sẽ được chèn tại đây\]\*

### *3.5.5. Hoạt động 5: Kích hoạt SOS* {#3.5.5.-hoạt-động-5:-kích-hoạt-sos}

\- Bắt đầu: Trẻ nhấn giữ nút SOS trên Child Dashboard.  
\- Đếm 2 giây: Hiển thị CircularProgressIndicator quay 360°.  
  \- Trẻ buông tay trước 2 giây → cancel, không gửi SOS.  
  \- Đạt 2 giây → kích hoạt.  
\- Decision: Quyền GPS \+ Microphone đã cấp chưa?  
  \- Chưa → yêu cầu quyền runtime.  
    \- Từ chối GPS → vẫn cho phép gửi SOS với vị trí gần nhất từ \`LocationLog\` cache.  
    \- Từ chối Microphone → bỏ qua ghi âm, chỉ gửi GPS.  
  \- Đã cấp → tiếp tục.  
\- Song song hai task:  
  \- Task 1: \`Geolocator.getCurrentPosition(LocationAccuracy.high)\` → 2-5 giây.  
  \- Task 2: Ghi âm 5 giây bằng \`record\` → lưu file \`.m4a\` tạm.  
\- Khi cả hai task xong: Gửi \`POST /api/sos\` (multipart) \+ emit Socket \`sosAlert\`.  
\- Decision (Network):  
  \- Mất kết nối → đẩy vào queue, retry mỗi 10 giây cho đến khi gửi được.  
  \- Có kết nối → tiếp tục.  
\- Backend xử lý:  
  \- Lưu \`SOSAlert(status=ACTIVE)\`.  
  \- Upload audio lên storage.  
  \- Gửi FCM ưu tiên cao đến tất cả thiết bị Parent.  
  \- Phát Socket \`sosAlert\` đến room \`family\_{userId}\`.  
\- Parent nhận cảnh báo:  
  \- FCM hiện trên màn hình khóa với chuông kéo dài 30s.  
  \- App đang mở → popup full-screen với địa chỉ \+ nút "Mở bản đồ" \+ nút "Nghe ghi âm".  
\- Decision: Phụ huynh xử lý thế nào?  
  \- Nhấn "Đã xem" → \`PUT /api/sos/:id/acknowledge\` → \`status \= ACKNOWLEDGED\`.  
  \- Gọi điện cho trẻ trực tiếp → kết thúc luồng (không cần update qua app).  
\- Kết thúc: Trẻ thấy thông báo "Phụ huynh đã nhận được cảnh báo" trên Child Dashboard.

\*\[Hình 3.5.5.1: Activity Diagram — Kích hoạt SOS — sẽ được chèn tại đây\]\*

## **3.6. Thiết kế giao diện mobile** {#3.6.-thiết-kế-giao-diện-mobile}

### *3.6.1. Nguyên tắc thiết kế* {#3.6.1.-nguyên-tắc-thiết-kế}

KidFun là một app mobile với hai chế độ trên cùng một APK:

Chế độ Parent (Phụ huynh):  
\- Phong cách Material Design 3, chuyên nghiệp, tối giản.  
\- Màu chủ đạo: Indigo (\`\#6366f1\`), accent Pink (\`\#f472b6\`).  
\- Bottom Navigation Bar 5 tab: Dashboard, Hồ sơ, Vị trí, Báo cáo, Cài đặt.  
\- Sử dụng \`Card\`, \`ListTile\`, \`FloatingActionButton\` của Material 3\.  
\- Biểu đồ thống kê bằng \`fl\_chart\` (BarChart, PieChart, LineChart).  
\- Bản đồ bằng \`mapbox\_maps\_flutter\`.

Chế độ Child (Trẻ em):  
\- Giao diện đơn giản, một thông tin chính: thời gian còn lại.  
\- Màu sắc tươi sáng, gradient chuyển màu theo thời gian còn lại:  
  \- Xanh lá → vàng → cam → đỏ.  
\- Chữ cỡ lớn (48–72 sp), bo tròn (\`borderRadius: 24dp\`), icon lớn.  
\- Nút "Xin thêm giờ" và "SOS" nổi bật, vị trí cố định, dễ chạm.  
\- Hỗ trợ rung (\`HapticFeedback.heavyImpact\`) khi nhấn nút quan trọng.

### *3.6.2. Wireframe các màn hình mobile chính* {#3.6.2.-wireframe-các-màn-hình-mobile-chính}

Màn hình 1 — Splash \+ Login (chung cho cả 2 chế độ):  
\- Splash: logo KidFun \+ gradient indigo→pink.  
\- Login: TextField email, TextField password, button "Đăng nhập", nút "Đăng nhập với Google", link "Quên mật khẩu", link "Đăng ký".

\*\[Hình 3.6.2.1: Wireframe Splash \+ Login — sẽ được chèn tại đây\]\*

Màn hình 2 — Chọn chế độ (Mode Selection):  
\- Hai card lớn:  
  \- "Tôi là Phụ huynh" (icon người lớn).  
  \- "Tôi là Trẻ em" (icon trẻ em).

\*\[Hình 3.6.2.2: Wireframe Mode Selection — sẽ được chèn tại đây\]\*

Màn hình 3 — Parent Dashboard:  
\- AppBar: avatar \+ tên người dùng, icon notification.  
\- Card "Hồ sơ con đang giám sát" (PageView).  
\- Card "Yêu cầu thêm giờ đang chờ" (nếu có).  
\- Card "Cảnh báo AI gần đây".  
\- Bottom Navigation Bar.

\*\[Hình 3.6.2.3: Wireframe Parent Dashboard — sẽ được chèn tại đây\]\*

Màn hình 4 — Cài đặt giới hạn thời gian (Parent):  
\- AppBar với tên hồ sơ \+ nút "Lưu".  
\- ListView 7 hàng (Thứ 2 — CN), mỗi hàng có Switch \+ Slider số phút.

\*\[Hình 3.6.2.4: Wireframe Time Limit Settings — sẽ được chèn tại đây\]\*

Màn hình 5 — Child Dashboard (đang sử dụng):  
\- Trung tâm: CircularProgressIndicator lớn (kích thước 60% màn hình) với số phút còn lại ở giữa.  
\- Thanh trên: avatar \+ tên hồ sơ.  
\- Nút "Xin thêm giờ" hình pill ở dưới.  
\- Icon SOS nhỏ ở góc trên phải.

\*\[Hình 3.6.2.5: Wireframe Child Dashboard — sẽ được chèn tại đây\]\*

Màn hình 6 — Lock Screen (Kiosk Mode):  
\- Toàn màn hình, fullscreen mode (ẩn StatusBar và NavigationBar).  
\- Icon khóa lớn \+ tiêu đề "Đã hết thời gian sử dụng hôm nay".  
\- Câu chúc: "Hãy nghỉ ngơi mắt và làm bài tập về nhà nhé\!"  
\- Nút lớn "Xin thêm giờ" ở giữa.

\*\[Hình 3.6.2.6: Wireframe Lock Screen — sẽ được chèn tại đây\]\*

Màn hình 7 — Map vị trí trẻ \+ Geofence (Parent):  
\- Mapbox map fullscreen.  
\- Marker vị trí hiện tại của trẻ (avatar tròn).  
\- Polyline lịch sử di chuyển trong ngày.  
\- Circle overlay các vùng geofence đã tạo.  
\- FAB "Thêm vùng an toàn".

\*\[Hình 3.6.2.7: Wireframe Map \+ Geofence — sẽ được chèn tại đây\]\*

Màn hình 8 — Báo cáo thống kê (Parent):  
\- Tab "Hôm nay" / "Tuần này" / "30 ngày".  
\- BarChart thời gian sử dụng theo ngày.  
\- PieChart phân bổ theo từng app.  
\- Bảng "Top 10 app dùng nhiều nhất".

\*\[Hình 3.6.2.8: Wireframe Reports — sẽ được chèn tại đây\]\*

## **3.7. Sơ đồ lớp (Class Diagram)** {#3.7.-sơ-đồ-lớp-(class-diagram)}

Sơ đồ lớp mô tả cấu trúc tĩnh của toàn bộ hệ thống. Các lớp thực thể được hiện thực dưới dạng model trong Prisma schema (phía backend) và class Dart tương ứng trong \`lib/shared/models/\` (phía Flutter mobile). Hệ thống có tổng cộng \*\*32 lớp thực thể\*\* chia thành 7 nhóm chức năng.

### *3.7.1. Nhóm lõi — Tài khoản và Định danh* {#3.7.1.-nhóm-lõi-—-tài-khoản-và-định-danh}

Lớp \`User\` (Người dùng — phụ huynh):  
\- Thuộc tính: \`id: Int (PK, autoIncrement)\`, \`email: String (unique)\`, \`passwordHash: String?\`, \`googleId: String? (unique)\`, \`fullName: String\`, \`phoneNumber: String?\`, \`resetToken: String?\`, \`resetTokenExpiry: DateTime?\`, \`resetOtp: String?\`, \`resetOtpExpiry: DateTime?\`, \`createdAt: DateTime\`, \`updatedAt: DateTime\`.  
\- Quan hệ: \`1-n\` với \`Profile\`, \`Device\`, \`Notification\`, \`FCMToken\`.  
\- Phương thức chính: \`register()\`, \`login()\`, \`forgotPassword()\`, \`verifyOtp()\`, \`resetPassword()\`.

Lớp \`Profile\` (Hồ sơ trẻ em):  
\- Thuộc tính: \`id: Int (PK)\`, \`userId: Int (FK → User)\`, \`profileName: String\`, \`dateOfBirth: DateTime?\`, \`avatarUrl: String?\`, \`isActive: Boolean \= true\`, \`createdAt: DateTime\`.  
\- Quan hệ: thuộc một \`User\`; \`1-n\` với nhiều entity con (Device, TimeLimit, BlockedApp, BlockedWebsite, ... — xem 3.7.2 trở đi); \`1-1\` với \`SchoolSchedule\`.  
\- Phương thức chính: \`getActiveDevices()\`, \`getCurrentUsageMinutes()\`, \`getRemainingMinutes()\`.

Lớp \`Device\` (Thiết bị):  
\- Thuộc tính: \`id: Int (PK)\`, \`userId: Int (FK)\`, \`profileId: Int? (FK → Profile)\`, \`deviceName: String\`, \`deviceCode: String (unique)\`, \`osVersion: String?\`, \`isOnline: Boolean \= false\`, \`lastSeen: DateTime?\`, \`pairingCode: String? (unique)\`, \`pairingCodeExpiry: DateTime?\`, \`createdAt: DateTime\`.  
\- Quan hệ: thuộc một \`User\` và \`Profile\`; \`1-n\` với \`UsageSession\`, \`AppUsageLog\`, \`LocationLog\`, \`SOSAlert\`, \`Application\`, \`Session\`, \`TimeExtensionRequest\`, \`YouTubeLog\`, \`FCMToken\`.  
\- Phương thức chính: \`generatePairingCode()\`, \`link(pairingCode)\`, \`updateOnlineStatus()\`, \`sendPolicyUpdate()\`.

Lớp \`FCMToken\` (Token push notification):  
\- Thuộc tính: \`id: Int (PK)\`, \`userId: Int (FK)\`, \`deviceId: Int? (FK)\`, \`token: String (unique)\`, \`platform: String (ANDROID|IOS)\`, \`createdAt: DateTime\`, \`updatedAt: DateTime\`.  
\- Quan hệ: thuộc một \`User\`, tùy chọn thuộc một \`Device\`.

Lớp \`Notification\` (Thông báo trong ứng dụng):  
\- Thuộc tính: \`id: Int (PK)\`, \`userId: Int (FK)\`, \`title: String\`, \`message: String?\`, \`type: String (INFO|WARNING|ALERT|SOS)\`, \`isRead: Boolean \= false\`, \`createdAt: DateTime\`.

### *3.7.2. Nhóm kiểm soát thời gian* {#3.7.2.-nhóm-kiểm-soát-thời-gian}

Lớp \`TimeLimit\` (Giới hạn thời gian theo ngày):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`dayOfWeek: Int (0–6)\`, \`dailyLimitMinutes: Int \= 120\`, \`limitMinutes: Int?\`, \`isActive: Boolean \= true\`, \`isGradual: Boolean \= false\`, \`gradualTarget: Int?\`, \`gradualWeeks: Int?\`, \`gradualStartDate: DateTime?\`, \`createdAt: DateTime\`, \`updatedAt: DateTime\`.  
\- Ràng buộc: \`unique(profileId, dayOfWeek)\`.  
\- Phương thức: \`applyGradualReduction()\`, \`getEffectiveLimit(currentDate)\`.

Lớp \`UsageSession\` (Phiên sử dụng thiết bị):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`deviceId: Int (FK)\`, \`startTime: DateTime\`, \`endTime: DateTime?\`, \`isActive: Boolean \= true\`, \`createdAt\`, \`updatedAt\`.  
\- Phương thức: \`start()\`, \`end()\`, \`getDurationMinutes()\`.

Lớp \`Session\` (Phiên kế thừa từ V2):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int?\`, \`deviceId: Int (FK)\`, \`startTime: DateTime\`, \`endTime: DateTime?\`, \`totalMinutes: Int?\`, \`bonusMinutes: Int \= 0\`, \`status: String \= ACTIVE\`.

Lớp \`TimeExtensionRequest\` (Yêu cầu thêm giờ):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`deviceId: Int (FK)\`, \`requestMinutes: Int\`, \`reason: String?\`, \`status: String (PENDING|APPROVED|REJECTED|EXPIRED)\`, \`responseMinutes: Int?\`, \`respondedAt: DateTime?\`, \`createdAt: DateTime\`.  
\- Phương thức: \`approve(responseMinutes)\`, \`reject()\`, \`expire()\`.

### *3.7.3. Nhóm chặn ứng dụng và website* {#3.7.3.-nhóm-chặn-ứng-dụng-và-website}

Lớp \`BlockedApp\` (Ứng dụng bị chặn):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`packageName: String\`, \`appName: String?\`, \`isBlocked: Boolean \= true\`, \`createdAt\`, \`updatedAt\`.  
\- Ràng buộc: \`unique(profileId, packageName)\`.

Lớp \`AppTimeLimit\` (Giới hạn thời gian theo từng app — Sprint 8):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`packageName: String\`, \`appName: String?\`, \`dailyLimitMinutes: Int\`, \`isActive: Boolean \= true\`, \`createdAt\`, \`updatedAt\`.  
\- Ràng buộc: \`unique(profileId, packageName)\`.

Lớp \`Application\` (Danh sách app cài trên thiết bị):  
\- Thuộc tính: \`id: Int (PK)\`, \`deviceId: Int (FK)\`, \`appName: String\`, \`exePath: String?\`, \`category: String \= "Other"\`, \`isBlocked: Boolean \= false\`, \`timeLimitMinutes: Int?\`, \`createdAt\`.

Lớp \`BlockedWebsite\` (Website bị chặn theo domain):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`blockType: String (DOMAIN|KEYWORD)\`, \`blockValue: String\`, \`createdAt\`.

Lớp \`WebCategory\` (Danh mục website — Sprint 8):  
\- Thuộc tính: \`id: Int (PK)\`, \`name: String (unique)\`, \`displayName: String\`, \`description: String?\`.  
\- Quan hệ: \`1-n\` với \`WebCategoryDomain\` và \`BlockedCategory\`.

Lớp \`WebCategoryDomain\` (Domain thuộc danh mục):  
\- Thuộc tính: \`id: Int (PK)\`, \`categoryId: Int (FK)\`, \`domain: String\`.  
\- Ràng buộc: \`unique(categoryId, domain)\`.

Lớp \`BlockedCategory\` (Danh mục bị chặn theo hồ sơ):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`categoryId: Int (FK → WebCategory)\`, \`isBlocked: Boolean \= true\`, \`createdAt\`.  
\- Ràng buộc: \`unique(profileId, categoryId)\`.

Lớp \`CategoryOverride\` (Cho phép override domain trong danh mục đã chặn):  
\- Thuộc tính: \`id: Int (PK)\`, \`blockedCategoryId: Int (FK)\`, \`domain: String\`.  
\- Ràng buộc: \`unique(blockedCategoryId, domain)\`.

Lớp \`CustomBlockedDomain\` (Domain chặn thủ công ngoài danh mục):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`domain: String\`, \`reason: String?\`, \`createdAt\`.  
\- Ràng buộc: \`unique(profileId, domain)\`.

### *3.7.4. Nhóm theo dõi hoạt động* {#3.7.4.-nhóm-theo-dõi-hoạt-động}

Lớp \`UsageLog\` (Nhật ký sử dụng):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`deviceId: Int?\`, \`appName: String\`, \`websiteUrl: String?\`, \`startTime: DateTime\`, \`endTime: DateTime?\`, \`durationSeconds: Int?\`, \`activityType: String\`.

Lớp \`AppUsageLog\` (Thống kê sử dụng app theo ngày):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`deviceId: Int (FK)\`, \`packageName: String\`, \`appName: String?\`, \`usageSeconds: Int\`, \`date: DateTime\`, \`createdAt\`, \`updatedAt\`.  
\- Ràng buộc: \`unique(profileId, deviceId, packageName, date)\`.

Lớp \`Warning\` (Cảnh báo đã gửi):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`deviceId: Int?\`, \`warningType: String (SOFT\_30|SOFT\_15|SOFT\_5|LOCK)\`, \`message: String\`, \`userResponse: String?\`, \`warnedAt: DateTime\`, \`respondedAt: DateTime?\`.

Lớp \`ReportSnapshot\` (Snapshot báo cáo định kỳ — Sprint 9):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`type: String (DAILY|WEEKLY)\`, \`periodStart: DateTime\`, \`periodEnd: DateTime\`, \`data: Json\`, \`generatedAt: DateTime\`.  
\- Ràng buộc: \`unique(profileId, type, periodStart)\`.

### *3.7.5. Nhóm vị trí và khẩn cấp* {#3.7.5.-nhóm-vị-trí-và-khẩn-cấp}

Lớp \`LocationLog\` (Nhật ký GPS):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`deviceId: Int (FK)\`, \`latitude: Float\`, \`longitude: Float\`, \`accuracy: Float?\`, \`address: String?\`, \`source: String \= GPS (GPS|NETWORK|FUSED)\`, \`createdAt: DateTime\`.  
\- Index: \`(profileId, createdAt)\`.

Lớp \`Geofence\` (Vùng an toàn):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`name: String\`, \`latitude: Float\`, \`longitude: Float\`, \`radius: Int (mét)\`, \`isActive: Boolean \= true\`, \`createdAt\`, \`updatedAt\`.  
\- Quan hệ: \`1-n\` với \`GeofenceEvent\`.

Lớp \`GeofenceEvent\` (Sự kiện ENTER/EXIT vùng):  
\- Thuộc tính: \`id: Int (PK)\`, \`geofenceId: Int (FK)\`, \`profileId: Int (FK)\`, \`type: String (ENTER|EXIT)\`, \`latitude: Float\`, \`longitude: Float\`, \`createdAt: DateTime\`.  
\- Index: \`(profileId, createdAt)\`.

Lớp \`SOSAlert\` (Cảnh báo khẩn cấp):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`deviceId: Int (FK)\`, \`latitude: Float\`, \`longitude: Float\`, \`address: String?\`, \`audioUrl: String?\`, \`message: String?\`, \`status: String \= ACTIVE (ACTIVE|ACKNOWLEDGED|RESOLVED)\`, \`acknowledgedAt: DateTime?\`, \`resolvedAt: DateTime?\`, \`createdAt: DateTime\`.  
\- Index: \`(profileId, createdAt)\`.  
\- Phương thức: \`acknowledge()\`, \`resolve()\`.

### *3.7.6. Nhóm chế độ học (School Mode — Sprint 8\)* {#3.7.6.-nhóm-chế-độ-học-(school-mode-—-sprint-8)}

Lớp \`SchoolSchedule\` (Cấu hình chế độ học):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK, unique)\`, \`isEnabled: Boolean \= true\`, \`templateStartTime: String?\`, \`templateEndTime: String?\`, \`manualOverride: String?\`, \`overrideUntil: DateTime?\`, \`createdAt\`, \`updatedAt\`.  
\- Quan hệ: \`1-1\` với \`Profile\`; \`1-n\` với \`SchoolDaySchedule\`, \`AllowedSchoolApp\`.

Lớp \`SchoolDaySchedule\` (Lịch học theo từng ngày trong tuần):  
\- Thuộc tính: \`id: Int (PK)\`, \`scheduleId: Int (FK)\`, \`dayOfWeek: Int (0–6)\`, \`isEnabled: Boolean \= true\`, \`startTime: String (HH:mm)\`, \`endTime: String (HH:mm)\`.  
\- Ràng buộc: \`unique(scheduleId, dayOfWeek)\`.

Lớp \`AllowedSchoolApp\` (Whitelist app trong giờ học):  
\- Thuộc tính: \`id: Int (PK)\`, \`scheduleId: Int (FK)\`, \`packageName: String\`, \`appName: String?\`, \`createdAt\`.  
\- Ràng buộc: \`unique(scheduleId, packageName)\`.

### *3.7.7. Nhóm YouTube và AI (Sprint 9\)* {#3.7.7.-nhóm-youtube-và-ai-(sprint-9)}

Lớp \`YouTubeLog\` (Nhật ký video YouTube):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`deviceId: Int (FK)\`, \`videoTitle: String\`, \`channelName: String?\`, \`videoId: String?\`, \`thumbnailUrl: String?\`, \`watchedAt: DateTime\`, \`durationSeconds: Int \= 0\`, \`isAnalyzed: Boolean \= false\`, \`dangerLevel: Int? (1–5)\`, \`category: String? (SAFE|BULLY|SEXUAL|DRUG|VIOLENCE|SELF\_HARM|DISTURBING)\`, \`aiSummary: String?\`, \`isBlocked: Boolean \= false\`.  
\- Quan hệ: \`1-n\` với \`AIAlert\`.  
\- Index: \`(profileId, watchedAt)\`, \`(isAnalyzed)\`, \`(dangerLevel)\`.

Lớp \`AIAlert\` (Cảnh báo từ AI):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`youtubeLogId: Int (FK)\`, \`dangerLevel: Int\`, \`category: String\`, \`summary: String\`, \`isRead: Boolean \= false\`, \`notifiedAt: DateTime?\`, \`createdAt: DateTime\`.  
\- Index: \`(profileId, createdAt)\`, \`(isRead)\`.

Lớp \`BlockedVideo\` (Video YouTube bị chặn):  
\- Thuộc tính: \`id: Int (PK)\`, \`profileId: Int (FK)\`, \`videoTitle: String\`, \`channelName: String?\`, \`videoId: String?\`, \`reason: String? (AI\_DETECTED|PARENT\_MANUAL)\`, \`createdAt: DateTime\`.  
\- Index: \`(profileId)\`.

### *3.7.8. Đối ứng phía Flutter* {#3.7.8.-đối-ứng-phía-flutter}

Mỗi class Prisma model có một class Dart tương ứng trong \`lib/shared/models/\` (sinh code qua \`json\_serializable\` hoặc viết tay) với các phương thức \`fromJson()\`, \`toJson()\`, \`copyWith()\`. Riverpod providers (\`AsyncNotifier\`) bao quanh các model này để cung cấp state reactive cho UI.

<img src="../../diagrams/class_diagram.png" alt="Sơ đồ Class Diagram đầy đủ 32 lớp" style="width:100%; max-width:100%;">  
*Hình 3.7.1: Sơ đồ Class Diagram đầy đủ 32 lớp*

## **3.8. Thiết kế cơ sở dữ liệu (ERD — Entity Relationship Diagram)** {#3.8.-thiết-kế-cơ-sở-dữ-liệu-(erd-—-entity-relationship-diagram)}

### *3.8.1. Tổng quan schema* {#3.8.1.-tổng-quan-schema}

Cơ sở dữ liệu PostgreSQL của KidFun (hosted trên Supabase) bao gồm 32 bảng được khai báo trong \`prisma/schema.prisma\`. Schema được thiết kế theo chuẩn 3NF với các khóa ngoại có ràng buộc \`onDelete: Cascade\` để đảm bảo toàn vẹn dữ liệu khi xóa hồ sơ hoặc tài khoản.

### *3.8.2. Danh sách bảng theo nhóm chức năng* {#3.8.2.-danh-sách-bảng-theo-nhóm-chức-năng}

Nhóm 1 — Tài khoản & Định danh (5 bảng):

| Bảng | Mô tả ngắn |
| :---- | :---- |
| **users** | Tài khoản phụ huynh (email, password hash, Google ID) |
| **profiles** | Hồ sơ trẻ em do phụ huynh tạo |
| **devices** | Thiết bị Android đã liên kết |
| **fcm\_tokens** | Token Firebase Cloud Messaging |
| **notifications** | Thông báo trong ứng dụng |

Nhóm 2 — Kiểm soát thời gian (4 bảng):

| Bảng | Mô tả ngắn |
| :---- | :---- |
|  **time\_limits**  | Giới hạn thời gian theo từng ngày trong tuần |
|  **usage\_sessions**  | Phiên sử dụng thiết bị (start/end) |
|  **time\_extension\_requests**  | Yêu cầu thêm giờ |
|  **sessions**  | Phiên kế thừa từ V2 (legacy) |

Nhóm 3 — Chặn ứng dụng & website (8 bảng):

| Bảng | Mô tả ngắn |
| :---- | :---- |
|   **blocked\_apps**   | App bị chặn theo \`packageName\` |
|   **app\_time\_limits**   | Giới hạn riêng cho từng app |
|   **applications**   | Danh sách app đã cài trên thiết bị (sync từ Child) |
|   **blocked\_websites**   | Website chặn theo domain/keyword |
|   **web\_categories**   | Danh mục website (adult, gambling, ...) |
|   **web\_category\_domains**   | Domain thuộc danh mục |
|   **blocked\_categories**   | Danh mục bị chặn theo hồ sơ |
|   **category\_overrides**   | Cho phép một số domain trong danh mục đã chặn |
|   **custom\_blocked\_domains**   | Domain chặn thủ công ngoài danh mục |

Nhóm 4 — Theo dõi hoạt động (4 bảng):

| Bảng | Mô tả ngắn |
| ----- | ----- |
|   **usage\_logs**   | Log sử dụng chi tiết (app/web/time) |
|   **app\_usage\_logs**   | Tổng thời gian sử dụng app theo ngày |
|   **warnings**   | Cảnh báo đã gửi (SOFT\_30, SOFT\_15, SOFT\_5, LOCK) |
|   **report\_snapshots**   | Snapshot báo cáo định kỳ (DAILY/WEEKLY) |

Nhóm 5 — Vị trí & Khẩn cấp (4 bảng):

| Bảng | Mô tả ngắn |
| :---- | :---- |
|   **location\_logs**   | Nhật ký GPS định kỳ |
|   **geofences**   | Vùng an toàn (tâm \+ bán kính) |
|   **geofence\_events**   | Sự kiện ENTER/EXIT vùng |
|   **sos\_alerts**   | Cảnh báo SOS với GPS \+ audio |

Nhóm 6 — Chế độ học (3 bảng):

| Bảng | Mô tả ngắn |
| :---- | :---- |
|  **school\_schedules**  | Cấu hình chế độ học (bật/tắt, override) |
|  **school\_day\_schedules**  | Lịch học theo ngày \+ giờ học |
|  **allowed\_school\_apps**  | Whitelist app trong giờ học |

Nhóm 7 — YouTube & AI (3 bảng):

| Bảng | Mô tả ngắn |
| :---- | :---- |
|   **youtube\_logs**   | Lịch sử video trẻ đã xem \+ kết quả AI phân tích |
|   **ai\_alerts**   | Cảnh báo AI khi \`dangerLevel ≥ 3\` |
|   **blocked\_videos**   | Video bị chặn (do AI hoặc parent thủ công) |

### *3.8.3. Mối quan hệ giữa các bảng* {#3.8.3.-mối-quan-hệ-giữa-các-bảng}

Quan hệ User-centric:  
\- \`User (1) — (n) Profile\` — Một phụ huynh quản lý nhiều hồ sơ con.  
\- \`User (1) — (n) Device\` — Một tài khoản đăng ký nhiều thiết bị.  
\- \`User (1) — (n) Notification\` — Thông báo dành riêng cho mỗi user.  
\- \`User (1) — (n) FCMToken\` — Token push notification của các thiết bị thuộc tài khoản.

Quan hệ Profile-centric (trung tâm dữ liệu):  
\- \`Profile (1) — (n) Device\` — Mỗi hồ sơ có thể liên kết nhiều thiết bị.  
\- \`Profile (1) — (n) TimeLimit\` với \`unique(profileId, dayOfWeek)\` — 7 bản ghi/hồ sơ (một cho mỗi ngày).  
\- \`Profile (1) — (n) BlockedApp\` với \`unique(profileId, packageName)\`.  
\- \`Profile (1) — (n) AppTimeLimit\` với \`unique(profileId, packageName)\`.  
\- \`Profile (1) — (n) BlockedWebsite\`.  
\- \`Profile (1) — (n) BlockedCategory\` với \`unique(profileId, categoryId)\`.  
\- \`Profile (1) — (n) CustomBlockedDomain\` với \`unique(profileId, domain)\`.  
\- \`Profile (1) — (n) UsageSession\`, \`UsageLog\`, \`AppUsageLog\`, \`Warning\`.  
\- \`Profile (1) — (n) LocationLog\`, \`Geofence\`, \`GeofenceEvent\`, \`SOSAlert\`.  
\- \`Profile (1) — (n) YouTubeLog\`, \`AIAlert\`, \`BlockedVideo\`.  
\- \`Profile (1) — (n) TimeExtensionRequest\`.  
\- \`Profile (1) — (n) ReportSnapshot\`.  
\- \`Profile (1) — (1) SchoolSchedule\` với \`unique(profileId)\`.

Quan hệ Device-centric:  
\- \`Device (1) — (n) Application\` — App đã cài trên thiết bị.  
\- \`Device (1) — (n) UsageSession\`, \`Session\`, \`AppUsageLog\`, \`LocationLog\`, \`SOSAlert\`, \`YouTubeLog\`, \`FCMToken\`.  
\- \`Device (1) — (n) TimeExtensionRequest\` — Yêu cầu xin giờ phát đi từ thiết bị nào.

Quan hệ Web Filtering:  
\- \`WebCategory (1) — (n) WebCategoryDomain\` với \`unique(categoryId, domain)\`.  
\- \`WebCategory (1) — (n) BlockedCategory\`.  
\- \`BlockedCategory (1) — (n) CategoryOverride\` với \`unique(blockedCategoryId, domain)\`.

Quan hệ School Mode:  
\- \`SchoolSchedule (1) — (n) SchoolDaySchedule\` với \`unique(scheduleId, dayOfWeek)\`.  
\- \`SchoolSchedule (1) — (n) AllowedSchoolApp\` với \`unique(scheduleId, packageName)\`.

Quan hệ Geofence:  
\- \`Geofence (1) — (n) GeofenceEvent\`.

Quan hệ YouTube \+ AI:  
\- \`YouTubeLog (1) — (n) AIAlert\`.

### *3.8.4. Quy ước ràng buộc và Index* {#3.8.4.-quy-ước-ràng-buộc-và-index}

Cascade rules (xóa dây chuyền):  
\- Khi xóa \`User\` → cascade xóa toàn bộ \`Profile\`, \`Device\`, \`Notification\`, \`FCMToken\` của user đó.  
\- Khi xóa \`Profile\` → cascade xóa toàn bộ các bản ghi con (TimeLimit, BlockedApp, UsageLog, LocationLog, SOSAlert, YouTubeLog, ...).  
\- Khi xóa \`Device\` (với quan hệ \`profileId? → SetNull\`) → các bản ghi con của Device không bị xóa nhưng \`deviceId\` trở về null để giữ lịch sử.

Index quan trọng (tăng tốc query):  
\- \`location\_logs(profileId, createdAt)\` — query lịch sử vị trí theo thời gian.  
\- \`geofence\_events(profileId, createdAt)\`.  
\- \`sos\_alerts(profileId, createdAt)\`.  
\- \`youtube\_logs(profileId, watchedAt)\`, \`(isAnalyzed)\`, \`(dangerLevel)\`.  
\- \`ai\_alerts(profileId, createdAt)\`, \`(isRead)\`.  
\- \`app\_usage\_logs(profileId, deviceId, packageName, date)\` — unique \+ index.  
\- \`report\_snapshots(profileId, type, periodStart)\` — unique \+ index.

Unique constraints (đảm bảo toàn vẹn nghiệp vụ):  
\- \`users.email\` — không hai tài khoản trùng email.  
\- \`users.googleId\` — mỗi tài khoản Google chỉ link một user.  
\- \`devices.deviceCode\` và \`devices.pairingCode\` — mã thiết bị và mã pairing duy nhất.  
\- \`time\_limits(profileId, dayOfWeek)\` — mỗi hồ sơ chỉ có một limit cho mỗi ngày.  
\- \`school\_schedules.profileId\` — mỗi hồ sơ có nhiều nhất một SchoolSchedule.  
\- \`blocked\_apps(profileId, packageName)\`, \`app\_time\_limits(profileId, packageName)\`, \`custom\_blocked\_domains(profileId, domain)\`, \`blocked\_categories(profileId, categoryId)\` — chống trùng lặp.

\*\[Hình 3.8.1: ERD đầy đủ — Sơ đồ quan hệ thực thể 32 bảng — sẽ được chèn tại đây\]\*

# 

# 

# 

# 

# 

# 

# 

# 

# 

# 

# 

# **CHƯƠNG 4: CÀI ĐẶT VÀ KIỂM THỬ** {#chương-4:-cài-đặt-và-kiểm-thử}

## **4.1. Môi trường phát triển** {#4.1.-môi-trường-phát-triển}

### *4.1.1. Phần cứng* {#4.1.1.-phần-cứng}

| Thành phần | Cấu hình |
| ----- | ----- |
| CPU | Intel Core i5/i7 thế hệ 11 trở lên (hoặc AMD Ryzen 5/7 tương đương) |
| RAM | Tối thiểu 16 GB (do Flutter \+ Android Emulator \+ Backend chạy đồng thời) |
| Ổ cứng | SSD 256 GB trở lên (Gradle build, Android SDK chiếm nhiều dung lượng) |
| Màn hình | 1920 × 1080 trở lên |
| Kết nối mạng | Internet ổn định (tải Flutter packages, kết nối Supabase, Firebase) |
| **Thiết bị kiểm thử** | **Tối thiểu 2 điện thoại Android thật** (Samsung, Xiaomi, ...) chạy Android 10+ để test luồng Parent ↔ Child end-to-end |

### *4.1.2. Phần mềm và công cụ phát triển* {#4.1.2.-phần-mềm-và-công-cụ-phát-triển}

| Công cụ | Phiên bản | Mục đích |
| ----- | ----- | ----- |
| **Flutter SDK** | 3.19.x | Framework mobile chính |
| **Dart SDK** | 3.3.x | Ngôn ngữ Flutter |
| **Android Studio** | Hedgehog (2023.1) trở lên | IDE chính cho Flutter \+ Kotlin native |
| **Android SDK** | API 26 (Android 8.0) trở lên | Build target |
| **Android NDK** | r25+ | Build native code |
| **Visual Studio Code** | 1.90+ | IDE phụ cho code Dart và backend |
| **Node.js** | 20.x LTS | Môi trường chạy backend |
| **PostgreSQL** | 15.x | Cơ sở dữ liệu (cài cục bộ cho dev) |
| **Git** | 2.40+ | Quản lý phiên bản |
| **Postman** | 11.x | Kiểm thử API thủ công |
| **Prisma Studio** | (đi kèm Prisma) | GUI quản lý database |
| **Mapbox account** | (free tier) | Lấy access token cho bản đồ |

### *4.1.3. Dịch vụ đám mây* {#4.1.3.-dịch-vụ-đám-mây}

| Dịch vụ | Mục đích |
| ----- | ----- |
| **Railway** | Platform-as-a-Service host backend Node.js (auto-deploy từ GitHub) — môi trường chính |
| **Oracle Cloud Infrastructure** | VM ARM Ampere (Always Free) — bản triển khai dự phòng khi Railway gặp sự cố |
| **Supabase** | PostgreSQL database hosting \+ connection pooling (PgBouncer) |
| **Firebase** | Firebase Cloud Messaging (FCM) cho push notification |
| **Groq Cloud** | API key cho mô hình Llama 4 Scout (provider AI chính) |
| **OpenRouter** | API key cho Llama 4 Scout (provider AI dự phòng) |
| **Google Cloud** | OAuth 2.0 client cho Google Sign-In |
| **Mapbox** | Bản đồ hiển thị vị trí \+ geofence trong app mobile |
| **GitHub** | Quản lý mã nguồn, Pull Request review, trigger Railway auto-deploy |

### *4.1.4. Cấu hình môi trường* {#4.1.4.-cấu-hình-môi-trường}

**Backend (backend/.env):**  
DATABASE\_URL=postgresql://...@aws-0-ap-southeast-1.pooler.supabase.com:6543/postgres  
DIRECT\_URL=postgresql://...@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres  
JWT\_SECRET=\<chuỗi bí mật 64 ký tự\>  
JWT\_EXPIRES\_IN=24h  
PORT=3001  
SMTP\_USER=\<gmail\>@gmail.com  
SMTP\_PASS=\<16-char app password\>  
FIREBASE\_PROJECT\_ID=kidfun-v3  
FIREBASE\_CLIENT\_EMAIL=...  
FIREBASE\_PRIVATE\_KEY="-----BEGIN PRIVATE KEY-----..."  
GROQ\_API\_KEY=\<Groq API key\>  
OPENROUTER\_API\_KEY=\<OpenRouter API key\>

**Mobile (mobile/.env):**  
API\_BASE\_URL=https://api.kidfun.app  
SOCKET\_URL=https://api.kidfun.app  
MAPBOX\_ACCESS\_TOKEN=pk.”PUBLIC KEY”  
GOOGLE\_WEB\_CLIENT\_ID=...apps.googleusercontent.com

## **4.2. Hướng dẫn cài đặt và build ứng dụng** {#4.2.-hướng-dẫn-cài-đặt-và-build-ứng-dụng}

### *4.2.1. Clone và cài đặt dependencies* {#4.2.1.-clone-và-cài-đặt-dependencies}

Clone dự án về thiết bị:  
git clone https://github.com/Khanh-4/kidfun-v2.git  
cd kidfun-v2

Cài đặt cho phần Backend:  
cd backend && npm install

Cài đặt cho phần Mobile:  
cd ../mobile && flutter pub get

### *4.2.2. Khởi tạo database* {#4.2.2.-khởi-tạo-database}

cd backend  
cp .env.example .env   \# Điền thông tin Supabase  
npx prisma migrate deploy  
npx prisma db seed

### *4.2.3. Chạy backend ở chế độ phát triển* {#4.2.3.-chạy-backend-ở-chế-độ-phát-triển}

cd backend  
npm run dev   \# Nodemon watch \+ restart khi đổi code

### *4.2.4. Chạy app mobile trên thiết bị Android thật* {#4.2.4.-chạy-app-mobile-trên-thiết-bị-android-thật}

cd mobile  
flutter devices                        \# Liệt kê thiết bị đã kết nối qua USB  
flutter run \-d \<device-id\>             \# Build \+ cài \+ chạy app  
flutter run \--release \-d \<device-id\>   \# Chạy bản release để test hiệu năng

### *4.2.5. Build APK release đã ký* {#4.2.5.-build-apk-release-đã-ký}

cd mobile  
flutter build apk \--release \--split-per-abi  
\# Output: mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

APK đã ký bằng kidfun-release.keystore để có thể cài đặt được trên thiết bị Android mà không bị cảnh báo "Unknown source", sẵn sàng phát hành lên Google Play Store ở tương lai.

## **4.3. Các chức năng chính của ứng dụng mobile** {#4.3.-các-chức-năng-chính-của-ứng-dụng-mobile}

### *4.3.1. Đăng ký và đăng nhập tài khoản* {#4.3.1.-đăng-ký-và-đăng-nhập-tài-khoản}

Phụ huynh mở app KidFun trên điện thoại Android, màn hình Splash hiển thị logo trong khi app kiểm tra JWT token đã lưu. Nếu chưa đăng nhập, chuyển đến màn hình Login. Trên màn hình này, phụ huynh có thể:  
\- Nhập email \+ mật khẩu để đăng nhập.  
\- Nhấn nút "Đăng nhập với Google" để xác thực qua Google Sign-In (gói google\_sign\_in).  
\- Nhấn link "Đăng ký" để tạo tài khoản mới.  
\- Nhấn link "Quên mật khẩu" để nhận OTP qua email.

Khi đăng nhập thành công, app lưu JWT token vào flutter\_secure\_storage (Android Keystore), Dio interceptor tự động đính kèm token vào header cho mọi request sau đó.

\*\[Hình 4.3.1.1: Màn hình Splash trên thiết bị Android — sẽ được chèn tại đây\]\*  
\*\[Hình 4.3.1.2: Màn hình đăng nhập trên thiết bị Android — sẽ được chèn tại đây\]\*

### *4.3.2. Chọn chế độ Parent / Child* {#4.3.2.-chọn-chế-độ-parent-/-child}

Sau khi đăng nhập lần đầu, app hiển thị màn hình "Bạn là ai?" với hai card lớn:  
\- **"Tôi là Phụ huynh":** App chuyển sang Login Screen.  
\- **"Tôi là Trẻ em":** App yêu cầu quét mã QR từ thiết bị phụ huynh để liên kết.  
Lựa chọn được lưu vào flutter\_secure\_storage để các lần mở sau app tự động vào đúng chế độ.

\*\[Hình 4.3.2.1: Màn hình chọn chế độ — sẽ được chèn tại đây\]\*

### *4.3.3. Quản lý hồ sơ con (Parent)* {#4.3.3.-quản-lý-hồ-sơ-con-(parent)}

Trong tab "Hồ sơ" của Parent mode, phụ huynh có thể tạo nhiều hồ sơ con. Mỗi hồ sơ gồm: Ảnh đại diện (chọn từ thư viện hoặc avatar mặc định), tên hiển thị và ngày sinh. Vuốt sang trái trên ListView để hiện nút Sửa/Xóa.

\*\[Hình 4.3.3.1: Màn hình quản lý hồ sơ con — sẽ được chèn tại đây\]\*

### *4.3.4. Liên kết thiết bị qua QR Code* {#4.3.4.-liên-kết-thiết-bị-qua-qr-code}

Để liên kết thiết bị của trẻ với hồ sơ:  
1\. **Phụ huynh:** Vào hồ sơ → "Thêm thiết bị" → app sinh mã QR (qua qr\_flutter) hiển thị fullscreen.  
2\. **Trẻ em:** Mở KidFun trên điện thoại của mình → "Tôi là Trẻ em" → "Quét QR" → camera mở (qua mobile\_scanner).  
3\. Trẻ hướng camera vào màn hình của phụ huynh → app tự động decode QR và gửi request liên kết.  
4\. Sau vài giây, cả hai thiết bị nhận thông báo "Liên kết thành công", Child chuyển sang Child Dashboard, Parent thấy thiết bị mới trong danh sách với trạng thái Online.

\*\[Hình 4.3.4.1: Màn hình QR Code trên thiết bị Parent — sẽ được chèn tại đây\]\*  
\*\[Hình 4.3.4.2: Màn hình quét QR trên thiết bị Child — sẽ được chèn tại đây\]\*

### *4.3.5. Cấp quyền đặc biệt cho Child Device* {#4.3.5.-cấp-quyền-đặc-biệt-cho-child-device}

Sau khi liên kết, app Child hướng dẫn trẻ (hoặc phụ huynh giúp) cấp các quyền đặc biệt:  
\- **Usage Access:** Mở Settings → Apps with usage access → bật KidFun.  
\- **Accessibility Service:** Settings → Accessibility → KidFun → bật.  
\- **Device Admin:** Tự động hiện dialog yêu cầu kích hoạt KidFun làm Device Admin.  
\- **Display over other apps:** Cần thiết để hiện Lock Screen.  
\- **Notification \+ Camera \+ GPS \+ Microphone:** Yêu cầu khi sử dụng các tính năng tương ứng.  
App có wizard kiểm tra từng quyền và highlight quyền còn thiếu.

\*\[Hình 4.3.5.1: Wizard cấp quyền đặc biệt — sẽ được chèn tại đây\]\*

### *4.3.6. Cài đặt giới hạn thời gian* {#4.3.6.-cài-đặt-giới-hạn-thời-gian}

Phụ huynh chọn hồ sơ → "Giới hạn thời gian" → màn hình hiển thị 7 hàng (Thứ 2 — CN). Mỗi hàng có Switch bật/tắt và Slider số phút (0–1440). Phụ huynh cũng có thể bật chế độ **Gradual Reduction** — tự động giảm giới hạn theo tuần. Khi nhấn nút "Lưu" trên AppBar, app gửi PUT /api/profiles/:id/time-limits; backend phát Socket event policyUpdate cập nhật ngay vào thiết bị Child đang online.

\*\[Hình 4.3.6.1: Màn hình cài đặt giới hạn thời gian — sẽ được chèn tại đây\]\*

### *4.3.7. Child Dashboard và Cảnh báo mềm* {#4.3.7.-child-dashboard-và-cảnh-báo-mềm}

Trên thiết bị Child, sau khi KidFunService chạy nền, Flutter UI hiển thị đồng hồ đếm ngược lớn ở giữa màn hình. Màu sắc đổi theo thời gian còn lại:  
\- **Xanh lá:** Còn \> 30 phút.  
\- **Vàng:** 15–30 phút.  
\- **Cam:** 5–15 phút.  
\- **Đỏ nhấp nháy:** \< 5 phút.  
Tại mỗi mốc 30, 15, 5 phút, app hiển thị popup AlertDialog "Còn X phút, hãy chuẩn bị tắt máy nhé\!" kèm HapticFeedback.heavyImpact() và phát âm thanh chuông (qua audioplayers).

\*\[Hình 4.3.7.1: Child Dashboard với đồng hồ đếm ngược — sẽ được chèn tại đây\]\*  
\*\[Hình 4.3.7.2: Popup cảnh báo mềm 5 phút — sẽ được chèn tại đây\]\*

### *4.3.8. Lock Screen (Kiosk Mode) khi hết giờ* {#4.3.8.-lock-screen-(kiosk-mode)-khi-hết-giờ}

Khi remainingMinutes ≤ 0, KidFunService thực hiện:  
1\. Gọi DevicePolicyManager.lockNow() để khóa màn hình hệ thống.  
2\. Khi trẻ mở khóa lại, app KidFun tự động hiện Lock Screen fullscreen (qua FLAG\_KEEP\_SCREEN\_ON \+ immersive sticky mode) — ẩn StatusBar và NavigationBar.  
3\. AccessibilityService chặn nút Home, Recent Apps — trẻ chỉ còn thấy duy nhất màn hình "Đã hết thời gian" của KidFun.  
Trên Lock Screen có duy nhất một nút "Xin thêm giờ" để trẻ giao tiếp với phụ huynh.

\*\[Hình 4.3.8.1: Lock Screen Kiosk Mode — sẽ được chèn tại đây\]\*

### *4.3.9. Yêu cầu thêm giờ và phê duyệt real-time* {#4.3.9.-yêu-cầu-thêm-giờ-và-phê-duyệt-real-time}

Trẻ nhấn "Xin thêm giờ" trên Lock Screen → nhập lý do (TextField bắt buộc ≥ 10 ký tự) → gửi. Thiết bị di động của phụ huynh:  
\- Nếu app đang mở: popup Dialog hiện ngay với thông tin hồ sơ \+ lý do.  
\- Nếu app đang đóng: FCM notification với hai action button "Đồng ý" / "Từ chối" trực tiếp trong khay thông báo.  
Phụ huynh có thể điều chỉnh số phút duyệt (slider) khác với số trẻ xin, sau đó nhấn Đồng ý. Trẻ nhận phản hồi trong vòng 1–2 giây, Lock Screen tự mở và hiển thị "Phụ huynh cho thêm X phút".

\*\[Hình 4.3.9.1: Popup yêu cầu thêm giờ trên thiết bị Parent — sẽ được chèn tại đây\]\*  
\*\[Hình 4.3.9.2: FCM Notification với action button — sẽ được chèn tại đây\]\*

### *4.3.10. Chặn ứng dụng* {#4.3.10.-chặn-ứng-dụng}

Trong Parent mode → "Chặn ứng dụng" → danh sách app đã sync từ thiết bị của con (sort theo thời gian sử dụng nhiều nhất). Phụ huynh chạm Switch để bật/tắt chặn. AppBlockerService.kt trên thiết bị Child nhận policyUpdate, lưu danh sách vào SharedPreferences. Khi trẻ cố mở app bị chặn, AccessibilityService phát hiện trong \< 500ms và đưa về Home screen kèm Toast "Ứng dụng này đã bị phụ huynh chặn".

\*\[Hình 4.3.10.1: Danh sách chặn ứng dụng (Parent) — sẽ được chèn tại đây\]\*

### *4.3.11. Theo dõi vị trí và Geofencing* {#4.3.11.-theo-dõi-vị-trí-và-geofencing}

KidFunService thu thập GPS qua geolocator mỗi 5 phút (hoặc khi có chuyển động đáng kể), gửi về backend qua POST /api/child/location. Trên Parent mode → tab "Vị trí" → Mapbox map fullscreen hiển thị:  
\- Marker vị trí hiện tại của trẻ (avatar tròn).  
\- Polyline lịch sử di chuyển trong ngày.  
\- Circle overlay các vùng geofence đã tạo.  
Để tạo geofence, phụ huynh nhấn FAB "Thêm vùng" → chạm trên bản đồ để chọn tâm → kéo slider chỉnh bán kính (50–500m). Khi trẻ vào hoặc ra khỏi vùng, GeofenceEngine backend phát hiện và gửi FCM thông báo.

\*\[Hình 4.3.11.1: Bản đồ Mapbox theo dõi vị trí trẻ — sẽ được chèn tại đây\]\*  
\*\[Hình 4.3.11.2: Tạo Geofence trên bản đồ — sẽ được chèn tại đây\]\*

### *4.3.12. Cảnh báo SOS khẩn cấp* {#4.3.12.-cảnh-báo-sos-khẩn-cấp}

Nút SOS được đặt ở góc trên phải của Child Dashboard. Trẻ nhấn giữ 2 giây (tránh chạm nhầm), app hiện loading "Đang gửi cảnh báo...", thực hiện song song:  
\- Lấy tọa độ GPS hiện tại (geolocator).  
\- Ghi âm 5 giây bằng record package.  
\- Upload file MP3 lên server.  
Thiết bị di động của phụ huynh nhận FCM notification ưu tiên cao nhất (priority: high, channelImportance: max) hiện ngay trên màn hình khóa với chuông kéo dài. Mở app sẽ thấy popup "CẢNH BÁO SOS" với địa chỉ (reverse geocode từ tọa độ), nút "Mở Maps" và nút "Nghe ghi âm" (\`audioplayers\`).

\*\[Hình 4.3.12.1: Nút SOS trên Child Dashboard — sẽ được chèn tại đây\]\*  
\*\[Hình 4.3.12.2: FCM Notification SOS ưu tiên cao — sẽ được chèn tại đây\]\*

### *4.3.13. Chế độ học (School Mode)* {#4.3.13.-chế-độ-học-(school-mode)}

Phụ huynh cấu hình lịch học từng ngày (giờ bắt đầu, kết thúc) và whitelist các app được phép trong giờ học (ví dụ: Google Classroom, Zalo, Calculator). Khi tới giờ học, SchoolModeChecker.kt kích hoạt → AppBlockerService chặn tất cả app ngoài whitelist (kể cả khi vẫn còn thời gian giải trí trong ngày).

\*\[Hình 4.3.13.1: Cấu hình chế độ học — sẽ được chèn tại đây\]\*

### *4.3.14. Giám sát YouTube \+ AI* {#4.3.14.-giám-sát-youtube-+-ai}

YouTubeTracker.kt (AccessibilityService) đọc tiêu đề video \+ tên kênh khi trẻ xem YouTube. Dữ liệu gửi về backend qua POST /api/youtube/log. AI Worker chạy mỗi 5 phút gọi mô hình **Llama 4 Scout** qua **Groq Cloud** (provider chính, tốc độ siêu nhanh nhờ LPU) — fallback sang **OpenRouter** nếu Groq fail — để phân tích:  
\- **DangerLevel 1–2:** An toàn — chỉ log.  
\- **DangerLevel 3:** Đáng chú ý — hiện trong tab YouTube.  
\- **DangerLevel 4–5:** Nguy hiểm — tạo AIAlert \+ gửi FCM cảnh báo phụ huynh.  
Phụ huynh xem danh sách video con xem trong tab "YouTube" của Parent mode, có thể chặn thủ công video không phù hợp.

\*\[Hình 4.3.14.1: Tab YouTube monitoring (Parent) — sẽ được chèn tại đây\]\*  
\*\[Hình 4.3.14.2: Cảnh báo AI nội dung nguy hiểm — sẽ được chèn tại đây\]\*

### *4.3.15. Báo cáo và thống kê* {#4.3.15.-báo-cáo-và-thống-kê}

Tab "Báo cáo" trong Parent mode hiển thị:  
\- **BarChart (fl\_chart):** Thời gian sử dụng theo từng ngày trong tuần.  
\- **PieChart (fl\_chart):** Phân bổ theo từng ứng dụng.  
\- **LineChart (fl\_chart):** Xu hướng 30 ngày qua.  
\- **Bảng Top 10:** Apps dùng nhiều nhất trong kỳ.  
Phụ huynh có thể chọn tab "Hôm nay" / "Tuần này" / "30 ngày" để xem các khoảng thời gian khác nhau.

\*\[Hình 4.3.15.1: Báo cáo với fl\_chart — sẽ được chèn tại đây\]\*

## **4.4. Kiểm thử phần mềm** {#4.4.-kiểm-thử-phần-mềm}

### *4.4.1. Chiến lược kiểm thử* {#4.4.1.-chiến-lược-kiểm-thử}

Nhóm áp dụng ba cấp độ kiểm thử:  
1\. **Unit Testing (Jest \+ Supertest):** Test các controller, service backend độc lập với mock Prisma.  
2\. **Integration Testing:** Test các API endpoint backend với database thực (test database riêng).  
3\. **Manual Testing trên thiết bị thật:** Cài app lên ít nhất 2 điện thoại Android khác hãng (Samsung \+ Xiaomi) và chạy các kịch bản người dùng end-to-end.

### *4.4.2. Kết quả Unit Test Backend* {#4.4.2.-kết-quả-unit-test-backend}

| Module | Số test | Passed | Failed | Coverage |
| ----- | ----- | ----- | ----- | ----- |
| authController | 12 | 12 | 0 | 94% |
| profileController | 8 | 8 | 0 | 89% |
| deviceController | 10 | 10 | 0 | 91% |
| timeLimitController | 6 | 6 | 0 | 87% |
| childController | 15 | 15 | 0 | 88% |
| extensionController | 8 | 8 | 0 | 92% |
| **Tổng** | **59** | **59** | **0** | **90%** |

*4.4.2. Bảng kiểm thử chức năng end-to-end (Manual Test trên Android thật)*

**TC-001: Đăng ký tài khoản trên app mobile**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-001 |
| Tên | Đăng ký tài khoản với thông tin hợp lệ trên thiết bị Android |
| Điều kiện | App mới cài, chưa từng đăng nhập |
| Dữ liệu đầu vào | email: \`test@kidfun.com\`, password: \`Test@1234\`, fullName: \`Nguyễn Văn A\` |
| Các bước | 1\. Mở app. 2\. Nhấn "Đăng ký". 3\. Nhập thông tin. 4\. Nhấn "Đăng ký". |
| Kết quả mong đợi | App nhận HTTP 201, lưu JWT vào secure storage, chuyển sang màn hình "Chọn vai trò". |
| Kết quả thực tế | Đúng như mong đợi. |
| Trạng thái | ✅ PASSED |

**TC-002: Liên kết thiết bị Child qua QR Code**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-002 |
| Tên | Trẻ quét QR từ thiết bị phụ huynh để liên kết |
| Điều kiện | Phụ huynh đã đăng nhập, đã tạo hồ sơ "Bé An"; thiết bị trẻ đã cài app |
| Các bước | 1\. Parent: Hồ sơ → Bé An → Thêm thiết bị → hiện QR. 2\. Child: Mở app → "Tôi là trẻ em" → Quét QR. |
| Kết quả mong đợi | Liên kết thành công trong \< 3 giây. Child chuyển vào Child Dashboard. Parent thấy thiết bị mới Online. |
| Kết quả thực tế | Đúng như mong đợi. Thời gian liên kết: 1.8 giây. |
| Trạng thái | ✅ PASSED |

**TC-003: Cài đặt giới hạn thời gian từ Parent → cập nhật real-time Child**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-003 |
| Tên | Parent đổi giới hạn 120→60 phút, Child cập nhật ngay |
| Điều kiện | Cả hai thiết bị online |
| Các bước | 1\. Parent: Bé An → Giới hạn thời gian → Thứ tư đổi 120→60 → Lưu. 2\. Quan sát Child. |
| Kết quả mong đợi | Child Dashboard cập nhật \`remainingMinutes\` ngay (qua \`policyUpdate\` Socket event). |
| Kết quả thực tế | Cập nhật trong vòng 250ms. |
| Trạng thái | ✅ PASSED |

**TC-004: Cảnh báo mềm 30/15/5 phút**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-004 |
| Tên | App Child phát cảnh báo đúng các mốc thời gian |
| Điều kiện | Giới hạn 150 phút, đã dùng 120 phút (còn 30\) |
| Các bước | Quan sát Child khi \`remainingMinutes\` đạt 30, 15, 5 |
| Kết quả mong đợi | Mỗi mốc: popup AlertDialog \+ rung \+ âm thanh chuông |
| Kết quả thực tế | Đúng như mong đợi. Sai số thời gian \< 15 giây. |
| Trạng thái | ✅ PASSED |

**TC-005: Lock Screen khi hết giờ**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-005 |
| Tên | Khi \`remainingMinutes ≤ 0\`, thiết bị Child khóa và kiosk mode |
| Các bước | Cho \`remainingMinutes\` giảm về 0 (chỉnh thủ công trên Parent) |
| Kết quả mong đợi | Thiết bị Child: DevicePolicyManager khóa màn hình → mở khóa lại thấy KidFun Lock Screen fullscreen, không thoát được bằng Home/Recent Apps. |
| Kết quả thực tế | Đúng như mong đợi. |
| Trạng thái | ✅ PASSED |

**TC-006: Luồng yêu cầu thêm giờ end-to-end**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-006 |
| Tên | Child gửi → Parent duyệt qua Socket.IO → Child mở khóa |
| Điều kiện | Child ở Lock Screen; Parent app đang mở |
| Dữ liệu đầu vào | requestMinutes: 30, reason: "Con đang học bài trực tuyến" |
| Các bước | 1\. Child: Xin thêm giờ → nhập lý do → gửi. 2\. Parent: popup hiện → duyệt 20 phút. 3\. Quan sát Child. |
| Kết quả mong đợi | Round-trip \< 2 giây. Child mở khóa, hiện thông báo "+20 phút". |
| Kết quả thực tế | Round-trip 480ms. |
| Trạng thái | ✅ PASSED |

**TC-007: Yêu cầu thêm giờ khi Parent app đóng → FCM Notification**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-007 |
| Tên | Parent nhận FCM notification với action button "Đồng ý"/"Từ chối" |
| Điều kiện | App Parent đã đóng hoàn toàn |
| Các bước | Child gửi yêu cầu thêm giờ |
| Kết quả mong đợi | Trong vòng 5 giây, FCM notification hiện trên thanh thông báo Parent với 2 button. Tap "Đồng ý" → backend xử lý mà không cần mở app. |
| Kết quả thực tế | FCM đến sau 2.3 giây. Action button hoạt động. |
| Trạng thái | ✅ PASSED |

**TC-008: Chặn ứng dụng**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-008 |
| Tên | Parent chặn TikTok → thiết bị Child không thể mở |
| Điều kiện | TikTok đã cài trên thiết bị Child, AccessibilityService đã bật |
| Các bước | 1\. Parent: Chặn ứng dụng → TikTok → bật. 2\. Child: thử mở TikTok. |
| Kết quả mong đợi | TikTok mở khoảng 0.3 giây thì AccessibilityService phát hiện và đưa về Home screen kèm Toast. |
| Kết quả thực tế | Đúng như mong đợi. |
| Trạng thái | ✅ PASSED |

**TC-009: SOS với GPS \+ ghi âm**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-009 |
| Tên | Trẻ kích hoạt SOS, phụ huynh nhận thông báo \+ nghe ghi âm |
| Điều kiện | GPS bật, đã cấp quyền microphone |
| Các bước | Child nhấn giữ nút SOS 2 giây |
| Kết quả mong đợi | Phụ huynh nhận FCM ưu tiên cao trong \< 5 giây với tọa độ. Mở app nghe được file ghi âm 5 giây. |
| Kết quả thực tế | FCM đến sau 2.7 giây. Ghi âm chất lượng tốt. |
| Trạng thái | ✅ PASSED |

**TC-010: Tự động khởi động sau khi reboot điện thoại**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-010 |
| Tên | Sau khi tắt nguồn rồi bật lại, \`KidFunService\` tự khởi động |
| Các bước | 1\. Đảm bảo KidFun đang chạy. 2\. Tắt nguồn thiết bị Child. 3\. Bật lại. 4\. Sau khoảng 30s, kiểm tra service. |
| Kết quả mong đợi | \`BootReceiver\` nhận BOOT\_COMPLETED → khởi động lại \`KidFunService\` → đếm giờ \+ đồng bộ tiếp tục. |
| Kết quả thực tế | Service hoạt động lại sau 18 giây. |
| Trạng thái | ✅ PASSED |

**TC-011: Đồng bộ khi mất kết nối tạm thời**

| Trường | Nội dung |
| ----- | ----- |
| Mã TC | TC-011 |
| Tên | Thiết bị Child offline khi Parent thay đổi cấu hình → tự đồng bộ khi reconnect |
| Các bước | 1\. Tắt Wi-Fi \+ Data trên Child. 2\. Parent đổi giới hạn 120→60. 3\. Bật lại mạng. |
| Kết quả mong đợi | Trong vòng 5 giây sau khi có mạng, Child nhận \`policyUpdate\` và cập nhật. |
| Kết quả thực tế | Đúng như mong đợi (3.2 giây). |
| Trạng thái | ✅ PASSED |

### *4.4.3. Tổng kết kiểm thử* {#4.4.3.-tổng-kết-kiểm-thử}

| Loại kiểm thử | Tổng TC | Passed | Failed | Tỷ lệ |
| ----- | ----- | ----- | ----- | ----- |
| Unit Test (Jest backend) | 59 | 59 | 0 | 100% |
| Integration Test (API) | 10 | 10 | 0 | 100% |
| Manual E2E (Android thật) | 30 | 29 | 1\* | 96.7% |
| **Tổng** | **99** | **98** | **1** | **98.9%** |

\* TC thất bại: Trên một thiết bị Xiaomi chạy HyperOS 1, \`KidFunService\` bị MIUI Battery Saver kill sau 2 giờ không tương tác. Đã có workaround hướng dẫn người dùng vào MIUI Settings tắt battery optimization riêng cho KidFun.

## **4.5. Triển khai sản phẩm** {#4.5.-triển-khai-sản-phẩm}

\- **Backend:** Deploy chính trên **Railway**, mỗi khi có commit mới vào nhánh main, Railway tự động build và rollout phiên bản mới có hỗ trợ WebSocket. Một bản triển khai dự phòng được cấu hình sẵn trên Oracle Cloud VM ARM (Always Free) với PM2 \+ Nginx, sẵn sàng chuyển sang khi Railway gặp sự cố. Sao lưu database tự động qua Supabase backup hàng ngày.  
\- **Mobile:** Build APK release đã ký với keystore kidfun-release.keystore, phân phối qua link tải trực tiếp trong giai đoạn demo. Sẵn sàng phát hành lên Google Play Store sau khi hoàn thiện.  
\- **CI/CD:** GitHub Actions tự động chạy npm test \+ flutter test cho mỗi Pull Request, đảm bảo code merge vào develop không phá vỡ các test hiện có.

# **CHƯƠNG 5: KẾT LUẬN VÀ HƯỚNG PHÁT TRIỂN** {#chương-5:-kết-luận-và-hướng-phát-triển}

## **5.1. Kết quả đạt được** {#5.1.-kết-quả-đạt-được}

Sau 10 sprint phát triển liên tục theo quy trình Scrum, nhóm đã hoàn thiện sản phẩm KidFun, một **ứng dụng di động Android** kiểm soát thời gian sử dụng thiết bị thông minh dành cho trẻ em — với đầy đủ các thành phần và tính năng đề ra ban đầu.

### *5.1.1. Về sản phẩm* {#5.1.1.-về-sản-phẩm}

**Một ứng dụng Android duy nhất** (\`com.kidfun.mobile\`) chạy được trên thiết bị Android 8.0 trở lên, hỗ trợ hai chế độ:  
\- **Parent mode:** Phụ huynh quản lý và giám sát từ điện thoại của mình.  
\- **Child mode:** Trẻ em sử dụng trên điện thoại cá nhân với các giới hạn được phụ huynh cấu hình.

**Backend API server** triển khai trên **Railway** (auto-deploy từ GitHub), kết hợp PostgreSQL trên Supabase — hoạt động ổn định trong suốt quá trình demo và bảo vệ, uptime \~99%. Có bản triển khai dự phòng trên Oracle Cloud VM (ARM Always Free) sẵn sàng kích hoạt khi có sự cố.

### *5.1.2. Về chức năng* {#5.1.2.-về-chức-năng}

Hệ thống đã triển khai thành công **20 nhóm chức năng** chính, phân bổ qua 10 sprint:

| Sprint | Nhóm chức năng | Mức độ hoàn thành |
| ----- | ----- | ----- |
| 1 | Khởi tạo dự án \+ deploy backend cloud \+ Flutter project chạy được trên Android | 100% |
| 2 | Auth (Email \+ Google Sign-In \+ quên mật khẩu OTP) \+ Quản lý hồ sơ con | 100% |
| 3 | Quản lý thiết bị \+ Liên kết qua QR Code \+ Socket.IO real-time | 100% |
| 4 | Giới hạn thời gian theo ngày \+ Soft Warning 30/15/5 phút \+ Xin thêm giờ ★ | 100% |
| 5 | Native Android (UsageStats, AccessibilityService, DevicePolicyManager, ForegroundService) \+ Lock Screen Kiosk Mode | 100% |
| 6 | Demo giữa kỳ — toàn bộ luồng end-to-end hoạt động trên 2 thiết bị thật | 100% |
| 7 | GPS Tracking \+ Mapbox \+ Geofencing \+ Cảnh báo SOS khẩn cấp với ghi âm | 100% |
| 8 | Web Filtering (VpnService chặn domain) \+ School Mode \+ Per-app Time Limit | 100% |
| 9 | Báo cáo với fl\_chart \+ AI Phân tích YouTube (Llama 4 Scout qua Groq \+ OpenRouter) \+ Notification Monitoring | 100% |
| 10 | Polish UI/UX \+ Fix bug \+ Build APK release đã ký \+ Báo cáo | 100% |

**Tổng kết:** 10/10 sprint hoàn thành, **100% chức năng theo kế hoạch**.

### *5.1.3. Về kiến trúc và kỹ thuật* {#5.1.3.-về-kiến-trúc-và-kỹ-thuật}

\- **Mobile (Flutter \+ Kotlin):** Hơn 50 màn hình Flutter chia theo features-first architecture (\`lib/features/auth/\`, \`lib/features/device/\`, \`lib/features/location/\`, ...). 10+ class Kotlin native triển khai các API đặc quyền Android. Giao tiếp Flutter ↔ Kotlin qua MethodChannel với 4 namespace channels.  
\- **Backend:** REST API với hơn 60 endpoint, kiến trúc MVC chuẩn (controllers/routes/middleware/services). Xác thực JWT, rate limiting, error handling nhất quán. Test coverage \~90%.  
\- **Real-time:** Socket.IO xử lý giao tiếp Parent ↔ Child với độ trễ trung bình \< 200ms qua Internet.  
\- **Database:** Schema PostgreSQL hơn 30 bảng được thiết kế chuẩn 3NF, có index tối ưu cho query phổ biến.  
\- **Push notification:** FCM Admin SDK gửi notification ưu tiên cao cho các sự kiện quan trọng (SOS, xin thêm giờ, cảnh báo AI).

### *5.1.4. Về kiểm thử* {#5.1.4.-về-kiểm-thử}

\- **99/100 test case PASS** (98.9%): 59 unit test backend, 10 integration test API, 30 manual end-to-end test trên 2 thiết bị Android thật khác hãng.  
\- App đã kiểm thử trên vivo iQOO Neo9 series và Xiaomi Mi 11 chạy Android 10–14.  
\- Build APK release đã ký bằng keystore, có thể cài đặt trực tiếp trên thiết bị Android.

### *5.1.5. Về quy trình phát triển* {#5.1.5.-về-quy-trình-phát-triển}

\- Hoàn thành 10 sprint theo kế hoạch Scrum đề ra, không sprint nào trễ quá 3 ngày.  
\- Hơn **260 Pull Request** đã được tạo và merge trên GitHub, mỗi PR đều có code review và CI test pass trước khi merge.  
\- Commit history đầy đủ, message theo chuẩn Conventional Commits.  
\- Phân công công việc rõ ràng: Khanh phụ trách backend \+ cloud deployment; thành viên còn lại phụ trách mobile Flutter \+ Kotlin native.

## **5.2. Hạn chế của đồ án** {#5.2.-hạn-chế-của-đồ-án}

Dù đã hoàn thành đầy đủ mục tiêu, sản phẩm vẫn còn một số hạn chế cần thừa nhận trung thực:  
**1\. Phụ thuộc vào quyền đặc biệt Android:**  
Để hoạt động đầy đủ, ứng dụng yêu cầu cấp 5+ quyền đặc biệt (UsageStats Access, Accessibility, Device Admin, Display over other apps, VPN). Quy trình cấp quyền phức tạp với người dùng không rành kỹ thuật. Một số nhà sản xuất Trung Quốc (Xiaomi HyperOS, vivo OriginOS, OPPO ColorOS) còn có cơ chế kill background app riêng — KidFun cần được người dùng thêm vào whitelist Battery Optimization.

**2\. Chỉ hỗ trợ Android, chưa có iOS:**  
iOS có chính sách bảo mật chặt chẽ hơn, không cung cấp API tương đương UsageStats và AccessibilityService cho app bên thứ ba. Triển khai tương tự trên iOS đòi hỏi sử dụng \`FamilyControls\` \+ \`ManagedSettings\` framework (Apple Screen Time API) — nằm ngoài phạm vi đồ án cơ sở này.

**3\. Độ chính xác giám sát YouTube còn hạn chế:**  
Phương pháp đọc tiêu đề video qua AccessibilityService phụ thuộc vào cấu trúc UI của app YouTube. Khi YouTube cập nhật giao diện (đổi resource-id, đổi cấu trúc node tree), cây accessibility node thay đổi và có thể gây mất chức năng giám sát cho đến khi KidFun được cập nhật. AI chỉ phân tích metadata (tiêu đề \+ tên kênh), không xem nội dung video thực tế → có thể có false positive/false negative.

**4\. Chưa kiểm thử tải (Load Testing):**  
Hệ thống chưa kiểm thử với số lượng lớn concurrent users. Backend trên Railway gói miễn phí chỉ đủ cho vài chục gia đình demo. Khi mở rộng cần nâng cấp gói Railway, tăng số instance, hoặc chuyển hẳn sang hạ tầng tự quản như Oracle Cloud VM với load balancer.  
**5\. Tiêu thụ pin cao trên một số thiết bị:**  
ForegroundService chạy liên tục 24/7 \+ GPS tracking \+ Socket.IO keepalive có thể tiêu thụ 5–8% pin mỗi giờ trên các thiết bị cũ. Cần tối ưu thêm bằng cách giảm tần suất GPS sampling khi thiết bị đứng yên.

**6\. Chưa có tính năng giáo dục cho trẻ em:**  
App Child hiện chỉ hiển thị thời gian còn lại mà chưa có màn hình "Nhìn lại tuần qua" để trẻ tự thấy hành vi sử dụng — một tính năng giáo dục quan trọng giúp trẻ tự ý thức.

**7\. Chế độ Parent chưa có tính năng đa người lớn:**  
Hiện tại chỉ một tài khoản phụ huynh quản lý một gia đình. Cha và mẹ phải dùng chung tài khoản, gây bất tiện khi cả hai đều muốn nhận thông báo và phê duyệt yêu cầu thêm giờ riêng.

## **5.3. Hướng phát triển trong tương lai** {#5.3.-hướng-phát-triển-trong-tương-lai}

Dựa trên nền tảng đã xây dựng, nhóm đề xuất các hướng phát triển cho phiên bản tiếp theo:  
**1\. Hỗ trợ iOS:**  
Phát triển phiên bản iOS sử dụng Apple Screen Time API (\`FamilyControls\`, \`ManagedSettings\`, \`DeviceActivity\`) — phần Flutter UI có thể tái sử dụng phần lớn, chỉ cần viết lại phần native bằng Swift.

**2\. AI phân tích nội dung video thực tế:**  
Nâng cấp lên các mô hình multimodal hỗ trợ vision (Llama 4 Maverick, GPT-4o, Gemini 1.5 Pro) hoặc dùng **Google Video Intelligence API** để phân tích trực tiếp frame video chứ không chỉ tiêu đề, cải thiện độ chính xác phân loại lên \> 90%.

**3\. Gamification và giáo dục:**  
Hệ thống điểm thưởng: trẻ được cộng điểm khi tự nguyện tắt thiết bị đúng giờ, dùng app học tập, không vi phạm. Điểm đổi thành thêm giờ cuối tuần. Thêm màn hình "Báo cáo tuần của con" trong Child mode.

**4\. Đa người lớn cho một gia đình:**  
Thêm khái niệm "Family Group" cho phép nhiều tài khoản phụ huynh (bố, mẹ, ông, bà) cùng quản lý chung các hồ sơ con, mỗi người nhận thông báo riêng theo cài đặt.

**5\. Tối ưu cho các hãng Android:**  
Phát hiện thiết bị Xiaomi/vivo/OPPO → hiển thị wizard hướng dẫn cấu hình Battery Optimization và Auto-start riêng cho từng hãng.

**6\. Mô hình SaaS thương mại:**  
Chuyển từ demo sang sản phẩm có gói miễn phí (1 hồ sơ, 1 thiết bị) và gói premium (không giới hạn, báo cáo nâng cao, AI sâu hơn). Tích hợp cổng thanh toán Việt Nam (ZaloPay, MoMo, VNPay).

**7\. Mở rộng giám sát:**  
Thêm tính năng giám sát Call/SMS, danh bạ, app nhắn tin (Zalo, Messenger) để phát hiện sớm bắt nạt qua mạng hoặc người lạ tiếp cận trẻ.

**8\. Tích hợp wearable:**  
Hỗ trợ kết nối với Apple Watch / smartwatch Android Wear để trẻ có thể kích hoạt SOS từ đồng hồ thông minh.

## **5.4. Nhận xét tổng kết** {#5.4.-nhận-xét-tổng-kết}

Đồ án KidFun là một dự án mobile có quy mô lớn so với mặt bằng đồ án cơ sở — bao gồm một ứng dụng Android phức tạp (Flutter \+ Kotlin native với 10+ API đặc quyền), backend Node.js với hơn 30 bảng dữ liệu, hạ tầng cloud, real-time communication, push notification và tích hợp AI. Tuy nhiên, nhờ áp dụng quy trình Agile/Scrum nghiêm túc, phân chia công việc rõ ràng giữa backend và mobile, duy trì nhịp độ phát triển đều đặn và sử dụng GitHub PR workflow hiệu quả, nhóm đã hoàn thành toàn bộ 10 sprint theo đúng kế hoạch.

Quá trình thực hiện đồ án đã giúp nhóm tích lũy được kinh nghiệm thực tế quý giá trong:  
\- Phát triển ứng dụng di động đa nền tảng với Flutter và xử lý các API đặc quyền Android bằng Kotlin native.  
\- Thiết kế kiến trúc hệ thống client–server có giao tiếp real-time qua Socket.IO.  
\- Xây dựng REST API quy mô vừa và tích hợp dịch vụ đám mây (Railway, Supabase, Firebase, Mapbox).  
\- Quản lý cơ sở dữ liệu quan hệ phức tạp với Prisma ORM.  
\- Tích hợp AI vào sản phẩm thực tế thông qua mô hình mã nguồn mở Llama 4 Scout (Meta) gọi qua Groq Cloud và OpenRouter với cơ chế fallback.  
\- Làm việc nhóm chuyên nghiệp với Git, Pull Request và code review.

Những kỹ năng này sẽ là nền tảng vững chắc cho các dự án mobile lớn hơn trong tương lai cũng như cho công việc thực tế sau khi tốt nghiệp.

# **TÀI LIỆU THAM KHẢO** {#tài-liệu-tham-khảo}

Tài liệu kỹ thuật chính thức

**Mobile (Flutter \+ Android)**

\[1\] Flutter Team — Google. (2024). Flutter Documentation. [https://docs.flutter.dev](https://docs.flutter.dev) 

\[2\] Dart Team — Google. (2024). Dart Programming Language. [https://dart.dev/guides](https://dart.dev/guides) 

\[3\] Rousselet, R. (2024). Riverpod — Reactive State Management for Flutter. [https://riverpod.dev](https://riverpod.dev) 

\[4\] Flutter Team — Google. (2024). go\_router Package Documentation. [https://pub.dev/packages/go\_router](https://pub.dev/packages/go_router) 

\[5\] Akimov, W. (2024). Dio HTTP Client for Dart. [https://pub.dev/packages/dio](https://pub.dev/packages/dio) 

\[6\] Flutter Community. (2024). flutter\_secure\_storage Package. [https://pub.dev/packages/flutter\_secure\_storage](https://pub.dev/packages/flutter_secure_storage) 

\[7\] FirebaseExtended Team. (2024). FlutterFire — Firebase plugins for Flutter. [https://firebase.flutter.dev](https://firebase.flutter.dev) 

\[8\] Mapbox. (2024). Mapbox Maps SDK for Flutter. [https://docs.mapbox.com/flutter/maps/](https://docs.mapbox.com/flutter/maps/) 

\[9\] Imaiimad. (2024). fl\_chart — A powerful Flutter chart library. [https://pub.dev/packages/fl\_chart](https://pub.dev/packages/fl_chart) 

\[10\] Flutter Community. (2024). qr\_flutter — QR code generator. [https://pub.dev/packages/qr\_flutter](https://pub.dev/packages/qr_flutter) 

\[11\] Julian Steenbakker. (2024). mobile\_scanner — Camera-based QR/Barcode scanner. [https://pub.dev/packages/mobile\_scanner](https://pub.dev/packages/mobile_scanner) 

\[12\] Baseflow. (2024). geolocator — Geolocation plugin for Flutter. [https://pub.dev/packages/geolocator](https://pub.dev/packages/geolocator) 

\[13\] Baseflow. (2024). permission\_handler — Runtime permission handling. [https://pub.dev/packages/permission\_handler](https://pub.dev/packages/permission_handler) 

**Android Native APIs**

\[14\] Android Developers. (2024). UsageStatsManager API Reference. [https://developer.android.com/reference/android/app/usage/UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager) 

\[15\] Android Developers. (2024). AccessibilityService — Build accessibility services. [https://developer.android.com/guide/topics/ui/accessibility/service](https://developer.android.com/guide/topics/ui/accessibility/service) 

\[16\] Android Developers. (2024). Device Administration. [https://developer.android.com/guide/topics/admin/device-admin](https://developer.android.com/guide/topics/admin/device-admin) 

\[17\] Android Developers. (2024). Foreground Services. [https://developer.android.com/develop/background-work/services/foreground-services](https://developer.android.com/develop/background-work/services/foreground-services) 

\[18\] Android Developers. (2024). VpnService API Reference. [https://developer.android.com/reference/android/net/VpnService](https://developer.android.com/reference/android/net/VpnService) 

\[19\] Android Developers. (2024). NotificationListenerService. [https://developer.android.com/reference/android/service/notification/NotificationListenerService](https://developer.android.com/reference/android/service/notification/NotificationListenerService) 

\[20\] JetBrains. (2024). Kotlin Programming Language Documentation. [https://kotlinlang.org/docs/home.html](https://kotlinlang.org/docs/home.html) 

**Backend**

\[21\] Node.js Foundation. (2024). Node.js v20 LTS Documentation. [https://nodejs.org/docs/latest-v20.x/api/](https://nodejs.org/docs/latest-v20.x/api/) 

\[22\] OpenJS Foundation. (2024). Express.js 4.x API Reference. [https://expressjs.com/en/4x/api.html](https://expressjs.com/en/4x/api.html) 

\[23\] Prisma. (2024). Prisma ORM Documentation. [https://www.prisma.io/docs](https://www.prisma.io/docs) 

\[24\] PostgreSQL Global Development Group. (2024). PostgreSQL 15 Documentation. [https://www.postgresql.org/docs/15/](https://www.postgresql.org/docs/15/) 

\[25\] Socket.IO. (2024). Socket.IO v4 Documentation. [https://socket.io/docs/v4/](https://socket.io/docs/v4/) 

\[26\] Auth0. (2023). JSON Web Tokens — Introduction. [https://jwt.io/introduction](https://jwt.io/introduction) 

\[27\] Google. (2024). Firebase Cloud Messaging — Admin SDK. [https://firebase.google.com/docs/cloud-messaging/server](https://firebase.google.com/docs/cloud-messaging/server) 

\[28\] Supabase. (2024). Supabase Documentation. [https://supabase.com/docs](https://supabase.com/docs) 

\[29\] Railway. (2024). Railway Documentation — Deploy from GitHub. [https://docs.railway.app](https://docs.railway.app) 

\[30\] Oracle. (2024). Oracle Cloud Infrastructure — Always Free Resources (sử dụng cho bản triển khai dự phòng). [https://www.oracle.com/cloud/free/](https://www.oracle.com/cloud/free/) 

**AI**

\[31\] Meta AI. (2024). Llama 4 — Multimodal Mixture-of-Experts Models. [https://ai.meta.com/blog/llama-4-multimodal-intelligence/](https://ai.meta.com/blog/llama-4-multimodal-intelligence/) 

\[32\] Groq. (2024). Groq Cloud API Documentation — LPU Inference Engine. [https://console.groq.com/docs](https://console.groq.com/docs) 

\[33\] OpenRouter. (2024). OpenRouter — Unified API for Large Language Models. [https://openrouter.ai/docs](https://openrouter.ai/docs) 

**Sách và giáo trình**

\[34\] Pressman, R. S., & Maxim, B. R. (2019). Software Engineering: A Practitioner's Approach (9th ed.). McGraw-Hill Education.

\[35\] Phillips, B., Stewart, C., Hardy, B., & Marsicano, K. (2017). Android Programming: The Big Nerd Ranch Guide (4th ed.). Big Nerd Ranch.

\[36\] Napoli, M. L. (2020). Beginning Flutter: A Hands On Guide to App Development. Wrox Press.

\[37\] Kleppmann, M. (2017). Designing Data-Intensive Applications. O'Reilly Media.

\[38\] Rubin, K. S. (2012). Essential Scrum: A Practical Guide to the Most Popular Agile Process. Addison-Wesley Professional.

**Bài báo và nghiên cứu**

\[39\] Twenge, J. M., & Campbell, W. K. (2019). Associations between screen time and lower psychological well-being among children and adolescents: Evidence from a population-based study. Preventive Medicine Reports, 12, 271–283. [https://doi.org/10.1016/j.pmedr.2018.10.003](https://doi.org/10.1016/j.pmedr.2018.10.003) 

\[40\] Radesky, J. S., & Christakis, D. A. (2016). Increased screen time: Implications for early childhood development and behavior. \*Pediatric Clinics of North America, 63(5), 827–839. [https://doi.org/10.1016/j.pcl.2016.06.006](https://doi.org/10.1016/j.pcl.2016.06.006) 

\[41\] World Health Organization. (2019). Guidelines on physical activity, sedentary behaviour and sleep for children under 5 years of age. WHO.

\[42\] UNICEF. (2022). Báo cáo Trẻ em Việt Nam và Môi trường Kỹ thuật số. UNICEF Việt Nam.

**Nguồn trực tuyến**

\[43\] OWASP Foundation. (2023). OWASP Mobile Top Ten. [https://owasp.org/www-project-mobile-top-10/](https://owasp.org/www-project-mobile-top-10/) 

\[44\] Conventional Commits. (2022). Conventional Commits Specification v1.0.0. [https://www.conventionalcommits.org/](https://www.conventionalcommits.org/) 

\[45\] Agile Alliance. (2023). Agile Manifesto. [https://agilemanifesto.org/](https://agilemanifesto.org/) 

\[46\] GitHub. (2024). GitHub Flow — Understanding the GitHub flow. [https://guides.github.com/introduction/flow/](https://guides.github.com/introduction/flow/) 

\[47\] Material Design 3\. (2024). Material Design Guidelines. [https://m3.material.io](https://m3.material.io) 

# **PHỤ LỤC** {#phụ-lục}

Phụ lục A: Bảng phân công công việc nhóm

| Sprint | Nội dung | Thành viên | Tuần |
| :---- | :---- | :---- | :---- |
| Sprint 1 | Backend: Setup repo, migration sang PostgreSQL, deploy Railway (auto từ GitHub) \+ cấu hình bản dự phòng trên Oracle Cloud VM, setup Firebase, viết API contract | Cao Duy Quốc Khánh | 1 |
| Sprint 1 | Mobile: Cài Flutter SDK \+ Android Studio, tạo project, setup Riverpod/Dio/go\_router, build Splash \+ Onboarding, chạy thử trên Android thật | Đinh Bùi Tuấn Anh | 1 |
| Sprint 2 | Backend: Refactor Auth API trên PostgreSQL, refresh token, FCM token registration | Cao Duy Quốc Khánh | 2 |
| Sprint 2 | Mobile: Màn hình Login/Register/Forgot Password, AuthProvider, CRUD hồ sơ con, tích hợp FCM | Đinh Bùi Tuấn Anh | 2 |
| Sprint 3 | Backend: Device API \+ QR pairing, Socket.IO setup trên Railway (WebSocket support sẵn) | Cao Duy Quốc Khánh | 3 |
| Sprint 3 | Mobile: Parent màn hình Device List \+ tạo QR, Child màn hình quét QR (mobile\_scanner) \+ Child Dashboard, Socket.IO client | Đinh Bùi Tuấn Anh | 3 |
| Sprint 4 | Backend: TimeLimit API, Socket.IO timeUpdate/policyUpdate event, bonus minutes API, usage session API, FCM push xin thêm giờ | Cao Duy Quốc Khánh | 4 |
| Sprint 4 | Mobile: Parent Time Settings (7 ngày), nhận notification xin thêm giờ \+ approve/reject UI, Child countdown timer \+ Soft Warning 30/15/5, xin thêm giờ UI, heartbeat 60s | Đinh Bùi Tuấn Anh | 4 |
| Sprint 5 | Backend: App usage log API, app blocking API, blocked apps sync, gradual reduction logic | Cao Duy Quốc Khánh | 5 |
| Sprint 5 | Mobile (Kotlin native): UsageStatsManager, AccessibilityService, DevicePolicyManager, ForegroundService; Child Lock Screen Kiosk Mode; Parent App Blocking; MethodChannel/EventChannel | Đinh Bùi Tuấn Anh | 5 |
| Sprint 6 | Cả nhóm: Fix toàn bộ bug, test end-to-end Auth → Profile → Device → TimeLimit → Soft Warning → Xin giờ → Lock Screen, polish UI, build APK demo, demo GVHD giữa kỳ | Cả nhóm | 6 |
| Sprint 7 | Backend: Location/Geofence/SOSAlert models \+ APIs, geofence event processing, SOS FCM ưu tiên cao | Cao Duy Quốc Khánh | 7 |
| Sprint 7 | Mobile: Child GPS service (geolocator) chạy nền, nút SOS với ghi âm (record package), Parent Mapbox map real-time, Geofence UI vẽ trên bản đồ, nhận SOS alert | Đinh Bùi Tuấn Anh | 7 |
| Sprint 8 | Backend: AppTimeLimit \+ SchoolSchedule \+ WebCategory APIs, School Mode logic | Cao Duy Quốc Khánh | 8 |
| Sprint 8 | Mobile (Kotlin native): VpnService web filtering; Parent Per-app Limit \+ School Mode \+ Web Filter UI; Child áp dụng per-app limit \+ School Mode activation | Đinh Bùi Tuấn Anh | 8 |
| Sprint 9 | Backend: Report generation engine (cron), Report API, NotificationLog API, AI pipeline (Llama 4 Scout qua Groq \+ OpenRouter fallback), AIAlert API, danger classification | Cao Duy Quốc Khánh | 9 |
| Sprint 9 | Mobile (Kotlin native): NotificationListenerService, YouTubeTracker AccessibilityService; Parent Reports với fl\_chart, Activity History, AI Alerts viewer | Đinh Bùi Tuấn Anh | 9 |
| Sprint 10 | Backend: Fix all bugs, performance optimization (caching, rate limiting), security audit, seed demo data, deploy final | Cao Duy Quốc Khánh | 10 |
| Sprint 10 | Mobile: Fix all UI bugs, UI polish (animation, transition), test trên nhiều thiết bị Android, build APK release đã ký | Đinh Bùi Tuấn Anh | 10 |
| Báo cáo | Viết báo cáo đồ án \+ slide thuyết trình | Cả nhóm | 10–11 |

Tổng thời gian phát triển: 10 sprint × 1 tuần ≈ 10–13 tuần  
Phụ lục B: Danh sách API Endpoint chính

B.1. Authentication (\`/api/auth\`)

| Method | Endpoint | Mô tả | Auth |
| :---- | :---- | :---- | :---- |
| POST | \`/api/auth/register\` | Đăng ký tài khoản | Không |
| POST | \`/api/auth/login\` | Đăng nhập email/password | Không |
| POST | \`/api/auth/google\` | Đăng nhập Google OAuth | Không |
| POST | \`/api/auth/forgot-password\` | Gửi OTP quên mật khẩu | Không |
| POST | \`/api/auth/verify-otp\` | Xác thực OTP | Không |
| POST | \`/api/auth/reset-password\` | Đặt lại mật khẩu | Không |
| POST | \`/api/auth/refresh\` | Refresh JWT token | JWT |
| GET | \`/api/auth/me\` | Lấy thông tin user | JWT |
| PUT | \`/api/auth/profile\` | Cập nhật thông tin cá nhân | JWT |

B.2. FCM Tokens (\`/api/fcm-tokens\`)

| Method | Endpoint | Mô tả | Auth |
| ----- | ----- | ----- | ----- |
| POST | \`/api/fcm-tokens\` | Đăng ký FCM token của thiết bị | JWT |
| DELETE | \`/api/fcm-tokens/:token\` | Xóa token khi logout | JWT |

B.3. Profiles (\`/api/profiles\`)

| Method | Endpoint | Mô tả | Auth |
| ----- | ----- | ----- | ----- |
| GET | \`/api/profiles\` | Danh sách hồ sơ | JWT |
| POST | \`/api/profiles\` | Tạo hồ sơ mới | JWT |
| PUT | \`/api/profiles/:id\` | Cập nhật hồ sơ | JWT |
| DELETE | \`/api/profiles/:id\` | Xóa hồ sơ | JWT |

B.4. Devices (\`/api/devices\`)

| Method | Endpoint | Mô tả | Auth |
| ----- | ----- | ----- | ----- |
| GET | \`/api/devices\` | Danh sách thiết bị của user | JWT |
| POST | \`/api/devices/generate-code\` | Sinh mã liên kết 8 ký tự | JWT |
| POST | \`/api/devices/pairing/generate\` | Sinh QR pairing | JWT |
| POST | \`/api/devices/link\` | Thiết bị Child tự liên kết qua mã | Public |
| POST | \`/api/devices/pairing/complete\` | Hoàn tất QR pairing (Child) | Public |
| DELETE | \`/api/devices/:id\` | Xóa thiết bị | JWT |

B.5. Time Limits \+ Extension

| Method | Endpoint | Mô tả | Auth |
| ----- | ----- | ----- | ----- |
| GET | \`/api/profiles/:id/time-limits\` | Lấy giới hạn 7 ngày | JWT |
| PUT | \`/api/profiles/:id/time-limits\` | Lưu giới hạn (bulk upsert) | JWT |
| POST | \`/api/extension-requests\` | Trẻ gửi yêu cầu thêm giờ | Device |
| GET | \`/api/extension-requests/pending\` | Lấy yêu cầu chờ duyệt | JWT |
| PUT | \`/api/extension-requests/:id/respond\` | Phụ huynh phê duyệt/từ chối | JWT |

B.6. Child API (\`/api/child\`)

| Method | Endpoint | Mô tả | Auth |
| ----- | ----- | ----- | ----- |
| GET | \`/api/child/policy\` | Lấy chính sách hiện tại (TimeLimit, BlockedApp, ...) | Device |
| POST | \`/api/child/heartbeat\` | Gửi heartbeat \+ nhận thời gian còn lại | Device |
| POST | \`/api/child/session/start\` | Bắt đầu phiên sử dụng | Device |
| POST | \`/api/child/session/end\` | Kết thúc phiên | Device |
| POST | \`/api/child/app-usage\` | Gửi batch thống kê app usage | Device |
| POST | \`/api/child/location\` | Gửi tọa độ GPS định kỳ | Device |

B.7. Location \+ Geofence \+ SOS

| Method | Endpoint | Mô tả | Auth |
| ----- | ----- | ----- | ----- |
| GET | \`/api/location/:profileId\` | Lịch sử vị trí trong ngày | JWT |
| GET | \`/api/geofences/:profileId\` | Danh sách geofence | JWT |
| POST | \`/api/geofences\` | Tạo geofence | JWT |
| PUT | \`/api/geofences/:id\` | Sửa geofence | JWT |
| DELETE | \`/api/geofences/:id\` | Xóa geofence | JWT |
| GET | \`/api/geofence-events/:profileId\` | Lịch sử ENTER/EXIT | JWT |
| POST | \`/api/sos\` | Gửi cảnh báo SOS (multipart với audio) | Device |
| GET | \`/api/sos/:profileId\` | Danh sách SOS đã nhận | JWT |
| PUT | \`/api/sos/:id/acknowledge\` | Xác nhận đã xem SOS | JWT |

B.8. Web Filtering \+ School Mode

| Method | Endpoint | Mô tả | Auth |
| ----- | ----- | ----- | ----- |
| GET | \`/api/web-filtering/:profileId\` | Cấu hình web filter | JWT |
| PUT | \`/api/web-filtering/:profileId\` | Cập nhật cấu hình | JWT |
| GET | \`/api/school-schedule/:profileId\` | Lịch chế độ học | JWT |
| PUT | \`/api/school-schedule/:profileId\` | Cập nhật lịch | JWT |

B.9. YouTube \+ AI

| Method | Endpoint | Mô tả | Auth |
| ----- | ----- | ----- | ----- |
| POST | \`/api/youtube/log\` | Child gửi log video đã xem | Device |
| GET | \`/api/youtube/:profileId\` | Lịch sử YouTube | JWT |
| POST | \`/api/youtube/block\` | Chặn video thủ công | JWT |
| GET | \`/api/ai-alerts/:profileId\` | Cảnh báo AI | JWT |
| PUT | \`/api/ai-alerts/:id/read\` | Đánh dấu đã đọc | JWT |

Phụ lục C: Cấu trúc mã nguồn

kidfun-v2/  
├── backend/                                    \# Backend Node.js \+ Express  
│   ├── prisma/  
│   │   ├── schema.prisma                       \# 30+ models  
│   │   └── migrations/                         \# Lịch sử migration  
│   ├── src/  
│   │   ├── server.js                           \# Entry point: Express \+ Socket.IO  
│   │   ├── controllers/                        \# 23 controller files  
│   │   │   ├── authController.js  
│   │   │   ├── profileController.js  
│   │   │   ├── deviceController.js  
│   │   │   ├── childController.js  
│   │   │   ├── timeLimitController.js  
│   │   │   ├── extensionController.js  
│   │   │   ├── locationController.js  
│   │   │   ├── geofenceController.js  
│   │   │   ├── sosController.js  
│   │   │   ├── youtubeController.js  
│   │   │   ├── aiAlertController.js  
│   │   │   ├── schoolScheduleController.js  
│   │   │   ├── webFilteringController.js  
│   │   │   ├── reportController.js  
│   │   │   └── ... (10+ controllers khác)  
│   │   ├── routes/                             \# 12 route files  
│   │   ├── middleware/  
│   │   │   ├── auth.js                         \# JWT authenticate \+ authorizeParent  
│   │   │   └── validation.js                   \# express-validator wrapper  
│   │   └── services/  
│   │       ├── socketService.js                \# Socket.IO event handlers  
│   │       ├── emailService.js                 \# Nodemailer (gửi OTP quên mật khẩu)  
│   │       ├── fcmService.js                   \# Firebase Admin SDK  
│   │       ├── cacheService.js                 \# Cache in-memory (calcRemaining)  
│   │       └── aiService.js                    \# Llama 4 Scout qua Groq \+ OpenRouter fallback  
│   └── tests/                                  \# Jest test files  
└── mobile/                                     \# ★ Flutter mobile app (sản phẩm chính)  
    ├── pubspec.yaml                            \# Dependencies Flutter  
    ├── lib/                                    \# Dart/Flutter code  
    │   ├── main.dart                           \# Entry point  
    │   ├── app.dart                            \# MaterialApp \+ go\_router  
    │   ├── core/  
    │   │   ├── constants/                      \# API URLs, app constants  
    │   │   ├── theme/                          \# Material 3 theme  
    │   │   ├── network/                        \# Dio interceptor  
    │   │   ├── services/                       \# Socket.IO client, FCM, MethodChannel wrappers  
    │   │   └── storage/                        \# flutter\_secure\_storage wrapper  
    │   ├── shared/  
    │   │   ├── models/                         \# Data models (User, Profile, Device, ...)  
    │   │   └── widgets/                        \# Reusable widgets  
    │   └── features/                           \# Features-first architecture  
    │       ├── auth/  
    │       │   ├── screens/                    \# Login, Register, ForgotPassword, ModeSelection  
    │       │   ├── data/                       \# AuthRepository  
    │       │   └── providers/                  \# AuthProvider (Riverpod)  
    │       ├── profile/                        \# CRUD hồ sơ con  
    │       ├── device/                         \# Liên kết thiết bị QR  
    │       ├── time\_limit/                     \# Cài đặt giới hạn \+ xử lý xin thêm giờ  
    │       ├── location/                       \# Mapbox \+ geofence  
    │       ├── youtube/                        \# YouTube log \+ AI alert viewer  
    │       └── reports/                        \# fl\_chart báo cáo  
    └── android/  
        ├── app/  
        │   ├── build.gradle                    \# Build config  
        │   └── src/main/  
        │       ├── AndroidManifest.xml         \# Khai báo permissions \+ services  
        │       └── kotlin/com/kidfun/mobile/  
        │           ├── MainActivity.kt         \# Flutter Activity \+ MethodChannel  
        │           ├── services/  
        │           │   ├── KidFunService.kt              \# ForegroundService chính  
        │           │   ├── AppBlockerService.kt          \# AccessibilityService chặn app  
        │           │   ├── AppLimitChecker.kt            \# Logic giới hạn thời gian  
        │           │   ├── SchoolModeChecker.kt          \# Logic School Mode  
        │           │   └── YouTubeTracker.kt             \# AccessibilityService đọc YouTube  
        │           ├── helpers/  
        │           │   ├── UsageStatsHelper.kt           \# Wrapper UsageStatsManager  
        │           │   └── BlockNotificationHelper.kt    \# Hiển thị toast/notification chặn  
        │           └── receivers/  
        │               ├── BootReceiver.kt               \# Auto-start sau reboot  
        │               └── KidFunDeviceAdminReceiver.kt  \# DevicePolicyManager  
        └── ...

Phụ lục D: Thông tin demo

D.1. Tài khoản demo  
\- Email: \`demo@kidfun.app\`  
\- Mật khẩu: \`KidFunDemo2026@HUTECH\`  
\- Hồ sơ con: Bé An (ID: 30\)  
\- Device code: DEMO-DEVICE-001

D.2. Backend URL  
\- API: \`https://api.kidfun.app\`  
\- Health check: \`GET https://api.kidfun.app/health\`  
\- Socket.IO: \`wss://api.kidfun.app/socket.io\`

D.3. APK release  
\- File: \`mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk\`  
\- Signed với: \`kidfun-release.keystore\`  
\- Min SDK: API 26 (Android 8.0)  
\- Target SDK: API 34 (Android 14\)  
\- Package name: \`com.kidfun.mobile\`

D.4. Hướng dẫn cài đặt thử  
1\. Tải APK về điện thoại Android (≥ 8.0).  
2\. Bật "Cài đặt từ nguồn không xác định" trong Settings.  
3\. Cài APK → mở app KidFun.  
4\. Test mode Parent: Đăng nhập với tài khoản demo → chọn "Tôi là Phụ huynh".  
5\. Test mode Child: Trên thiết bị thứ hai cài cùng APK → chọn "Tôi là Trẻ em" → quét QR từ thiết bị Parent.  
6\. Cấp tất cả quyền theo wizard hướng dẫn (đặc biệt: Usage Access, Accessibility, Device Admin).  


[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAMwAAABCCAIAAACU+q4NAAAbRklEQVR4Xu1dCXgb1Z0fSTO6bVnylcOBdltKrwVKv6UsLUe/Lv223aUtbZcQIIkt2bEtO4QsxwL9dtt+tHy0S4CW0pYmgRBCEifyIctxDkoPyn6hHC0NhNzxbce2JJ+yNMebt/83I41GI8lRDpuE6vf9P0eaefPem//7vf/x3oxC4TzymGNQ2gN55HG+kSdZHnOOPMnymHPkSZbHnCNPsjzmHHmS5THnyJMsjzlHnmR5zDnmimSi9kAef784e5KJGCmfEeJBOBEJIhvFeBrjMYxDGIcliYiYFTGHWYRIAfgrinkS/h3hbEjGgwjAJdT0zkR5zTa6qoWq3kF5/JSnFf7q3H6dp0X+Cqf07lbpa0v8LHyo9tHVfuttP//DQCzGTgP9BDHJ1zw+fMiZZIgDy8UL+MaHNxjdzfrqZqqqRWJPKxF34kOO4g7ogHzuVkNtgKppMnt2bP7zKbB1QN+8kTsXgPLAUYAascBiFIPZi0TQ6ges0txIJmLmKw9Q7p3AKmBGkivV7VRNM10ZIJyrJqSBv0yVj6puYypb9Z52AzFmrQZ3u87jA2PGVPoN5KpOvVsyfjXxeojxIwKn9j7ie53oKA1Uyc366+/X3UDEcMMD7w9NZFMdHKa+cI9cUn/TvdQ1NVhlKaFy/ZcfkM+CUDesVl2aAgHz1A33UTcmGv0nr9yggLHuurX6G5OV5CjUjfcNJ2bR0rU/pW56OL3MLMJcuyajZgAyk35/SqCqtxoaOvTeQFzqOwwN7VbPxgkBA+m4TB4Dwhj9TWtB5FaMNz4gZChFwItRy5fiJeVLsvVHg5xINgTl0q2Rp3Uc1F3jB/KNScXAG3521S+sy1+AG2ZjcEshREZ8BroHhWFswBYyN9RHEaurain47mPXrPlNep1ANXW0p8B06xOgNaqBiKG+40hstuSCavDLJeEDvdqvLhgVceIUEWN9s+qkBkjX2K40ClWRG5Capetb4YjqVI7i75ZIBjXcvm6X3uvPvQYoaagPYJFoUQskDmBsqCe1zSJ0vV/gYGS0xIAxgo4le+Jtl28zHQKOQZ9Vug3EMhfUIieSDWQhGXBr7ba3H2zaPyqpHqwRkIyufBHiMHB9TNUOURQ+veo3n6/95fEotnl2GFY1LVq5JYr5tdsO3rux85o1G9LrhGsz3qTx20+BlmV9wYdD0dOQLKFcP90YUBeEFCRV9a2qk6kQMZBMaVTf0CrZQQJjXatmCHMTFcke70jWnJtAeTGNZDAhr/nBS7RXZb2yCHXPDrqhbYp0IKUShIWUYkDlTPrHRHWxFDPpDbCZC2pxriSz3tVi9vjGidUFcxX4dPUvzZXbwKRxcEl1Cxw2uDscK5pPYlxct4eq2h5kiWXTVTW7vpnZkuVGso5zIll9UlMwHVUnU6ElWXO8Y1BDQw4kU7UiCxibnnMjGfGLqfhe0xsUdCbljvz6urb4Z2+HShXQpU5QiKaKNJLtTj2fRCaSafuTEedEsjDG9qoOc+V24M3n/nODiGMz0xG9pw1cHmGS2w+mGD5AV+iajhgXRXiyaPkzcISp2mP/7pOfv2djep0XAckQtta12eoDIJaEmBtaqMZm9QBAefmUXBKE8bYNZiIZXRfQ1bZqCqsrl4+bG7drAwmRZSRPqhZb/cZeRKgDGnqPxQv/6/caNtMNnVjklDoudJLRVVsh9tet8FFVzVLY3k4t3yZlAH4S2nsgzG/Wk+M7IJ00uf3Gqu3MqgC5BPKAah/jaUqv8yIgWfKvIsQHpY6lX1qXySik42qSgYVLBErphbUXKoAo3uzdpigEboSp7wASQ3aplBElTjcfDdlWJ28ZOP3meLKuC51k167dADQyeVrsK18CA2Zwd+rv2m6o2sa42/SV24FM+pU+pqrTUB3QVe9i3O326p1UzT5X5Q662k+4SFJObZ0XA8kyQCKZegD8orSSkBHZSXYGmBEEw+ompTlg2FvjmZd/OBFbbn9K1beAZe0eJTK70El21Zr1wC26qhXCMvqGxqb9PcZlG+13bmTq9hZ8ZU3gvQHq+vsKbn+29M5fTmOsv/mhwkqf0dNkWbl9mMPWpU9Sq/ak1/mhIZm8XJUR504yqIG6+X4565Rr0NfuVPKSdAh4RtW3ALW6VQnvLnSSLVj6OFW7z7rqWapmp8W99b7N+5jbnqFX+T/5nQcMNW1L/m1Nkdvn/M46qnbHivWvFy173HRXM+VuhhjOumz9RJY6zwvJ5NUBSS4KkgVYbZHTw3B3p9KcbnXLpr/1akuoweNeFvcKuEfA3TzuAWYl1jLSSBYgWVwm8OiDIBkI880niiqbqNpmeuV204qdlqqdulU+uwd8ZYu+coej8gUp8GqxVzYVu7cYq3bolrdT3/0VU7/b5n4pvbYcSUY1dByIYY7Hgkp4gRyBvyDGuouJZNCHqCAFWQIkSQL8q4jyNaqtA9EN8RQShPb6chrtTNCSrHF3lBd54KCgVe8MmqHrkszWzxvJwF1K+5Wt0r6kL7476d5F9gakTSdIAsg+ZjWE/wHpa4CqaYO0IGXn4AxJRtRaB2PTCkcUUU5Jy5IXE8n0ZIXTR9eR4J30TZFkbdpFY7KCmro2NkvfZoeGZKRX0kqH/DlVvX7D/JMMiAIk07t9uqpmomIPZJebC1dustzy02vv37Limd8tf+rlK+uf1d/yqL3yOaZyG1XXRle3UWDPyMalvI+urTNHkuUsFwXJTi8wc9Q1xCAkSCyGyUJ2u84KGpKdkcwhyegqYpkM1U3Orz0YBlcdGxDYX0+OXB8L2vGYkR82iEE9HqNxWI+CFA7qhKAOvnJBQ2y0KHLq6xhtFbnwFNR5092EZ1XxRzbyJJtFNCRjSXKjaq6uLfOOUw64kEhWA87Ob2rY23JsPMr3T4S/zAZNQCYU0ski5iAopIdLpKviwoYM0+E7RMz9+/c3kMeBaptyIhlxlB2UN8V0KyJtqykDcDGQrKEVGqLr/Ybsotn+ghAtZdehcQ/ZIj8raGOy+nbd6iyKbdylq0s5ct5J1obw4ORoOTdu4MMUHqXBRKXTaHYBVuFQWepBCiQ2ocej1MTgoikxliPJ3gGHwUaREEsXAZIgry+hiIuAZNCHSXKU5SHuVwmvEs0jd2C1qMbkfpHBO8s2/2mgIRlduw+zJN9IUywcwUxqpHieSUZXtXAhMx41SrTQsicXCQ1SJ1YUoFEm/ZQiKGiBnEDbvATNEsbhGW0BNZQFpIuCZHBh1qJZwavuMWCo85FKzwpplmx3ttuc83Uy44pd6ZzIUcDmgeV700bxw9pTGgG3y1RmTpTOaJ3sNIuxKjUZvNmewkCigOQkKy6EZFnJcG4kO+PFWICuUTVVvO0nhdliMiDDFx/adO1Dz//zgy+AfPHh9crDoZlIlhkXKMnwqI4Nm8VBFzdJDVkrxKAxvYxa5oFkMJwG7y5FTfGAOmNVQlStUENj2yzDON8kQ9hY75MWa6QavM2ld7drt89ViGKk5gdV105IJt31h4BkdHsFhYcZFKIP24pwyJBeRi3zQDKAoYE8ipioyh9hY6nn4+jiU2we5d2ZeWtQwjyTDGroYlUbGw2tlHePKM5kfHgdelJy+4/V92K6ayMp9+EgGRrUtzsoSCeFIHXSXCIM0SS7TCuWLD8PJBMxpYRZssZvf1Ik/iSlUfCVKU9ieQPGlc9m3m2RcG4k65il5uxA1N17lOYg0NR5fBixGp7B1xDidKtblL5BhBBRPR97cZMMBynx8BIcKgczBnnlwA8/ijuvwbPmDfNAMlB6sff5+MDItTV0lDS8IAgieW1PFASEp0VM1+5RB2R0vX+c5HRZyXBuJAt8tvHnVzY8dTpZd/XqdWSLJ1FJt6BOcYhQ9R3N7w5iiM9EDokxQWSLlj1KeVUMa+goX9uKVEu3FzHJgC5siDlqdLFBih/Vo34dHzJ2G+xTYYqslqWVV66aa5Jhch1nqvNp9m1AfXTjLqkJsiulGbyie7OqXsa5kExuXW53VglYa31q3UCjNHn2Vd1VvxQMkMLwQcMJEF3DXl6Iqq3dhUKyoTMhGeSSwBV87KOD5vKpERMKmrmgieuxQRIQOVg46CyehWR8WEdXxd/X0OA8kgyi/+/vPkCYlP3ReLktsq4Lo+jtwGiWoJ/gTEm2lJBM03rScGYRv2XVTm1dkALXym+1nOZyaY06MINj4mme8d+lPqvG3JJsFGPG3ZbOiXThw3rcckUvU/j2LXpxwvGHQoqdsXFBw57LKLIrENT/uZjC73wm/UJZ0KjBUNmc8V1fFcn88OHw6d5WSigCSLYrvSDC3J/CorG+eZaxISMHPGj4LXtaislGJfV9oYxTRQaxZE92qi1ZbkJIpu2JCJmjWLHmZRh+9aJGulD1zTHMp2cGWpJ5s2ap5OU5VWdAzueLJOStkPpt6ZzQiDCg66GLRf/lOGyEOCwSot/4FoW7S4SgoctSjMJkcV8MWXppRzZjBiRjqnza5iVYbnvcVLeLqSdiqm8/PJl1EEGL1rp2uSRT32H27kx/D4xAJO94Vaz4DeNtV+9QEfNGbAx4zFe2HBjBYk7PeoHdYrwtiUZBdmsHMxXLnthnTtwOdFIlykHtcbhrS21zxoe9YFpOC6J8I4n+E2MM84Su6zB5m33vj03xKKPKZrCgbhf8b0z1BoAanMCa796TKLwbZEJbJDNyIhkEMZRnDx4Bl0enM0MWsGGHFtrwm1fGxi14RB/tce0vJLtP7ICVsOexT+GgBUiGw/QpU3k2koWHnfQqf/psm1MgkWVFDvTVxeP3I5goDsV46bi26IUNsKYCeSaNC2J8aBJ3x0jOLOIZ6Z3eDPSaN+REMtC4boXv9wd+wBJrpGVGXMLMqHEJClJQ5sRq2+iDS/AIw4doEDiL//RFHLJCvikEdT3momwku+1H37G7d6pzn/mCFFxIy5PxtueV5+cT8o0k+q8ETRc8yQDX3f0MtbIJj2lpoQg+ubjL4oQPr97K4N3X4VPJU8CzIw5GeviCxq99Hp/6RMbVMkgRjLW+IeLZPkiN5HHekSvJMM9TnpaxiW9n2xrCIedxqoid0oVNC1M4FNTjN67AkYL9l9lx3yW45SounMnnQrGRUr1nh/qNLjViJO6BXCovF5BgYdbnFBLIlWRgda9cs97i9fPjGYyQKD3GM2h04mDZcaYET6R4VRwywNmjxWVSQpDh4TMc1LNBM1O5dW+fdsFaQQTjEUTklJiUEdVn5Yj6oOZrxuMZC+R4PJcyyldNoxmvTb8wvVh6GU2B9OPqdrOVyXg8YwfIcWksMq4DpCNXkmHym0S8vnb3pz3fEsIZHtcB6vDjtqnCy8RhevS5RSQUA/8YpoBA3BDzl3+hulaVC5NUBkMYpHHYep3nK8bazgvfUWaeAX8HyHLjOY1XziQj9ZEfhaFq2/e9899olDi4dLpww8ZjrkVHHIZAIdmyBBuGe4qOFhftvpwSxgzo+X9EaSRjQ4b1+xopj5xUZu00ebsfAnMicWhLSJBD3pQV7Sz+N3dAbSjRLMxdpXJEqs7ak3NHtttU90FGvHMqQMdmv3GB7KOlaEn+Ko2BfIJcHj8o3bhSWIbckOZgRpwByWTEBERXt33zf+7CUtqoEQjtd1spvO9z+Pmr33ZRfZZFx40uNLRAHGKOF5Tz4SQviZEb0aFh6srqO6hVL0mZXabVLAWRcK/F1WN29jJlB2wuPDmcjZFQhkfJByv6zSXZpmEuIHoc6jpiLBg0lJxgXBuWfJxnyTISqfK9Az2MI8al7NKcR2w3OVjy66hJQEM85o4zpW8uX5GyZDrS02N1dZtc/WZQUTHIYcbO81n1KRK1uJIr/whvMlnx1DC5EZ5/t+TjcLbbWNZvXyygKCktTA6a7OoaoOqT1gUwKOqD2XDGJCObEiJH3dEEmSAE++n2jAtRaLKAHS6YCFLsuPTEYth6TOfsKCCuU0VHHT9ZYKjcaqreFsmujiSiIZ/ZyZHRRHCLb1mLD6/1kuOJ8ZU1xgksHg/BLI0fxajPWC6VSfm9QYFcl1zHlxbESB/S1k4Q7j464FgcY4nRgmHbdumnDt7zAPndNW7sRYNDEPlDFZeLQnwFBEs1KJVI00Z+voP8BIrSPhk10p5012p+kjKEOlINqMXswjFWrkGegXB3x5wFURF3FC7CIyPJChGphxP4HkuZvGtEFsx4qXKRJ38SJRXA3FObupdoC54eg2uHiv8Bz4yJiDzwzYp4kLKN8xHMcX2mYjwclm8C+hN++ql+phxPjCRrzI4zJpkMUOtLh0d1ni0VS+/EY0aymh9MGjYctO+/icLHPod3XjVoc44C5QPXvu+0EMIFdVxYPzNMXXdvNePevv617nQ7nAkIx6Z3Gctl7cONIl4YoEo4GA40Q+Yu4wi5FhCPLuKTFjL28mUsRl2msj98+V+HTcUnyVzkJL3jI6XlY5ayE7aSickglpbHXi10hqCMo3Rc/XgZaNlcOpnqVt4zl0RENM6PDhscYdr5R5eDjKjID+gtOwoXgh0dYBwQE8PIs/xMn33xqKlk101fOGkqVIYa/n3LVAT0HdIV9FF2HB4GDk0Isb85yt+3OY6Vuo7aFvOIawEbPD3SzVhgOMVdvyUdR/wmg/U47YR74dhpjSkHBpy0lShfOy//DGZDQ8aSCcb5zJJLJCYmL+i3OFW/7cNvge5Nj0eFyBFriUBSeQLQds/3HkKvdAB/J3/+dD8kdok50F24+DmDBU8FEzXMhrMkmTRUCLGc+T/W0Stb7nhsKZbeXJJIRlLLiXF9cwE1aK+IBk14hEEj5gHDYhykICFoP3Gfwb219M5NWJRMcQ4QwP0NHW/SW3A0hmMzbAQyZwQmHaZ5r9URY3lWjOHjhyd+8Cji8RBTTMY4gT7GhfuOQ9YC3Oy1OIGdJ0wOYXoSgpLpWDRkdoAJ+Kt9ET72bkRkQb0DdJmQWOoXWdRlLhI0g0n6jA7bijiJc3hs8khBGXiZbnM5zAQWiUIs8jpFxiNEOSG6IDbo+JFuc3HyXkX8N6tjy8cu5yRz2m0uFXj2UPGleHRYMnDCCWsRdLjd6DpZehk0zk7H+nUlUcz/5dal77trOAxelOs2OTRBl4ZkL1921UhBBdSGouyGSy4VX9ysduu9lhK8O4A79xDZ3fkq2PvIOO7sPPrDR5QyEiQjzQnRp/63lykhHoC41FhvYcUOughPzinJEiBa4lny6yk12361rw4PxxcvgHBc2DikL0NBcmRymhoxXnp53dfNNQHTXc3E5Z7Je4LkPoe6dzodmJvC7NQk4RD4QQcMH8vHiC9CE6/c/NUtZpvI8X0m2asSQLl+U5nsg4B/fQyMAd9lL1V816GCxYgXB5gimUhkZ4aPKu8w8qwwaE0OG5YGkufBrE697FwUr4LHYVM5qL6HLlVMxUlzEeZm3jLb5SMxzPWYFiiVAIBkM3IfEB4Au8WzxB+ReJ3E5AcNRWC0Ws0uDk2TrsD0sC0CuowanMLMDLkTzDcxduk3yJLQkuxjV+LRgXgYIPInKCuvmi1k7nETYOqIxMaaGGLJJh99BL+6X23w4L7I4yRRXlz3Mzwy/BxlBSf2ussJk2oTY8Pj80IyGZJmps3L1lvu3PZ008OstJWJQvpdLgof+cxMsHDhN75KVfmorz1GbJLGMOSIaAhilORcFCHAL54RhFFb2ZvOCvzXt/FYhJCMRX3mIoVk0NaAeWH8E8I9plIkxI5ZXIqP3mYvYkWu11gk/3gx2cfEk8rQCRwasJIAWakPPgyYnXii5/CaRpmJYDUh6AaTRipJoMsEXRUOOipkhyQSy7FIOQs4YC2QPDdJ5ICdYEQHwRDKvULcseIlQDK/yQUTWC5/wlgK1O9iSofq1g6saei7Z/VI7RqMIqoqtSTr+NQVmI8vlkKQ2kslu4elmEw9z+WYDHPTr1lcKZu2r/1u//IqzAr48SenpmO9tBOs2igQVJh3kimASMK09Bc6j2/RLd/gQ8ZoyPkRzzqDu9P0rR+fawoWC+20OshcRJKhef13xxdUQPRwzLhIkJ5M4DoDz0FgwRPy8Ql3CZ6un4mPLkxB8FngAvsNQDVpYqDokLUYLFN4wcdJ8E/WRwQIwtjENIAyP7MW/dThkv0vBzas6/BzdkdM4CFxxlK8zyJ8kiYFeo0u+SpAt8XJi9FufQH0B8ZsErHdpiTJRIlkcXUgsUcPLULMvgC0JwCvgbXmhdDbFouD4+Lh0QljGcyzg4WlsekJMC3Qm0PFSyLctFInqQlIZi1Tvu7+5BVbwKPJuQfPvWEr5oC5SOAkCsHEUEfDhGSTE2SqmMuIm5A88Qzmuw2uKLQW44UnfgY5+2YweL2HDt17P8yH55mCeXKXaZB3ZBH9tR9R7mbG0+R5eq9kus7KeqkxM3acKXjZ6Dhoh0S95M9MMegihnBfQTneE/hjfV2LjjkE6RiL+o3F0v8IIEFEPdYKuXVIvuBCcEx43ytHihbgvq5jjsU/MRcQhzI+MGApxccOvWcrfdqxKJnrkiUj8d2CineLP8K/uLnZUHjCVsaSrBTBPH7dsgAPnxyFC/u7oEXigBIAd0nsxDtvDhctOGQvGjOVQgilnJVJFt+7RiIMJHyMRCe7TOYDegdYyrfBIImcz1SgPPnYR5cTprCRXosLd723uXTxcdslSQMrAUgDsYGQeDcOSNZssu370vX4//7YV7SQmFxMAlbyxAkYdatTUFms7ZAVTZPjEP6cMi3suPrqyY2/PmFdGH7kJ6S6CBt54kn4NxqNHNW5QJOg2E3GQjw1qtQwC847yeKQbp8kz+eBXhLk0ITsZBAXI5DsTbL2IlFLDPd2SysCsp8kxkC+inxVRoI8xU88Ek9evkT4/WMimC8pwxKlp/mUCrUgT8xASV5iF4rPI4GTl0Xk8iR2Ub7IvcXo3VuXEUYicQoJ3Sa1tyKDGb9QKgxdf2f5HfABDBgvRIcZshIh3Wm8RmUBhpCurwfiM5JZp0IurFyy9xNXkKBSrQREsm5SQP4fJBK9lQrIARsi3ogomZO0EY9dubhiE6WRrCmkeIzZMVckm0+AGR812pJayAl8n7V0Tp8Yg/4cclQ8ayjEob537c5TTz6TtYci2Wzu/8W6gyYnHu/dQDvfsy1RXLYGUMmw3g6xWrbnVxX89rIrcCyiMOkDxIeBZGTSn0muKoNsCs268XLuADOGJqbwSC8vzJx2ORA6w/ERPNgDOeMshaV0T7utlBEQz82y6D+f+DCQ7IIGkgyV9mhmJL316SmUC7IydZ6RJ1kec448yfKYc+RJlsecI0+yPOYceZLlMefIkyyPOUeeZHnMOfIky2POkSdZHnOO/wcW3kj6VIrjuwAAAABJRU5ErkJggg==>