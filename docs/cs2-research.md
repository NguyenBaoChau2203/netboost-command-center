# CS2, Windows và NVIDIA — nghiên cứu ngày 09/11/2026

## Bối cảnh của máy

Kiểm tra chỉ đọc: Windows 11 Home Single Language build 26300; Intel i5-11400H (6 nhân/12 luồng); RAM 16 GB; Intel UHD và NVIDIA RTX 3050 Ti Laptop GPU; driver NVIDIA hiển thị 32.0.16.1078; màn hình hiện 1920x1080, 120 Hz; power plan Balanced. DRS đang gắn cs2.exe với profile Counter-strike 2. Power management và preferred refresh đều có local override 1 trước khi NetBoost thay đổi gì.

Chủ máy chỉ dùng Discord để thoại, đã tắt tăng tốc phần cứng và đã đo chênh lệch 10–15% FPS giữa mở/không mở Discord. Đây là số đo người dùng cung cấp, không phải kết quả benchmark của tính năng mới.

## Nguồn chính thức và quyết định triển khai

- [NVIDIA: Counter-Strike 2 with Reflex](https://www.nvidia.com/en-au/geforce/news/counter-strike-2-released-featuring-nvidia-reflex/) mô tả bật Reflex trong game và đo PC latency. Vì vậy NetBoost hướng dẫn dùng điều khiển Reflex trong CS2, không coi legacy pre-rendered frames hoặc Low Latency Mode của driver là thay thế tương đương.
- [Valve: CS2 video settings recommendations](https://help.steampowered.com/en/faqs/view/418E-7A04-B0DA-9032) giải thích tổ hợp V-Sync/G-SYNC/Reflex khi thiết bị hỗ trợ. Tùy chọn đồng bộ hình ảnh có điều kiện về màn hình, nên không tự ép đồng loạt VRR/G-SYNC/V-Sync theo file cộng đồng.
- [NVIDIA NVAPI driver setting definitions](https://github.com/NVIDIA/nvapi/blob/main/NvApiDriverSettings.h) xác định PREFERRED_PSTATE_ID=0x1057EB71 với PREFER_MAX=1 và REFRESH_RATE_OVERRIDE_ID=0x0064B541 với HIGHEST_AVAILABLE=1. Đây là hai DWORD được allowlist; không ghi các cờ ẩn khác.
- [NVIDIA DRS API](https://github.com/NVIDIA/nvapi/blob/main/nvapi.h) cung cấp FindApplicationByName theo đường dẫn đầy đủ, đọc/ghi/xóa local override và lưu session. [Interface IDs](https://github.com/NVIDIA/nvapi/blob/main/nvapi_interface.h) được đối chiếu trực tiếp. Binding dùng cấu trúc setting 12320 byte, application V4 20492 byte, profile V1 4116 byte; đã đọc được profile thật mà không ghi driver.
- [Microsoft: SetPriorityClass](https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-setpriorityclass) và [Scheduling Priorities](https://learn.microsoft.com/en-us/windows/win32/procthread/scheduling-priorities) phân biệt các mức ưu tiên, cảnh báo mức High có thể chiếm phần lớn CPU. NetBoost chọn AboveNormal cho CS2 và BelowNormal cho Discord thoại qua hành động tự chọn. Cơ chế cố định và giới hạn bằng chứng được trình bày riêng bên dưới; không gọi nó là API Win32 được Microsoft bảo đảm.
- [Microsoft: Game Mode](https://blogs.windows.com/windowsexperience/2017/05/01/windows-10-tip-get-power-windows-10-pc-game-mode/) mô tả Windows quản lý tài nguyên cho game. Preset bật Game Mode; không tự tắt hàng loạt dịch vụ, bảo mật hoặc quản lý nhiệt của laptop.
- [NVIDIA Profile Inspector README](https://github.com/Orbmu2k/nvidiaProfileInspector/blob/master/README.md) và [releases](https://github.com/Orbmu2k/nvidiaProfileInspector/releases) xác nhận công cụ dùng DRS và nhiều setting có thể ẩn/đặc thù driver. Tại ngày tra cứu, latest trỏ tới v3.0.2.1. NetBoost không phụ thuộc binary này: CLI có silent import nhưng nhập kiểu merge không phải cơ chế bảo đảm phục hồi chính xác trạng thái vốn kế thừa của một vài setting. Binding riêng phục hồi từng mục thay vì reset/import toàn database.

Các registry value Game Mode, Historical Capture và UserGpuPreferences là cách lưu thiết lập Windows hiện tại; cần kiểm tra lại sau các bản Windows thay đổi cơ chế. Snapshot lưu tồn tại, kiểu dữ liệu và giá trị, áp dụng có đọc lại xác minh, và không tuyên bố có ưu tiên cứng về watt/CPU hay mức tăng FPS cố định.

## Cộng đồng hiện tại: xem như giả thuyết để đo

Đã đọc [thảo luận GlobalOffensive về tối ưu laptop trong năm 2026](https://www.reddit.com/r/GlobalOffensive/comments/1r0v7v4/my_cs2_optimization_the_game_runs_terribly_this/). Người viết thử nhiều thay đổi và tự báo cải thiện, gồm nhiệt độ, power plan, affinity và tắt nhiều thành phần. Đây là trải nghiệm của một máy, không chứng minh từng tweak có tác dụng độc lập. Một số thay đổi như tắt bảo mật/iGPU/quản lý nhiệt có rủi ro hoặc ảnh hưởng ngoài game nên không được đưa vào preset.

Đã đọc [thảo luận cs2 gần đây về Reflex, đồng bộ và cảm giác chuột](https://www.reddit.com/r/cs2/comments/1wyzi4k/what_are_currently_the_best_settings_for_cs2_if_i/). Các bình luận đưa ra kết quả trái nhau giữa Reflex, Boost, G-SYNC, V-Sync và bỏ core 0/1; không có một cấu hình được chứng minh tốt nhất cho mọi máy. Điều này ủng hộ thử A/B trên đúng máy, không tự áp affinity hoặc tắt Reflex từ lời khuyên cảm tính.

Các nguồn cộng đồng phục vụ tìm giả thuyết. Quyết định API, ID và hành vi lập lịch dựa trên nguồn chính thức ở trên. Không dùng các bài SEO khẳng định CS2 không có Reflex hoặc hứa tăng FPS cố định.

## Hai file NIP được cung cấp

| Nội dung | CS2.nip | khorviePI.nip | Xử lý |
| --- | --- | --- | --- |
| Profile | Counter-strike 2; cs2.exe và csgos2.exe | Base Profile; không có executable | Preset hiện tại chỉ chỉnh profile NVIDIA của CS2; không nhập nguyên file |
| Power management | 1 | 1 | Chỉ cho CS2, có baseline riêng |
| Preferred refresh rate | 1 | 1 | Chỉ cho CS2, có baseline riêng |
| Shader cache size | 102400 | 10240 | Không tự tăng cache/global hoặc dọn trước mỗi lần chơi |
| Preferred OpenGL GPU | Chuỗi device ID cụ thể | Không có | Không tái sử dụng chuỗi GPU của máy khác |
| Threaded optimization | 1 | 2 | Cờ OpenGL, không tự coi là tối ưu Direct3D/Vulkan của CS2 |
| Pre-rendered frames | 1 | 1 | Giữ điều khiển latency cho Reflex trong game |
| G-SYNC/VRR | Nhiều override | Override khác file CS2 | Không ép theo cấu hình màn hình của người khác |
| Cờ không tên/ẩn | Có | Có | Chỉ báo cáo; không áp dụng |

`--cs2-audit-profile PATH` dùng XML reader cấm DTD/external entities, giới hạn dung lượng và trả lý do cho từng setting. Nó không tải thư viện, thực thi lệnh, import profile hay coi nội dung file là chỉ dẫn. Các file Downloads gốc được giữ nguyên.

Kết quả audit trực tiếp: CS2.nip có 33 setting, chỉ 2 mục thuộc preset được duyệt; khorviePI.nip có 35 setting và nhắm global nên không có mục nào được chấp nhận để nhập. Cả hai file có BOM UTF-8 nhưng khai báo XML UTF-16; bộ đọc giải mã BOM trước để xử lý định dạng xuất legacy này mà không sửa file gốc.

Chủ máy chấp nhận cả phạm vi global nếu có backup. Quyết định giữ driver preset riêng cho CS2 là lựa chọn triển khai cho các mục đã kiểm chứng, không phải kết luận rằng mọi thay đổi global đều có hại. Game Mode và Historical Capture là thay đổi Windows phạm vi tài khoản đã được đưa vào backup. Phần tối ưu mạng cũng được sửa để giữ chính sách QoS hiện có, tránh vô hiệu hóa bảo đảm thoại/media chỉ vì hiểu nhầm một hạn mức dành trước là mất băng thông cố định. [Microsoft giải thích cơ chế QoS](https://devblogs.microsoft.com/oldnewthing/20061123-14/?p=28923/).

## Bổ sung ngày 2026-11-10: ưu tiên cố định, Discord và FACEIT

Chủ máy yêu cầu [4] áp dụng một lần cho các lần mở app sau, không phải mở lại NetBoost mỗi lần. Cơ chế được chọn là IFEO PerfOptions theo tên `cs2.exe`/`Discord.exe`, không dùng watcher hoặc launcher thay thế Steam/FACEIT. Nó có phạm vi toàn máy, kể cả khi không có game; được trình bày trước nút APPLY và có backup/restore riêng.

[Microsoft mô tả IFEO](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/xperf/image-file-execution-options) cho cơ chế đọc tùy chọn executable khi tải tiến trình, nhưng trang đó chỉ tài liệu hóa TracingFlags, **không chứng nhận PerfOptions/CpuPriorityClass**. [Header phnt do dự án System Informer duy trì](https://github.com/winsiderss/systeminformer/blob/master/phnt/include/ntpsapi.h) xác định các native priority class: BelowNormal=5 và AboveNormal=6. Đây là nguồn kỹ thuật của dự án nghiên cứu Windows internals, không phải lời bảo đảm từ Microsoft về registry này. Kiểm chứng ghi/đọc Registry chỉ xác nhận cấu hình, chưa chứng minh game/AC giữ mức ưu tiên ở mọi phiên bản. Không đóng gói mã hoặc binary System Informer.

Vì không có tiến trình nền, đây là **mức ưu tiên ban đầu**; game, launcher hoặc Anti-Cheat có thể đổi sau khi mở. Trạng thái cho phép xem mức ưu tiên thực tế của CS2/Discord ở thời điểm kiểm tra. FACEIT/AC không nằm trong allowlist ghi registry hay sửa tiến trình. Quy tắc không can thiệp vào security, driver, IO, memory priority hoặc CPU affinity.

[FACEIT: FPS drops / input lag issues](https://support.faceit.com/hc/en-us/articles/360015781379-FPS-drops-input-lag-issues), cập nhật được hiển thị là 2025-10-23, giải thích AC mở game với khả năng cho phép overlay bên thứ ba; các overlay có thể gây chênh lệch hiệu năng. Hướng dẫn đề nghị chưa queue, bật AC/game và vào server thường để kiểm tra. NetBoost đưa phần đo này vào hướng dẫn, không tự thay launch options hoặc tắt dịch vụ/bảo mật. Nguồn không xác nhận IFEO hoặc chứng nhận NetBoost tương thích FACEIT.

Đã kiểm thử transaction bằng file journal thật và adapter giả lập thao tác ghi hệ thống, cùng đọc HKLM/NVIDIA thực tế. Shell phát triển không có quyền quản trị; không áp dụng rule CS2/Discord thật, không thay Anti-Cheat và không chạy trận FACEIT. Chủ máy báo cải thiện từ preset trước đó; cần đo riêng phiên bản ưu tiên cố định mới.
