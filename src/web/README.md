# NetBoost Command Center - Local Web UI

Dự án giao diện Web quản trị tối ưu (Local Web UI) cho NetBoost Command Center, được phát triển bằng **React**, **TypeScript**, **Vite** và **Tailwind CSS v4**.

Giao diện Web được tối ưu hóa đẹp mắt theo đúng mockup Stitch, hiển thị hoàn hảo trên màn hình Desktop và Mobile (responsive chiều rộng tối thiểu 390px).

Tuân thủ nghiêm ngặt hiến pháp dự án (`constitution.md`): **100% Local-first**, **Không thu thập telemetry**, **Không yêu cầu tài khoản đám mây**, và **Tuyệt đối an toàn cho hệ thống** (không ép đóng display drivers hay ứng dụng khi dọn cache).

---

## 🛠️ Hướng dẫn cài đặt và khởi chạy

Thư mục Web UI nằm độc lập dưới đường dẫn `src/web/`. Bạn có thể thao tác trực tiếp bên trong thư mục này:

### 1. Cài đặt các gói phụ thuộc (Dependencies)
```bash
# Di chuyển vào thư mục src/web (hoặc mở terminal tại đây)
npm install
```

### 2. Khởi chạy máy chủ phát triển (Development Server)
Chạy lệnh sau để bật dev server cục bộ:
```bash
npm run dev
```
Sau đó mở trình duyệt và truy cập: **`http://127.0.0.1:5173`** (hoặc cổng hiển thị trong terminal).

### 3. Biên dịch bản sản xuất (Production Build)
Lệnh biên dịch sẽ tối ưu hóa toàn bộ assets thành file HTML/CSS/JS tĩnh đặt tại thư mục `src/web/dist/` để backend PowerShell có thể load trực tiếp:
```bash
npm run build
```

---

## 📂 Cấu trúc mã nguồn

*   **`src/App.tsx`**: Shell giao diện chính. Quản lý Sidebar trên Desktop, Bottom Tab Bar trên Mobile, và Top Bar hiển thị trạng thái Localhost / Administrator.
*   **`src/index.css`**: Nơi khởi tạo cấu hình Tailwind v4, định nghĩa các design tokens (bảng màu HSL cao cấp, spacings, fonts) và overrides kích thước bo góc (`rounded-xl` được cố định là `8px` theo đúng Stitch mockup).
*   **`src/api/`**:
    *   `types.ts`: Định nghĩa interface TypeScript cực kỳ chặt chẽ, map 100% theo hợp đồng API tại `specs/001-local-web-command-center/contracts/api.md`.
    *   `mockData.ts`: Chứa dữ liệu mẫu mô phỏng trùng khớp hoàn hảo với các thông số hiển thị từ mockup Stitch của người dùng Bao Chau.
    *   `client.ts`: Quản lý logic mô phỏng (Simulation adapter) cho các thao tác DNS (ping độ trễ, flush, reset), live dọn dẹp hệ thống (hiển thị tiến trình %, file đang xóa, danh sách file bị khóa) và test Scheduled Task.
*   **`src/views/`**:
    *   `DashboardView.tsx` (US1): Tổng quan adapter mạng, DNS đang sử dụng, task tự động, latency so sánh nhanh Google vs Cloudflare DNS, tiến trình dọn dẹp và Activity Log terminal.
    *   `DnsView.tsx` (US2): Cho phép tự động tối ưu chọn DNS nhanh nhất, force nhà mạng Google/Cloudflare, reset DHCP, flush cache và Console PowerShell.
    *   `CleanupView.tsx` (US3): Checklist dọn cache hệ thống an toàn (User/Windows temp, Shader caches, Crash dumps, Recycle Bin) kèm cảnh báo tác động rủi ro, popup xác nhận an toàn, live terminal logs và Locked-file table (liệt kê các file đang bận an toàn được bỏ qua).
    *   `AutoTaskView.tsx` (US4): Quản lý tạo/xóa Scheduled Task `NetBoost Auto DNS Optimizer` chạy lúc đăng nhập Windows. Tích hợp thanh timeline kiểm tra thực tế và PowerShell terminal.
    *   `SettingsView.tsx` (US5): Bento layout cho cài đặt giao diện (ngôn ngữ EN/VI, dark mode, compact mode), hiển thị bind address local-only read-only, session token toggles, PowerShell paths và nút **Test PowerShell v5.1** mô phỏng kiểm tra môi trường Windows.

---

## 🛡️ Cam kết kỹ thuật & Hiến pháp bảo mật

1.  **Local-First & Safety First**: Không tích hợp bất kỳ API cloud, telemetry hay tài khoản đăng nhập. Máy chủ backend bind chặt vào `127.0.0.1`.
2.  **Skip Locked Files**: Logic dọn dẹp được lập trình mô phỏng bỏ qua các file bị locked thay vì force-kill tiến trình hay Display Driver đồ họa, đảm bảo không gây treo hệ thống hay gián đoạn trải nghiệm người dùng Windows.
3.  **Report-Only Node Scanner**: Scanner chỉ phân tích đĩa và đưa ra hướng dẫn copyable, không thực hiện ghi hoặc thay đổi cấu trúc file của lập trình viên.
4.  **Accented Vietnamese Text**: Toàn bộ nhãn, hướng dẫn và thông điệp hiển thị sử dụng Tiếng Việt chuẩn có dấu, rõ ràng và trực quan cao.
