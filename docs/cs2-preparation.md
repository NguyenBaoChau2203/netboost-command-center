# Chuẩn bị chơi CS2

Mở NetBoost và chọn **[21]**. Tính năng này giữ cấu hình qua các lần chơi và không cài service, scheduled task, watcher hoặc helper nền. Bạn có thể đóng NetBoost sau khi áp dụng. Dùng bản xem trước để biết chính xác những gì sẽ đổi.

## Dùng lần đầu

1. Đóng CS2. Discord có thể tiếp tục mở.
2. Trong menu [21], chọn **[1]** để xem CPU/GPU/driver, nguồn điện, đường dẫn CS2 và trạng thái backup.
3. Chọn **[2]**, xem các thiết lập rồi nhập đúng `APPLY`.
4. Chương trình ghi và xác minh backup trước, sau đó áp dụng và kiểm tra kết quả từng bước. Khi thành công, đóng NetBoost và mở CS2 bình thường. Không cần áp dụng lại mỗi lần chơi.

Các thay đổi cố định:

| Mục | Phạm vi và giá trị |
| --- | --- |
| Windows Game Mode | Bật cho tài khoản Windows hiện tại; Windows đảm nhiệm quản lý tài nguyên khi chơi |
| Ghi hình nền | Tắt Historical Capture; không chỉnh lại thiết lập tăng tốc phần cứng Discord của bạn |
| Windows graphics preference | Chọn GPU hiệu năng cao riêng cho đường dẫn cs2.exe, giữ các token cấu hình khác |
| NVIDIA power management | Prefer Maximum Performance, chỉ trong profile mà driver gắn với cs2.exe |
| NVIDIA preferred refresh | Highest Available, chỉ trong cùng profile CS2 |

Trên laptop đã khảo sát, hai thiết lập NVIDIA đã là `1` từ trước. Áp dụng lại không tạo lợi ích mới từ chính hai mục đó; backup sẽ giữ nguyên các lựa chọn cũ của bạn.

Game Mode là thiết lập Windows chung cho tài khoản, Historical Capture ảnh hưởng ghi hình nền của các game; hai mục này đều được sao lưu riêng. Tính năng giữ nguyên power plan Windows, dịch vụ, Defender/anti-cheat, cập nhật driver, timer, affinity, G-SYNC/V-Sync và cài đặt trong game. Nó không nhập toàn bộ file .nip cộng đồng và không chỉnh Base Profile.

## Ưu tiên cố định cho CS2 + Discord thoại + FACEIT

Chọn **[4]** trong menu CS2, đọc phạm vi thay đổi rồi nhập **`APPLY`**. Có thể làm trước khi mở game; không cần chạy lại mỗi lần chơi. Backup ưu tiên tách riêng khỏi backup Windows/NVIDIA, nên có thể dùng [4] độc lập với [2].

- Windows có quy tắc khởi động `cs2.exe` ở `AboveNormal` và `Discord.exe` ở `BelowNormal`, phù hợp lựa chọn Discord chỉ để thoại của bạn.
- Quy tắc áp dụng theo **tên executable, cho mọi tài khoản Windows**, kể cả khi ứng dụng còn lại không mở. Nó không chờ đủ CS2 + Discord + FACEIT mới kích hoạt.
- **Thoát hẳn rồi mở lại CS2 và Discord** sau khi bật. Discord có thể còn ở khay hệ thống; dùng Quit Discord để kết thúc trước khi mở lại. NetBoost không tự đóng app.
- Sau đó mở Discord, FACEIT/Anti-Cheat, CS2 như bình thường. Có thể đóng NetBoost; không có service, task, watcher hoặc helper nền.

Quy tắc dùng Windows IFEO `PerfOptions\CpuPriorityClass`: DWORD `6` cho CS2, `5` cho Discord, trong registry view gốc của hệ điều hành. Đây là cơ chế tùy chọn không được bảo đảm bằng một hợp đồng Win32 công khai; cần kiểm tra lại trên phiên bản Windows/game/FACEIT của bạn. Nó cung cấp mức ưu tiên ban đầu. Nếu game, launcher hoặc Anti-Cheat đổi lại mức ưu tiên sau đó, NetBoost không có tiến trình nền để ép lại. Xem **[1]** hoặc Task Manager → Details để kiểm tra mức ưu tiên thực tế. Việc lưu giá trị Registry thành công không tự chứng minh game đã giữ mức đó suốt trận.

Giữ nguyên FACEIT client, FACEITService, tiến trình/driver Anti-Cheat, bảo mật, affinity, IO và memory priority. Không đặt game ở High/Realtime. Nâng ưu tiên CPU không phân chia số watt cố định và không xóa chi phí xử lý thoại hoặc Anti-Cheat. Nếu Discord bị ngắt tiếng, chọn **[7]** để khôi phục riêng ưu tiên, rồi mở lại các app; bộ Windows/NVIDIA ở [2] vẫn được giữ.

FACEIT [hướng dẫn kiểm tra FPS/input lag](https://support.faceit.com/hc/en-us/articles/360015781379-FPS-drops-input-lag-issues) lưu ý overlay của phần mềm khác có thể hoạt động khi bật AC và làm giảm hiệu năng. Thử tắt Discord overlay bằng cài đặt Discord nếu bạn không cần nó; không tắt các dịch vụ bảo mật để tối ưu. Không tuyên bố NetBoost được FACEIT chứng nhận. Chưa chạy trận FACEIT để xác nhận tương thích của quy tắc ưu tiên mới.

Bản xem trước cũ chỉ đổi các tiến trình đang chạy. Bản mới thay [4] bằng quy tắc cố định nêu trên; các record PID/thời điểm khởi động trong backup cũ vẫn được hỗ trợ khôi phục.

## Backup và khôi phục

Backup ở `%LOCALAPPDATA%\NetBoost\cs2\backups\<id>.json`; trạng thái khôi phục hiện tại ở `%LOCALAPPDATA%\NetBoost\cs2\active.json`.

Ưu tiên cố định có journal riêng ở `%ProgramData%\NetBoost\cs2-priority\active.json` và `backups\<id>.json`, vì thay đổi này có phạm vi toàn máy. Dùng tài khoản đã tạo backup để khôi phục. Hai vị trí backup không nằm trong thư mục giải nén ứng dụng; nâng cấp bằng thư mục mới vẫn giữ được chúng.

- Chạy Apply lại khi cấu hình còn nguyên: giữ cùng baseline, không sao lưu đè trạng thái đã tối ưu lên bản gốc.
- Chọn **[3]** để khôi phục cả Windows/NVIDIA và ưu tiên cố định; **[7]** chỉ khôi phục ưu tiên cố định. Hai journal được xử lý riêng, lỗi từ từng phần được báo rõ. Mở lại CS2/Discord để áp dụng mức ưu tiên đã phục hồi.
- Giá trị Registry vốn không tồn tại sẽ được xóa; kiểu dữ liệu và giá trị cũ được giữ. Không xóa khóa IFEO cha hoặc tùy chọn khác do phần mềm ngoài tạo. NVIDIA vốn kế thừa mặc định/global sẽ trở về kế thừa, không bị ghim thành một override mới.
- Restore thành công kết thúc đợt hiện tại. Apply sau đó tạo backup có ID mới từ cấu hình hiện tại; lịch sử đợt cũ vẫn được giữ.
- Nếu app bị đóng hoặc máy tắt giữa chừng, chạy Restore để xử lý các bước đã ghi vào journal. Backup lỗi/khác máy/khác tài khoản bị từ chối trước khi chỉnh cấu hình.
- Nếu bạn chỉnh các mục đó bằng công cụ khác sau khi Apply, NetBoost báo xung đột thay vì ghi đè im lặng. Đưa mục xung đột về giá trị NetBoost đã áp dụng rồi thử Restore; không sửa tay nội dung baseline. Giữ cả active.json và thư mục backups khi cần hỗ trợ phục hồi.
- Ưu tiên tiến trình chỉ khôi phục khi PID, thời điểm khởi động và đường dẫn đều khớp; không tác động vào tiến trình mới dùng lại PID cũ.

Nhật ký dùng ghi tệp tạm, flush, rồi thay tệp nguyên tử. Không ghi được backup thì không áp dụng. Các bước đã thử được ghi trước khi gọi hệ thống. Lỗi áp dụng kích hoạt hoàn tác; nếu hoàn tác cũng lỗi, dữ liệu phục hồi được giữ và kết quả trả thất bại.

## CLI

```powershell
.\NetBoost_Command_Center.bat --cs2
.\NetBoost_Command_Center.bat --cs2-status
.\NetBoost_Command_Center.bat --cs2-plan
.\NetBoost_Command_Center.bat --cs2-optimize
.\NetBoost_Command_Center.bat --cs2-priority-plan
.\NetBoost_Command_Center.bat --cs2-priority
.\NetBoost_Command_Center.bat --cs2-priority-restore
.\NetBoost_Command_Center.bat --cs2-restore
.\NetBoost_Command_Center.bat --cs2-plan --cs2-exe "D:\SteamLibrary\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe"
.\NetBoost_Command_Center.bat --cs2-audit-profile "C:\Users\chau1\Downloads\CS2.nip"
```

`--cs2-status`, `--cs2-plan`, `--cs2-priority-plan` và `--cs2-audit-profile` chỉ đọc. `--cs2-optimize`, `--cs2-priority`, `--cs2-priority-restore`, `--cs2-restore` thực thi thay đổi và cần quyền quản trị. CLI trả mã 1 khi thao tác không hoàn tất. Restore không có baseline là không làm gì; không tự reset driver/Windows về giá trị đoán. IFEO có cấu hình UseFilter khác thường bị từ chối; NetBoost không sửa nó để ép quy tắc.

NVIDIA API nằm trong driver đã cài. Không cần cài hoặc chạy NVIDIA Profile Inspector để dùng tính năng. Nếu máy có NVIDIA nhưng DRS không đọc được hoặc không xác định được profile riêng của CS2, thao tác áp dụng bị chặn để tránh thay sai profile. Máy không có NVIDIA vẫn có phần Windows.

## Đo lại trên laptop

1. Cắm sạc, giữ nguyên chế độ quạt/hiệu năng của hãng laptop, độ phân giải, map/demo, giới hạn FPS và thiết lập CS2. Làm nóng game và chờ shader ổn định.
2. Dùng cùng một demo hoặc benchmark và cùng khoảng đo; chạy ba lượt mỗi trường hợp: không Discord, Discord thoại chưa ưu tiên, Discord thoại sau nút [4] và mở lại app. Chỉ đổi một điều giữa các trường hợp.
3. Ghi FPS trung bình, 1% low, frametime, GPU utilization, xung/nhiệt CPU/GPU. Phần trăm tụt FPS = `(FPS không Discord - FPS có Discord) / FPS không Discord * 100`.
4. Nếu GPU đã có dư tải nhưng FPS vẫn tụt khi Discord mở, kiểm tra CPU/voice/overlay trước. Nếu CPU/GPU hạ xung khi nóng hoặc chạy pin, so sánh lại ở cùng nhiệt độ và nguồn điện.
5. Kiểm tra NVIDIA Reflex trong CS2. Chọn V-Sync/G-SYNC theo màn hình và mục tiêu; không sao chép đồng loạt thiết lập VRR từ profile người khác.
6. Khi thử FACEIT, theo hướng dẫn của FACEIT: chưa queue trận, bật AC rồi vào server CS2 thường để đối chiếu với trường hợp không AC. Giữ Discord thoại giống nhau, kiểm tra overlay và mức ưu tiên thực tế; ghi lại frametime/1% low cùng FPS trung bình.

Chủ máy báo bộ tối ưu trước đó đã cải thiện. Chưa có benchmark sau khi bật ưu tiên cố định mới, cũng chưa đo với FACEIT/AC trong lần phát triển này. Xem [nghiên cứu và đối chiếu hai profile](cs2-research.md) để phân biệt dữ kiện chính thức với kinh nghiệm cộng đồng.
