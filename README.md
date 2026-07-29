# WorkSave — Save trạng thái làm việc như game

App Flutter Windows đơn giản, dữ liệu lưu SQLite local (không cần server, không cần mạng).

## Tính năng

| Tab | Chức năng |
|---|---|
| **Task** | Task với các trường: Mô tả, Bối cảnh, Vướng mắc, Hướng giải quyết, **Deadline (ngày + giờ)** + nhật ký hằng ngày. Deadline có công tắc **bật/tắt nhắc riêng**, và tự đẩy sang Lịch thành mục `[Deadline] tên task`. Nút 🤖 copy toàn bộ thông tin task thành prompt để dán vào AI chat xin gợi ý. |
| **Pomodoro** | Đồng hồ tập trung 25/5/15 (chỉnh được), tự luân phiên focus → nghỉ ngắn → nghỉ dài. Gắn phiên với 1 task để tự ghi nhật ký "Pomodoro 25 phút" cho task đó. Hết giờ có notification + pháo hoa. Thống kê số phiên & tổng phút hôm nay. |
| **Save** | Thứ 6 bấm "Tổng hợp việc còn dở & Save" → AI (Gemini) tự đọc các task chưa xong và viết sẵn bản save. Sáng thứ 2 mở app, save mới nhất tự bật lên như load game. Vẫn có "Save thủ công" bất kỳ lúc nào. |
| **Ý tưởng** | Ghi nhanh ý tưởng, sửa/xóa được. Ý tưởng nào chín thì bấm nút ✓ để chuyển thẳng thành Task. |
| **Nhật ký** | Ghi lại suy nghĩ tự do theo ngày ("đang nghĩ gì"), khác với log của task ("đã làm gì"). |
| **Lịch** | Lịch lưới tháng kiểu Outlook: mỗi ngày 1 ô, việc hiện ngay trong ô (kèm giờ nếu có). Mỗi mục có nút bật/tắt nhắc riêng. Điều hướng tháng trước/sau không giới hạn, nút "Hôm nay", bấm vào tên tháng để nhảy nhanh. Bấm vào ô ngày để thêm/sửa/xóa việc. Tới ngày, app bật notification Windows (khi app đang mở). |
| **Chấm công** | Nhắc giờ chấm công vào/ra. Đặt giờ riêng cho từng mốc, chọn áp dụng những thứ nào trong tuần, bật/tắt độc lập. Hôm OT thì thêm ngoại lệ cho đúng ngày đó (hoặc đặt "không nhắc" khi nghỉ phép). Xác nhận "đã chấm công" thì ngừng nhắc. |
| **Báo cáo** | Gom nhật ký các task trong tuần → sinh sẵn 1 prompt, copy dán vào AI để ra báo cáo đúng format `-Ngày .../.../...: "..."`. Cảnh báo các task chưa Done. |

Nhắc task chưa Done: banner cam hiện ngay khi mở app nếu còn task chưa chuyển sang Done.

## Ngôn ngữ & thứ tự tab (v7)

- **Đổi ngôn ngữ**: Settings ⚙ → chọn **Tiếng Việt / English**. Giao diện đổi ngay, không cần khởi động lại. Lựa chọn được lưu vào DB.
- **Sửa thứ tự tab**: Settings ⚙ → **Sửa thứ tự tab...** → dùng mũi tên ↑ ↓ hoặc kéo thả để sắp xếp → **Lưu**. Có nút "Về mặc định". Thứ tự lưu vào DB và áp dụng ngay cho thanh trái.

## Tính năng nền (v5)

- **Chạy nền ở system tray**: bấm X là app thu vào khay ẩn (hidden icons), noti và review vẫn chạy. Click icon tray để mở lại, chuột phải để có menu (mở / ghi nhanh / thoát hẳn).
- **Ghi nhanh toàn cục**: nhấn **Ctrl+Shift+Space** ở bất kỳ đâu → bật ô ghi nhanh vào Nhật ký hoặc Ý tưởng, Enter là lưu.
- **Mở cùng Windows**: bật trong Settings ⚙ để app tự chạy khi mở máy.
- **Review cuối ngày**: tới giờ đặt trong Settings (mặc định 16:30) app tự hỏi "hôm nay đã làm gì?" — ghi 1 dòng log cho mỗi task, tick Done task nào xong. Đây là nguồn dữ liệu cho báo cáo tuần. Cũng mở thủ công bằng icon 🌇 trên thanh trái.
- **Tìm kiếm toàn app** (icon 🔍): quét task, log, ý tưởng, nhật ký, save, lịch.
- **Reward 🎉**: hoàn thành task, xác nhận xong lịch, chốt sổ cuối ngày → pháo hoa + lời chúc mừng.
- **Sao lưu / khôi phục**: Settings ⚙ → xuất toàn bộ dữ liệu ra 1 file JSON; mất app/cài lại máy → cài app mới → "Khôi phục từ file" là dữ liệu về đủ. Lưu ý file backup chứa cả API key trong settings.

## AI tổng hợp T6 (Gemini — miễn phí)

1. Lấy API key miễn phí tại **aistudio.google.com/apikey** (đăng nhập Google → Create API key).
2. Trong app bấm ⚙ (góc dưới thanh trái) → dán key → Lưu. Key chỉ nằm trong SQLite local.
3. Model mặc định: **gemini-2.5-flash** (free ~250 request/ngày — dư sức cho 1 lần/tuần).
   Nếu báo quota, app tự thử **gemini-2.5-flash-lite** (free ~1000 request/ngày).

Quy tắc tiết kiệm quota đã cài sẵn:
- Chỉ gọi API vào **thứ 6**, và **mỗi thứ 6 đúng 1 lần** — bấm lại trong ngày sẽ dùng bản đã gen (cache).
- Hết quota / sai key / mất mạng → app KHÔNG treo: tự chuyển sang bản liệt kê local và báo lý do.


## Kiến trúc mã nguồn (v1.0)

Bốn tầng, phụ thuộc chỉ đi một chiều từ trên xuống:

```
lib/
├─ main.dart            khởi động nền tảng (window, tray, notifier, autostart)
├─ app.dart             MaterialApp, đổi ngôn ngữ là rebuild
├─ core/                tiện ích thuần Dart: ClockTime, ngày tháng, khóa settings
├─ domain/              miền nghiệp vụ — KHÔNG import Flutter
│  ├─ enums.dart        TaskStatus, PomodoroPhase, AppTab, AppLanguage...
│  └─ models/           Task, Deadline, ScheduleItem, Checkpoint, ReminderSettings...
├─ data/
│  ├─ app_database.dart chỉ mở kết nối + migration (v1 → v6)
│  ├─ dao/              SQL thuần, mỗi bảng một lớp
│  └─ repositories/     nghiệp vụ: đồng bộ task↔lịch, luật nhắc, tìm kiếm, backup
├─ services/            L10n, ReminderService, GeminiService, AiPromptBuilder...
└─ ui/                  theme, screens/, dialogs/, widgets/ — không có câu SQL nào
```

Nguyên tắc: `ui` gọi `services` và `repositories`; `repositories` gọi `dao`;
`dao` gọi `app_database`. Không có chiều ngược lại, và `domain` không phụ thuộc
vào bất cứ tầng nào khác.

### Những gì đã sửa khi dọn code cho bản phát hành

- **Bỏ god class `AppDb` (673 dòng)** vốn ôm cả kết nối, SQL, nghiệp vụ, tìm
  kiếm, sao lưu lẫn chuỗi hiển thị → tách thành 6 DAO + 7 repository.
- **Cắt import vòng** giữa tầng dữ liệu và tầng dịch (`AppDb` từng gọi `L10n`).
- **Kiểu mạnh thay chuỗi ma thuật**: `TaskStatus`, `AppTab`, `AppLanguage`,
  `PomodoroPhase`, `SearchHitKind`, `QuickCaptureTarget`; khóa settings gom vào
  `SettingKeys`; giờ-phút có kiểu `ClockTime` riêng thay vì `String 'HH:mm'`.
- **Sửa lỗi thật**: deadline đúng 00:00 từng bị coi là "cả ngày" vì `hasTime`
  suy ra từ `hour == 0 && minute == 0`. Nay `Deadline` lưu ngày và giờ tách
  bạch (migration v6 tự chuyển dữ liệu cũ).
- **Model bất biến** (`@immutable` + `copyWith`) — không còn sửa ngầm object mà
  UI đang giữ.
- **Kéo nghiệp vụ ra khỏi widget**: vòng lặp nhắc lịch giờ ở `ReminderService`,
  luật đồng bộ deadline↔lịch ở `TaskRepository`, dựng prompt ở `AiPromptBuilder`.
- **Lỗi có kiểu**: `sealed class GeminiFailure` (quota / request) và
  `sealed class BackupResult` thay cho việc bắt `Exception` chung chung.
- **Tách widget dùng lại**: `CelebrationOverlay`, `TextEntryField`,
  `UnfinishedTasksBanner`, `ScreenTitle`; màu và khoảng cách gom vào
  `ui/theme.dart` thay vì rải mã màu khắp nơi.
- **`analysis_options.yaml`** bật `strict-casts`, `strict-inference`,
  `strict-raw-types` cùng bộ lint bổ sung.

## Cài đặt & chạy (Windows)

Yêu cầu: Flutter SDK (bản stable), Visual Studio với workload "Desktop development with C++".

```bat
cd worksave
flutter create --platforms=windows .
flutter pub get
flutter run -d windows
```

Lệnh `flutter create --platforms=windows .` chỉ sinh thêm phần khung Windows còn thiếu,
KHÔNG ghi đè code trong `lib/`.

## Build file .exe để dùng hằng ngày

```bat
flutter build windows --release
```

File chạy nằm ở: `build\windows\x64\runner\Release\worksave.exe`
(copy nguyên thư mục `Release` đi đâu cũng chạy được).

## Dữ liệu lưu ở đâu?

SQLite tại `%APPDATA%\com.example\worksave\worksave.db` (thư mục Application Support).
Backup = copy file này.

## Nhắc chấm công (v1.1)

Hai lớp cấu hình, ngoại lệ luôn thắng lịch mặc định:

1. **Giờ hằng ngày** — mỗi mốc (vào / ra) có giờ riêng, chọn được áp dụng thứ
   nào trong tuần, và có công tắc bật/tắt độc lập. Mặc định gợi ý 07:30 và
   17:00 cho T2–T6 nhưng **để TẮT**, để app không tự bắn thông báo sai giờ —
   vào tab Chấm công chỉnh giờ rồi bật lên.
2. **Ngoại lệ theo ngày** — hôm OT thì thêm một mốc riêng cho đúng ngày đó
   (ví dụ 21/07 chấm ra lúc 20:00, kèm ghi chú). Bật "Hôm đó không nhắc" khi
   nghỉ phép hoặc đi công tác.

Cách nhắc dùng chung tham số với lịch: báo trước N phút, lặp mỗi M phút
(Settings ⚙ → *Cách nhắc lịch*), và **chỉ dừng khi bạn bấm xác nhận đã chấm
công** cho mốc đó trong ngày. Sang ngày mới trạng thái tự reset.

## Cách nhắc lịch (v8)

Mốc tới hạn của một mục:
- Có đặt giờ → đúng giờ đó.
- Để **"Cả ngày"** → dùng **giờ nhắc đầu ngày** trong Settings (mặc định **08:00**).

Cách nhắc:
1. **Báo trước** mốc N phút (mặc định **10**, chỉnh trong Settings) — thông báo ghi rõ "Còn N phút nữa tới hạn".
2. Tới giờ → "Đã tới hạn".
3. Sau đó **nhắc lại mỗi M phút** (mặc định **10**, chỉnh được), thông báo ghi rõ đã quá hạn bao nhiêu phút, **cho tới khi bạn xác nhận xong**.

Tắt nhắc bằng 1 trong 2 cách: chuyển task sang **Done** (mục deadline liên kết tự tắt), hoặc vào **Lịch** → bấm ô ngày → bấm icon chuông đỏ để xác nhận. Mở lại task (Done → Đang làm) thì nhắc tiếp. Mỗi mục cũng có công tắc bật/tắt nhắc riêng.

Ba tham số trong Settings ⚙ → *Cách nhắc lịch*: **Giờ nhắc đầu ngày**, **Báo trước (phút)**, **Nhắc lại mỗi (phút)**.

Lưu ý kỹ thuật:
- App quét mỗi **30 giây**, nên thời điểm nhắc có thể lệch tối đa nửa phút.
- Notification chỉ bắn được khi **app đang chạy** (mở cửa sổ hoặc thu vào khay). Bật "Mở cùng Windows" trong Settings để yên tâm.
- Lần đầu chạy, `local_notifier` tự tạo shortcut để Windows cho phép hiện toast.

## Quy trình dùng gợi ý

1. Đầu ngày: mở app → đọc save gần nhất → làm việc. Có lịch tới hạn thì noti tự bắn.
2. Trong ngày: làm xong việc gì thì mở task đó, gõ 1 dòng nhật ký, bấm **Ghi**.
3. Xong task: bấm vào icon tròn bên trái task để chuyển Chưa làm → Đang làm → Done.
4. Chiều thứ 6: tab **Báo cáo** → Copy prompt → dán vào AI → có báo cáo tuần. Sau đó tab **Save** → "Tổng hợp việc còn dở & Save" → sửa lại nếu cần → Save.
