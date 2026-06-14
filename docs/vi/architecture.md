# Kiến trúc tổng quan (Dành cho người mới bắt đầu)

Tài liệu này giải thích kiến trúc của dự án bằng ngôn ngữ đơn giản. Nếu bạn chưa từng dùng Kubernetes, hãy bắt đầu ở đây.

## Kubernetes là gì? (Giải thích trong 30 giây)

Hãy tưởng tượng bạn đang điều hành một nhà hàng:

- **Source code (app)** của bạn là công thức nấu ăn
- **Một Pod** là một đầu bếp đang nấu món đó
- **Một Deployment** là bếp trưởng — người đảm bảo luôn có đủ đầu bếp
- **Một Service** là phục vụ bàn — người biết mang order đến đầu bếp nào
- **Một Ingress** là cửa chính nhà hàng — tất cả khách đều vào qua đây
- **Một Node** là căn bếp (một máy chủ vật lý hoặc ảo)
- **Cluster** là toàn bộ nhà hàng

Kubernetes (gọi tắt là K8s) là hệ thống quản lý tất cả những thứ trên một cách tự động. Bạn chỉ cần nói "chạy 3 bản sao ứng dụng của tôi", nó sẽ đảm bảo điều đó luôn đúng — kể cả khi một máy chủ bị hỏng.

## Dự Án Này Cung Cấp Gì Cho Bạn?

Đây là một **bản thiết kế có sẵn** để chạy ứng dụng web trên Kubernetes. Thay vì tự mày mò nghiên cứu và cấu hình từng thứ, bạn nhận được:

- Một Kubernetes cluster sẵn sàng cho production trên AWS
- HTTPS tự động qua Let's Encrypt (miễn phí)
- Cơ sở dữ liệu (MySQL, MariaDB, hoặc PostgreSQL — bạn chọn)
- Tự động mở rộng (thêm bản sao khi traffic cao)
- Giám sát trực quan (dashboard + cảnh báo)
- Sao lưu tự động (chụp snapshot hàng ngày)
- Bảo mật (tường lửa, mã hoá secrets)

## Sơ đồ tổng quan

```
                    ┌─────────────────────┐
                    │     INTERNET         │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │   INGRESS-NGINX     │  ← "Cửa chính" (xử lý HTTPS)
                    │   (TLS termination)  │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
    │  REACT SPA   │   │  LARAVEL API │   │  DATABASE    │
    │  (Giao diện) │   │  (Xử lý)     │   │  (PostgreSQL)│
    │  Nginx       │   │  PHP-FPM     │   │  3 bản sao   │
    │  File tĩnh   │   │  + Horizon   │   │              │
    └──────────────┘   └──────────────┘   └──────────────┘
```

## Các Tầng (Từ Dưới Lên Trên)

Giống như xây nhà — bắt đầu từ móng rồi lên mái.

### 1. Tầng Cluster (Móng Nhà + Đất)

**Là gì:** Máy chủ và mạng lưới — nơi mọi thứ chạy trên đó.

**Ví dụ thực tế:** Bạn mua một miếng đất, đổ móng, kéo điện và nước vào.

**Dự án này tạo ra:**
- **VPC**: Một mạng riêng (như khu đất có rào)
- **Subnets**: Các khu vực trong mạng (như sân trước vs sân sau)
- **EC2 instances**: Máy tính thật sự (máy chủ)
- **EKS**: Dịch vụ Kubernetes của Amazon

### 2. Tầng Mạng (Cửa + Khóa)

**Là gì:** Kiểm soát ai được vào ứng dụng của bạn.

**Ví dụ:** Cửa chính, camera an ninh, chuông cửa.

**Thành phần:**
- **Ingress-NGINX**: Cửa chính. Tất cả traffic từ Internet đều vào đây. Nó tự động xử lý mã hoá HTTPS.
- **cert-manager**: Người làm chìa khoá tự động. Lấy chứng chỉ HTTPS miễn phí từ Let's Encrypt.
- **CoreDNS**: Danh bạ nội bộ. Khi một service cần nói chuyện với service khác, nó tra danh bạ ở đây.

### 3. Tầng Lưu trữ (Tủ đựng + Tủ lạnh)

**Là gì:** Nơi ứng dụng lưu file vĩnh viễn.

**Ví dụ:** Kệ đựng nguyên liệu trong bếp.

**Khái niệm quan trọng — PVC (PersistentVolumeClaim):**
PVC giống như một kệ được đặt trước. Ứng dụng nói "tôi cần 10GB", và Kubernetes tự động cấp phát. Dữ liệu vẫn còn ngay cả khi app khởi động lại.

### 4. Tầng Dữ liệu (Database — MySQL/PostgreSQL)

**Là gì:** Nơi dữ liệu có cấu trúc (tài khoản, đơn hàng, bài viết) được lưu.

**Ví dụ:** Tủ hồ sơ có ngăn được dán nhãn.

**Tại sao 3 bản sao?** Database chạy với 3 bản:
- **1 Bản chính (Primary)**: Nơi ghi dữ liệu
- **2 Bản phụ (Replicas)**: Bản sao đồng bộ. Đọc dữ liệu có thể vào đây để chia tải.

Nếu bản chính hỏng, một bản phụ tự động lên làm chính. Đây gọi là **high availability**.

### 5. Tầng Ứng dụng (Nhà hàng thật sự)

**Là gì:** Code của bạn chạy trong container.

**Ví dụ:** Đầu bếp, phục vụ, dụng cụ nhà bếp.

**Thành phần:**
- **Deployment**: Bếp trưởng — đảm bảo luôn có đủ đầu bếp
- **Pod**: Một đầu bếp (một bản sao đang chạy)
- **Service**: Phục vụ bàn — biết đưa order cho đầu bếp nào
- **HPA**: Quản lý — thuê thêm đầu bếp khi đông khách
- **PDB**: Quy tắc "không bao giờ để dưới 2 đầu bếp, kể cả lúc sửa bếp"

### 6. Tầng Bảo mật (Khóa + Bảo vệ + Két sắt)

**Là gì:** Kiểm soát ai được truy cập gì.

**Ví dụ:** Khóa cửa, thẻ bảo vệ, két sắt.

**Thành phần:**
- **Network Policies**: Tường lửa. "Chỉ cửa chính mới được nói chuyện với bếp."
- **RBAC**: Thẻ bảo vệ. "Chỉ quản lý mới vào được phòng làm việc."
- **Sealed Secrets**: Két sắt mã hoá. Bạn có thể lưu mật khẩu trong Git mà không sợ bị đọc.

### 7. Tầng Giám sát (Camera + Dashboard)

**Là gì:** Theo dõi mọi thứ hoạt động có ổn không.

**Ví dụ:** Camera an ninh, đồng hồ đo nhiệt độ, phòng điều khiển.

**Thành phần:**
- **Prometheus**: Thu thập số liệu (CPU, RAM, số lượng request)
- **Grafana**: Hiển thị dashboard đẹp mắt (biểu đồ)
- **Loki**: Lưu log (như cuốn nhật ký có thể tìm kiếm)
- **AlertManager**: Gửi cảnh báo lên Slack hoặc email khi có vấn đề

### 8. Tầng Sao lưu (Bảo hiểm)

**Là gì:** Sao lưu tự động để không mất dữ liệu.

**Ví dụ:** Hợp đồng bảo hiểm với chụp ảnh hiện trường hàng ngày.

**Dự án này tạo ra:**
- **Sao lưu hàng ngày**: 2 giờ sáng, chụp snapshot và lưu lên S3
- **Giữ 30 ngày**: Khôi phục dữ liệu trong vòng 30 ngày
- **Sao lưu tháng**: Giữ 90 ngày

### 9. Tầng GitOps (Quản lý tự động)

**Là gì:** Hệ thống theo dõi Git và tự động áp dụng thay đổi lên cluster.

**Ví dụ:** Quản lý nhà hàng tự động, đọc sách công thức và đảm bảo bếp làm đúng.

## Luồng Request: Ai Đó Truy Cập Website Của Bạn

Khi ai đó gõ `https://myapp.example.com` trên trình duyệt:

```
Bước 1: Trình duyệt tra DNS → tìm IP của Ingress Controller
Bước 2: Trình duyệt kết nối đến Ingress-NGINX (cửa chính)
Bước 3: Ingress kiểm tra đường dẫn:
  - /api/* → chuyển đến Laravel backend
  - /* → chuyển đến React frontend
Bước 4a (Laravel): PHP-FPM xử lý request, nói chuyện với PostgreSQL
Bước 4b (React): Nginx trả file HTML/CSS/JavaScript
Bước 5: Response đi ngược lại đến trình duyệt
```

## Auto Scaling: Xử Lý Khi Lượng Truy Cập Tăng

```
Lượng truy cập tăng đột biến
      │
      ▼
Pod dùng nhiều CPU hơn (>75%)
      │
      ▼
HPA phát hiện CPU cao
      │
      ├─ Thêm Pod (tối đa 20)
      │
      ▼
Nếu cluster đầy, Cluster Autoscaler thêm server (node)
```

## Tóm tắt các tầng

| Tầng | Chức năng | Ví dụ |
|------|-----------|-------|
| Cluster | Máy chủ + mạng | Móng nhà + đất |
| Networking | HTTPS, DNS, định tuyến | Cửa + điện thoại |
| Storage | Ổ cứng cho dữ liệu | Tủ chứa |
| Data | Database | Tủ hồ sơ |
| Application | Code của bạn | Đầu bếp + phục vụ |
| Security | Tường lửa, mật khẩu | Khoá + bảo vệ + két sắt |
| Monitoring | Dashboard, cảnh báo | Camera an ninh |
| Backup | Sao lưu tự động | Bảo hiểm |
| GitOps | Tự động hoá qua Git | Quản lý tự động |
