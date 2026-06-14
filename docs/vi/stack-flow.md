# Hướng dẫn từng bước: Từ số 0 đến ứng dụng chạy trên Kubernetes

Hướng dẫn này giải thích mọi thứ bạn cần để triển khai ứng dụng với dự án này. Không yêu cầu kiến thức Kubernetes trước đó.

## Trước khi bắt đầu: Các công cụ cần cài đặt

### 1. Git

Công cụ tải mã nguồn từ GitHub.

```bash
git --version   # Kiểm tra đã cài chưa
```

**Cài đặt:**
- **Ubuntu/Debian**: `sudo apt install git -y`
- **macOS**: `brew install git` hoặc tải từ https://git-scm.com
- **Windows**: Tải từ https://git-scm.com

### 2. AWS CLI

Cho phép máy tính của bạn nói chuyện với Amazon Web Services.

```bash
# Linux:
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# macOS: brew install awscli
```

**Cấu hình:**
```bash
aws configure
```
Bạn cần Access Key ID và Secret Access Key từ AWS Console.

### 3. eksctl

Công cụ tạo Kubernetes cluster trên AWS.

```bash
# Linux:
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz"
tar -xzf eksctl_Linux_amd64.tar.gz
sudo mv eksctl /usr/local/bin/

# macOS: brew install eksctl
```

### 4. kubectl

Công cụ chính để điều khiển Kubernetes.

```bash
# Linux:
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# macOS: brew install kubectl
```

### 5. Helm

Trình quản lý gói cho Kubernetes (giúp cài đặt phần mềm phức tạp dễ dàng hơn).

```bash
# Linux:
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod +x get_helm.sh
./get_helm.sh

# macOS: brew install helm
```

### 6. kustomize

Công cụ tùy chỉnh cấu hình Kubernetes (tích hợp sẵn trong kubectl).

```bash
kubectl kustomize --help   # Kiểm tra
```

---

## Bước 1: Tải dự án về

```bash
git clone https://github.com/nathanpixodeo/k8s-production-stack.git
cd k8s-production-stack
```

---

## Bước 2: Tạo Kubernetes Cluster

Đây là bước quan trọng nhất — tạo máy chủ trên AWS.

```bash
eksctl create cluster -f clusters/eksctl-cluster.yaml
```

**Việc này mất 15-25 phút.** Nó tạo ra:
- Một mạng riêng (VPC) với các subnet public/private
- Kubernetes control plane ("bộ não" của cluster)
- 2 máy chủ EC2 (gọi là nodes)
- Cấu hình mạng để mọi thứ kết nối được với nhau

**Kiểm tra:**
```bash
kubectl get nodes
# Bạn sẽ thấy danh sách các máy chủ với trạng thái "Ready"
```

---

## Bước 3: Cấu hình ổ cứng (Storage)

```bash
kubectl apply -k storage/
```

**Tạo ra:**
- **StorageClass `gp3`**: Loại ổ SSD nhanh
- **VolumeSnapshotClass**: Cho phép chụp snapshot dữ liệu

**Kiểm tra:**
```bash
kubectl get storageclass
```

---

## Bước 4: Cài đặt hệ thống mạng (Cửa chính)

```bash
kubectl apply -k networking/
```

**Tạo ra:**

### Ingress-NGINX (Cửa chính)
- Một bộ định tuyến thông minh đặt trước cluster
- Một AWS Network Load Balancer (NLB)
- Tất cả traffic từ Internet đều vào qua đây

### cert-manager (Người làm chìa khoá tự động)
- Tự động lấy chứng chỉ HTTPS miễn phí từ Let's Encrypt
- Tự động gia hạn trước khi hết hạn

**Kiểm tra:**
```bash
kubectl get pods -n ingress-nginx
kubectl get pods -n cert-manager
```

---

## Bước 5: Cài đặt giám sát (Dashboard)

```bash
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -k monitoring/
```

**Tạo ra: Prometheus, Grafana, Loki, AlertManager**

**Mở Grafana:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Mở http://localhost:3000 trên trình duyệt
```

---

## Bước 6: Cài đặt bảo mật (Tường lửa + Kiểm soát)

```bash
kubectl apply -k security/
```

**Tạo ra:**
- **Network Policies**: Tường lửa — mặc định chặn hết, chỉ mở khi cần
- **RBAC**: Phân quyền — ServiceAccount, Role, RoleBinding
- **Sealed Secrets**: Mã hoá secrets để lưu an toàn trong Git

---

## Bước 7: Cài đặt Database

Chọn engine database:

```bash
# MySQL (mặc định):
kubectl apply -k database/

# PostgreSQL (dùng cho fullstack):
# Sửa database/kustomization.yaml, sau đó:
# kubectl apply -k database/postgresql/
```

**Tạo ra:**
- 3 bản sao database (1 chính + 2 phụ)
- Mỗi bản có 10GB ổ SSD riêng
- Service `database-svc` (ghi) và `database-svc-read` (đọc)

**Kiểm tra:**
```bash
kubectl get pods -n myapp -w
kubectl get svc -n myapp
```

---

## Bước 8: Triển khai ứng dụng

### Option A: Ứng dụng đơn giản
```bash
kubectl apply -k application/
```

### Option B: Laravel API
```bash
kubectl apply -k frameworks/laravel/
```

### Option C: React Frontend
```bash
kubectl apply -k frameworks/react/
```

### Option D: Fullstack (Laravel + React + PostgreSQL) — Khuyến nghị
```bash
kubectl apply -k database/postgresql/
kubectl apply -k frameworks/fullstack/
```

---

## Bước 9: Cài đặt sao lưu

```bash
kubectl apply -k backup/
```

Cài **Velero** — công cụ backup tự động lên AWS S3.

---

## Bước 10: Cài đặt GitOps

```bash
kubectl apply -k gitops/
```

Cài **ArgoCD** — tự động đồng bộ từ Git lên cluster.

---

## Các lệnh thường dùng

| Mục đích | Câu lệnh |
|----------|----------|
| Xem tất cả pods | `kubectl get pods -A` |
| Xem log ứng dụng | `kubectl logs -n myapp -l app=laravel` |
| Xem log theo thời gian thực | `kubectl logs -n myapp -l app=laravel -f` |
| Chạy lệnh trong pod | `kubectl exec -n myapp deploy/laravel -- php artisan list` |
| Xem services | `kubectl get svc -A` |
| Xem ingress | `kubectl get ingress -A` |
| Restart deployment | `kubectl rollout restart deployment laravel -n myapp` |
| Mở shell trong pod | `kubectl exec -n myapp -it deploy/laravel -- /bin/sh` |
| Xem tài nguyên | `kubectl top pods -n myapp` |

---

## Xoá toàn bộ

```bash
# CẢNH BÁO: Xoá VĨNH VIỄN, kể cả database
./scripts/destroy.sh
```

## Thuật ngữ cơ bản

| Thuật ngữ | Ý nghĩa | Ví dụ |
|-----------|---------|-------|
| **Cluster** | Toàn bộ hệ thống Kubernetes | Toà nhà nhà hàng |
| **Node** | Một máy chủ trong cluster | Một căn bếp |
| **Pod** | Đơn vị nhỏ nhất — chứa container | Một đầu bếp |
| **Deployment** | Quản lý nhóm pod giống hệt nhau | Bếp trưởng |
| **Service** | Điểm kết nối ổn định cho pods | Phục vụ bàn |
| **Ingress** | Cửa vào cho traffic từ Internet | Cửa chính |
| **Namespace** | Cách tổ chức tài nguyên (như thư mục) | Khu vực nhà hàng |
| **ConfigMap** | Lưu cấu hình (không bí mật) | Thẻ công thức |
| **Secret** | Lưu dữ liệu nhạy cảm (mật khẩu) | Két sắt |
| **PVC** | Yêu cầu lưu trữ | Đặt mua kệ mới |
| **StatefulSet** | Giống Deployment nhưng danh tính ổn định | Chỗ ngồi cố định |
| **HPA** | Tự động mở rộng | Thuê thêm người khi đông |
| **NetworkPolicy** | Tường lửa | Khoá cửa |
