# Thuật ngữ Kubernetes

Từ điển đơn giản các thuật ngữ dùng trong dự án này.

## A

**ArgoCD** — Công cụ GitOps tự động đồng bộ Git repository với Kubernetes cluster. Thay đổi vào Git trước, ArgoCD tự động áp dụng.

**AWS (Amazon Web Services)** — Nền tảng điện toán đám mây. Dự án này chạy Kubernetes trên AWS dùng EKS.

**AWS CLI** — Công cụ dòng lệnh để điều khiển AWS từ terminal.

## C

**cert-manager** — Công cụ tự động lấy và gia hạn chứng chỉ TLS/SSL cho HTTPS.

**Cluster** — Toàn bộ hệ thống Kubernetes: tất cả máy chủ (nodes), control plane (bộ não), và mọi thứ đang chạy trên đó.

**ClusterIP** — Loại Service mặc định. Nó cấp một IP riêng chỉ hoạt động bên trong cluster.

**ConfigMap** — Lưu dữ liệu cấu hình (cài đặt) mà ứng dụng có thể đọc. Không dùng cho mật khẩu.

**Container** — Một gói nhẹ, độc lập chứa mọi thứ cần thiết để chạy một phần mềm.

**Container Registry** — Nơi lưu trữ container images (như Docker Hub hoặc Amazon ECR).

**CronJob** — Chạy một tác vụ theo lịch trình (ví dụ `* * * * *` mỗi phút).

## D

**DaemonSet** — Đảm bảo một bản sao của pod chạy trên mọi node. Dùng cho log collector hoặc network proxy.

**Deployment** — Tài nguyên Kubernetes quản lý một nhóm pod giống hệt nhau. Xử lý cập nhật, mở rộng, và khởi động lại.

**DNS (Domain Name System)** — "Danh bạ" của internet. Dịch tên miền (như google.com) thành địa chỉ IP.

## E

**EC2 (Elastic Compute Cloud)** — Dịch vụ máy chủ ảo của AWS. Mỗi K8s node là một EC2 instance.

**EFS (Elastic File System)** — Lưu trữ file dùng chung của AWS, nhiều máy chủ có thể truy cập cùng lúc.

**EKS (Elastic Kubernetes Service)** — Dịch vụ Kubernetes của AWS. Nó chạy control plane cho bạn.

**eksctl** — Công cụ dòng lệnh tạo và quản lý EKS clusters.

## G

**Git** — Hệ thống quản lý phiên bản theo dõi thay đổi file. Toàn bộ dự án này được lưu trong Git.

**GitOps** — Cách quản lý hạ tầng nơi Git là nguồn sự thật duy nhất.

**Grafana** — Công cụ dashboard hiển thị metrics (CPU, memory, request rates) dưới dạng biểu đồ.

## H

**Helm** — "Trình quản lý gói" cho Kubernetes. Đóng gói các tài nguyên K8s liên quan vào một chart.

**HPA (Horizontal Pod Autoscaler)** — Tự động tăng/giảm số lượng pod dựa trên CPU/memory.

**HTTPS** — Web traffic được mã hoá. Ổ khoá xanh trên trình duyệt.

## I

**Ingress** — Tài nguyên Kubernetes quản lý truy cập từ bên ngoài vào services, thường là HTTP/HTTPS.

**Ingress Controller** — Phần mềm (như NGINX) thực thi các luật Ingress và xử lý traffic.

## K

**kubectl** (kube-control) — Công cụ dòng lệnh chính để điều khiển Kubernetes cluster.

**Kubernetes (K8s)** — Hệ thống mã nguồn mở tự động hoá triển khai, mở rộng, và quản lý ứng dụng container.

**kustomize** — Công cụ tuỳ chỉnh cấu hình Kubernetes mà không cần sửa file YAML gốc.

## L

**Label** — Cặp key-value gắn vào tài nguyên Kubernetes dùng để chọn lọc và tổ chức.

**Liveness Probe** — Kiểm tra sức khoẻ cho biết container còn sống không. Nếu hỏng, K8s khởi động lại container.

**Load Balancer** — Phân phối traffic đến nhiều server hoặc pod.

**Loki** — Hệ thống tổng hợp log. Thu thập và lưu trữ log từ tất cả container.

## M

**Manifest** — File YAML mô tả tài nguyên Kubernetes (deployment, service, v.v.).

**Memory (RAM)** — Bộ nhớ ngắn hạn của máy tính.

**Metric** — Giá trị đo lường (như % CPU, số request mỗi giây).

**Multi-AZ** — Chạy tài nguyên qua nhiều Availability Zones (trung tâm dữ liệu) để sẵn sàng cao.

## N

**Namespace** — Cluster ảo trong cluster vật lý. Dùng để tổ chức tài nguyên.

**Network Policy** — Luật tường lửa kiểm soát traffic giữa pods, services, và bên ngoài.

**NGINX** — Web server, reverse proxy, load balancer.

**NLB (Network Load Balancer)** — Load balancer của AWS hoạt động ở Layer 4 (TCP/UDP).

**Node** — Máy chủ worker trong Kubernetes. Mỗi node chạy pods.

## P

**PDB (Pod Disruption Budget)** — Luật quy định số pod tối thiểu phải có sẵn trong lúc bảo trì.

**PersistentVolume (PV)** — Một phần lưu trữ trong cluster.

**PersistentVolumeClaim (PVC)** — Yêu cầu lưu trữ từ pod. Giống như nói "tôi cần 10GB ổ cứng."

**Pod** — Đơn vị nhỏ nhất trong Kubernetes. Chứa một hoặc nhiều container.

**Prometheus** — Hệ thống giám sát thu thập và lưu trữ metrics.

**Promtail** — Trình thu thập log gửi từ nodes đến Loki.

## R

**RBAC (Role-Based Access Control)** — Phương pháp kiểm soát truy cập dựa trên vai trò.

**Readiness Probe** — Kiểm tra sức khoẻ cho biết container đã sẵn sàng nhận traffic chưa.

**Replica** — Một bản sao của pod. Nhiều replicas cung cấp dự phòng và xử lý nhiều traffic hơn.

**Rolling Update** — Thay thế dần pod cũ bằng pod mới, đảm bảo không downtime.

## S

**Sealed Secret** — Kubernetes Secret được mã hoá, có thể lưu an toàn trong Git.

**Secret** — Lưu dữ liệu nhạy cảm (mật khẩu, API keys, chứng chỉ) trong Kubernetes.

**Service** — Abstraction định nghĩa điểm kết nối mạng ổn định cho một hoặc nhiều pods.

**ServiceAccount** — Danh tính cho process chạy trong pod, dùng để xác thực với Kubernetes API.

**StatefulSet** — Giống Deployment nhưng cho ứng dụng có trạng thái. Mỗi pod có danh tính và lưu trữ ổn định.

**StorageClass** — Định nghĩa các loại lưu trữ khác nhau (SSD nhanh, HDD chậm).

## T

**TLS/SSL** — Giao thức mã hoá bảo vệ web traffic (HTTPS).

## V

**Velero** — Công cụ backup cho Kubernetes: backup tài nguyên và persistent volumes lên cloud storage.

**Volume** — Thư mục trong pod có thể truy cập từ containers.

**VPC (Virtual Private Cloud)** — Mạng riêng trong AWS nơi tài nguyên của bạn hoạt động.

## Y

**YAML** — Định dạng dữ liệu mà con người có thể đọc được, dùng để định nghĩa tài nguyên Kubernetes.
