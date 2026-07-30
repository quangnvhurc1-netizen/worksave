import 'package:flutter/foundation.dart';

import '../data/repositories/repositories.dart';
import '../domain/enums.dart';

/// Đa ngôn ngữ đơn giản: L10n.t('key'). Đổi ngôn ngữ -> notifier báo cho app
/// rebuild toàn bộ, không cần restart.
class L10n {
  L10n._();
  static final L10n instance = L10n._();

  static final ValueNotifier<AppLanguage> language =
      ValueNotifier<AppLanguage>(AppLanguage.vi);

  static Future<void> load() async {
    language.value = await Repos.settings.language();
  }

  static Future<void> setLanguage(AppLanguage lang) async {
    language.value = lang;
    await Repos.settings.saveLanguage(lang);
  }

  static bool get isEn => language.value == AppLanguage.en;

  /// Lấy chuỗi theo key. Không có key -> trả về chính key (dễ phát hiện thiếu).
  static String t(String key) {
    final map = isEn ? _en : _vi;
    return map[key] ?? _vi[key] ?? key;
  }

  /// Chuỗi có tham số: t2('unfinished_banner', {'n': '3', 'list': 'a, b'})
  static String t2(String key, Map<String, String> args) {
    var s = t(key);
    args.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  // ---------------- Tiếng Việt ----------------
  static const Map<String, String> _vi = {
    // Tabs
    'tab_tasks': 'Task',
    'tab_pomodoro': 'Pomodoro',
    'tab_saves': 'Save',
    'tab_ideas': 'Ý tưởng',
    'tab_journal': 'Nhật ký',
    'tab_schedule': 'Lịch',
    'tab_report': 'Báo cáo',

    // Chung
    'save': 'Lưu',
    'cancel': 'Hủy',
    'close': 'Đóng',
    'delete': 'Xóa',
    'add': 'Thêm',
    'edit': 'Sửa',
    'ok': 'OK',
    'today': 'Hôm nay',
    'date': 'Ngày',
    'time': 'Giờ',
    'all_day': 'Cả ngày',
    'search_tooltip': 'Tìm kiếm toàn app',
    'settings': 'Cài đặt',
    'review_tooltip': 'Review cuối ngày (chốt sổ)',

    // Task
    'tasks_title': 'Task',
    'new_task': 'Task mới',
    'task_detail': 'Chi tiết task',
    'filter_all': 'Tất cả',
    'status_todo': 'Chưa làm',
    'status_doing': 'Đang làm',
    'status_done': 'Done',
    'status_label': 'Trạng thái: ',
    'no_tasks': 'Chưa có task nào. Bấm "Task mới" để tạo.',
    'field_title': 'Tên task *',
    'field_desc': 'Mô tả',
    'field_context': 'Bối cảnh / hệ thống liên quan',
    'field_blocker': 'Vướng mắc',
    'field_direction': 'Hướng giải quyết dự kiến',
    'deadline': 'Deadline: ',
    'pick_date': 'Chọn ngày',
    'remove_deadline': 'Bỏ deadline (gỡ khỏi Lịch)',
    'remove_time': 'Bỏ giờ (để cả ngày)',
    'remind_deadline': 'Nhắc deadline này',
    'remind_on_time': 'Tới giờ sẽ nhắc 10 phút/lần tới khi Done',
    'remind_on_day': 'Tới ngày sẽ nhắc 10 phút/lần tới khi Done',
    'remind_off': 'Chỉ hiện trên Lịch, không nhắc',
    'copy_ai_tooltip': 'Copy thông tin task cho AI',
    'copied_ai': 'Đã copy prompt — dán vào AI chat để xin gợi ý.',
    'worklog_title': 'Nhật ký làm việc (dữ liệu cho báo cáo tuần)',
    'worklog_hint': 'Hôm nay đã làm gì cho task này...',
    'log_btn': 'Ghi',
    'updated': 'cập nhật',
    'has_blocker': 'có vướng mắc',
    'cycle_status_tooltip': 'Bấm để đổi trạng thái',
    'delete_task_q': 'Xóa task?',

    // Banner
    'unfinished_banner':
        'Bạn còn {n} task chưa chuyển sang Done: {list}',
    'view_tasks': 'Xem task',
    'hide': 'Ẩn',

    // Pomodoro
    'pomodoro_title': 'Pomodoro',
    'phase_focus': 'Tập trung',
    'phase_short': 'Nghỉ ngắn',
    'phase_long': 'Nghỉ dài',
    'start': 'Bắt đầu',
    'pause': 'Tạm dừng',
    'reset': 'Đặt lại',
    'skip': 'Bỏ qua',
    'streak': 'Chuỗi',
    'pomo_config': 'Cấu hình Pomodoro',
    'pomo_config_tooltip': 'Cấu hình thời lượng',
    'pomo_focus_min': 'Phiên tập trung (phút)',
    'pomo_short_min': 'Nghỉ ngắn (phút)',
    'pomo_long_min': 'Nghỉ dài (phút)',
    'pomo_cycles': 'Số phiên trước khi nghỉ dài',
    'pomo_task_label': 'Đang làm task nào? (tùy chọn)',
    'pomo_task_help':
        'Chọn task để phiên focus tự ghi 1 dòng nhật ký cho task đó',
    'pomo_no_task': '— Không gắn task —',
    'pomo_today': 'Hôm nay: {c} phiên · {m} phút tập trung',
    'pomo_done_notif': 'WorkSave — Hết giờ tập trung 🍅',
    'pomo_break_notif': 'WorkSave — Hết giờ nghỉ',
    'pomo_done_body': 'Nghỉ một chút rồi quay lại nhé!',
    'pomo_break_body': 'Bắt đầu phiên tập trung tiếp theo.',
    'pomo_session_log': 'Pomodoro {m} phút',

    // Ý tưởng / Nhật ký
    'ideas_title': 'Ý tưởng',
    'idea_hint': 'Ghi nhanh ý tưởng...',
    'no_ideas': 'Chưa có ý tưởng nào.',
    'edit_idea': 'Sửa ý tưởng',
    'to_task_tooltip': 'Chuyển thành Task',
    'journal_title': 'Nhật ký',
    'journal_sub':
        'Đang nghĩ gì cứ ghi vào đây — khác với log của task ("đã làm gì"). Mẹo: Ctrl+Shift+Space ghi nhanh từ bất kỳ đâu.',
    'journal_hint': 'Đang nghĩ gì? Ghi tự do...',
    'no_journal': 'Chưa có ghi chép nào.',
    'edit_journal': 'Sửa ghi chép',

    // Lịch
    'schedule_title': 'Lịch',
    'schedule_hint': 'Bấm vào ô ngày để thêm / sửa việc',
    'day_hint': 'Ngày này cần làm gì?',
    'no_day_items': 'Chưa có việc nào trong ngày này.',
    'jump_month': 'Nhảy tới tháng',
    'prev_month': 'Tháng trước',
    'next_month': 'Tháng sau',
    'confirmed_done': 'Đã xác nhận xong — không nhắc nữa',
    'remind_muted': 'Đã tắt nhắc — chỉ hiện trên lịch',
    'deadline_nag': 'Deadline task — nhắc 10 phút/lần khi tới hạn',
    'item_nag': 'Sẽ nhắc 10 phút/lần khi tới hạn',
    'confirm_done_tooltip': 'Xác nhận xong (tắt nhắc)',
    'unconfirm_tooltip': 'Bấm để nhắc lại',
    'mute_tooltip': 'Tắt nhắc mục này',
    'unmute_tooltip': 'Bật nhắc mục này',
    'edit_in_task':
        'Mục này là deadline của task — sửa nội dung/ngày trong tab Task. Ở đây chỉ xác nhận xong hoặc xóa.',

    'notif_title_deadline': 'WorkSave — Deadline task',
    'notif_title_schedule': 'WorkSave — Lịch nhắc',
    'notif_early': '⏳ Còn {d} nữa tới hạn',
    'dur_under_minute': 'chưa tới 1 phút',
    'dur_minutes': '{n} phút',
    'dur_hours': '{n} giờ',
    'dur_days': '{n} ngày',
    'notif_now': '🔔 Đã tới hạn',
    'notif_overdue': '⚠ Đã quá hạn {d}',
    'notif_repeat': '(nhắc lại mỗi {n} phút tới khi bạn xác nhận xong)',
    'reminder_section': 'Cách nhắc lịch',
    'reminder_note':
        'Việc có đặt giờ thì nhắc theo giờ đó; việc để "Cả ngày" thì nhắc vào giờ đầu ngày bên dưới.',
    'day_start_time': 'Giờ nhắc đầu ngày (HH:mm)',
    'day_start_help': 'Áp dụng cho việc không đặt giờ cụ thể',
    'lead_minutes': 'Báo trước (phút)',
    'lead_help': 'Nhắc lần đầu trước giờ hẹn bao nhiêu phút',
    'nag_minutes': 'Nhắc lại mỗi (phút)',
    'nag_help': 'Lặp lại cho tới khi bạn xác nhận xong',
    'item_nag_time': 'Báo trước {lead} phút, sau đó mỗi {nag} phút tới khi xong',

    // Save trạng thái
    'save_doing': 'Đang làm dở',
    'save_next': 'Việc tiếp theo',
    'save_remember': 'Cần nhớ',
    'save_latest': 'Save mới nhất',
    'save_manual': 'Save thủ công',
    'save_ack': 'Đã nhớ, bắt đầu làm việc',
    'no_saves': 'Chưa có save nào.',
    'save_badge_ai': '🤖 AI vừa tổng hợp',
    'save_badge_cached': '🤖 Bản AI đã tổng hợp hôm nay (không gọi lại API)',
    'save_badge_local': '📋 Tổng hợp local (không dùng AI)',
    'ai_summary_title': 'Tổng hợp T6 bằng AI',
    'ai_generated_today': 'Đã gen hôm nay ✓',
    'ai_friday_ready':
        'Hôm nay là thứ 6! Bấm nút để AI đọc các task chưa xong và tự viết bản save.',
    'ai_friday_cached':
        'Hôm nay đã tổng hợp rồi — bấm nút sẽ dùng lại bản đã gen, không tốn quota.',
    'ai_not_friday':
        'AI chỉ tự tổng hợp vào thứ 6 (mỗi tuần đúng 1 lần để tiết kiệm quota).',
    'ai_summarise_btn': 'Tổng hợp việc còn dở & Save',
    'ai_working': 'Đang tổng hợp...',

    // Báo cáo
    'report_hint':
        'Prompt bên dưới được tổng hợp từ nhật ký các task trong tuần. Bấm Copy rồi dán vào AI chat.',
    'report_copy_btn': 'Copy prompt',
    'report_copied': 'Đã copy prompt báo cáo tuần vào clipboard.',
    'report_unfinished':
        'Còn {n} task chưa Done — kiểm tra lại trước khi gửi báo cáo: {list}',
    'refresh': 'Làm mới',

    // Lịch & sao lưu
    'month_year': 'Tháng {m} năm {y}',
    'pick_time_help': 'Giờ nhắc (bấm Hủy = cả ngày)',
    'converted_to_task': '✅ Đã chuyển "{t}" thành task — xem ở tab Task.',
    'backup_ok': '✅ Đã sao lưu toàn bộ dữ liệu ra {p}',
    'backup_fail': 'Lỗi sao lưu / khôi phục: {e}',
    'restore_confirm_title': '⚠ Khôi phục từ backup?',
    'restore_confirm_body':
        'Toàn bộ dữ liệu hiện tại sẽ bị GHI ĐÈ bằng nội dung file:\n{p}\n\nTiếp tục?',
    'restore_confirm_btn': 'Ghi đè & khôi phục',
    'restore_done_title': '✅ Khôi phục xong',
    'restore_done_body':
        'Dữ liệu đã được nạp lại. Khởi động lại app để mọi màn hình hiển thị đúng.',

    // Lời chúc mừng
    'praise_task': 'Đã xong "{t}"!',
    'praise_pomodoro': 'Xong 1 pomodoro {m} phút!',
    'praise_review_done': 'Hoàn thành {n} task hôm nay — nghỉ ngơi xứng đáng!',
    'praise_review_log': 'Đã chốt sổ hôm nay với {n} dòng nhật ký!',

    // Chấm công
    'tab_attendance': 'Chấm công',
    'attendance_title': 'Nhắc chấm công',
    'attendance_hint':
        'Đặt giờ nhắc chấm công hằng ngày, bật/tắt bất cứ lúc nào. Hôm nào OT thì thêm ngoại lệ cho riêng ngày đó.',
    'attendance_in': 'Chấm công vào',
    'attendance_out': 'Chấm công ra',
    'attendance_today': 'Hôm nay',
    'attendance_none_today':
        'Hôm nay không có mốc chấm công nào (đã tắt, không đúng thứ, hoặc đã đặt nghỉ).',
    'attendance_pending': 'Chưa xác nhận — sẽ nhắc tới khi bạn bấm xác nhận',
    'attendance_done': 'Đã chấm công ✓',
    'attendance_confirm': 'Xác nhận đã chấm công',
    'attendance_undo': 'Bỏ xác nhận',
    'attendance_ot_tag': 'ngoại lệ',
    'attendance_daily_section': 'Giờ nhắc hằng ngày',
    'attendance_override_section': 'Ngoại lệ theo ngày (OT / nghỉ)',
    'attendance_override_hint':
        'Ngoại lệ đè lên giờ mặc định của đúng ngày đó — dùng khi OT hoặc nghỉ phép.',
    'attendance_no_override': 'Chưa có ngoại lệ nào sắp tới.',
    'attendance_add_override': 'Thêm ngoại lệ',
    'attendance_override_title': 'Ngoại lệ chấm công cho một ngày',
    'attendance_skip': 'Không nhắc',
    'attendance_skip_title': 'Hôm đó không nhắc',
    'attendance_skip_sub': 'Dùng khi nghỉ phép, đi công tác',
    'attendance_note': 'Ghi chú (VD: OT nghiệm thu tuyến)',
    'attendance_notif_title': 'WorkSave — Chấm công',
    'praise_attendance': 'Đã {k}!',

    // Cá nhân hóa
    'user_name': 'Tên của bạn',
    'user_name_help':
        'Dùng để xưng hô trong thông báo và lời chúc mừng. Để trống cũng được.',
    'friend': 'bạn',
    'cheer_1': '🎉 {name} giỏi quá!',
    'cheer_2': '🔥 Quá đỉnh {name}!',
    'cheer_3': '🏆 Tuyệt vời {name}!',
    'cheer_4': '💪 {name} đúng là chiến thần năng suất!',
    'cheer_5': '⭐ Xuất sắc {name}!',
    'cheer_6': '🎊 Thêm một chiến thắng cho {name}!',

    'api_test_btn': 'Kiểm tra kết nối & model',
    'api_key_missing': 'Chưa nhập API key.',
    'api_test_no_model':
        'Key hợp lệ nhưng không có model nào dùng được cho sinh nội dung.',
    'api_test_ok': 'Kết nối OK — key dùng được {n} model, đang chọn "{m}".',
    'api_test_switched': 'Model cũ không còn khả dụng, đã đổi sang "{m}".',
    'api_test_fail': 'Không kết nối được: {e}',

    // Chẩn đoán nhắc
    'diag_btn': 'Chẩn đoán nhắc',
    'diag_title': '🩺 Chẩn đoán nhắc',
    'diag_running': 'Vòng lặp đang chạy',
    'diag_last_run': 'Lần kiểm tra gần nhất',
    'diag_last_fired': 'Lần bắn gần nhất',
    'diag_last_error': 'Lỗi gần nhất',
    'diag_config': 'Cấu hình',
    'diag_attendance': 'Chấm công hôm nay',
    'diag_attendance_off': 'Đang TẮT cả hai mốc — vào tab Chấm công để bật.',
    'diag_schedule': 'Mục lịch chưa xác nhận (sắp tới / quá hạn)',
    'diag_schedule_empty':
        'Không có mục nào đang chờ nhắc (đã xác nhận hết, hoặc đã tắt nhắc).',
    'diag_test_btn': 'Bắn thử thông báo',
    'diag_test_title': 'WorkSave — Thử thông báo',
    'diag_test_body': 'Nếu bạn thấy dòng này thì kênh thông báo đang hoạt động.',
    'diag_test_sent': 'Đã gửi. Không thấy gì hiện lên nghĩa là Windows đang chặn thông báo của app.',
    'diag_test_failed': 'Không gửi được thông báo: {e}',

    'nudge_tone': 'Giọng câu nhắc chấm công',
    'nudge_tone_help':
        'Áp dụng cho thông báo chấm công. Đổi giọng thì kho câu được sinh lại.',
    'tone_gentle': 'Nhẹ nhàng',
    'tone_sassy': 'Cà khịa',
    'tone_savage': 'Gắt',
    'nudge_tone_changed': 'Đã đổi sang giọng "{t}". Đang sinh kho câu mới...',

    'attendance_test_btn': 'Thử nhắc',
    'attendance_status_off':
        '⚠ Mốc này đang TẮT — gạt công tắc bên phải mới nhắc.',
    'attendance_status_no_weekday': '⚠ Chưa chọn thứ nào nên sẽ không nhắc.',
    'attendance_status_none': '⚠ Không có lần nhắc nào trong 14 ngày tới.',
    'attendance_status_next': 'Lần nhắc kế tiếp: {t}',
    'attendance_status_active':
        '🔔 Đang nhắc từ {t} hôm nay — xác nhận để dừng.',
    'attendance_confirm_short': 'Đã chấm công',

    // Hộp thư thông báo
    'notif_center': 'Thông báo',
    'notif_empty': 'Chưa có thông báo nào.',
    'notif_mark_all': 'Đánh dấu đã đọc',
    'notif_clear': 'Xóa hết',
    'notif_due_at': 'Tới hạn {t}',
    'notif_kind_info': 'Thông tin',

    'hotkey_failed_title': 'Không đăng ký được phím tắt',
    'hotkey_failed_body':
        '{k} đang bị app khác chiếm. Dùng menu chuột phải ở khay hệ thống để ghi nhanh.',
    'diag_hotkey': 'Phím tắt ghi nhanh',
    'diag_hotkey_blocked': 'Bị app khác chiếm',

    // Settings
    'settings_title': 'Cài đặt',
    'api_key': 'Google AI Studio API key',
    'api_key_hint': 'Dán key từ aistudio.google.com/apikey',
    'model': 'Model',
    'model_help':
        'Free: gemini-2.5-flash (mặc định) hoặc gemini-2.5-flash-lite (quota/ngày cao hơn)',
    'key_note':
        'Key chỉ lưu trong máy bạn (SQLite local), app chỉ gọi API đúng 1 lần vào thứ 6 khi tổng hợp bản Save.',
    'review_time': 'Giờ review cuối ngày (HH:mm)',
    'review_time_help':
        'Tới giờ này app sẽ tự bật hộp "hôm nay đã làm gì?" (1 lần/ngày)',
    'autostart': 'Mở cùng Windows',
    'autostart_sub': 'Tự chạy khi mở máy để noti và review hoạt động',
    'language': 'Ngôn ngữ / Language',
    'backup_section': 'Sao lưu & khôi phục',
    'backup_note':
        'Xuất toàn bộ dữ liệu (task, log, ý tưởng, nhật ký, lịch, save, settings) ra 1 file JSON. Cài lại app/máy -> Khôi phục từ file là đủ.',
    'export_btn': 'Sao lưu ra file...',
    'import_btn': 'Khôi phục từ file...',
    'tabs_section': 'Thứ tự tab',
    'tabs_note':
        'Sắp xếp lại thứ tự các tab trên thanh trái theo thói quen của bạn.',
    'edit_tabs_btn': 'Sửa thứ tự tab...',
    'tab_order_title': 'Sửa thứ tự tab',
    'tab_order_help':
        'Dùng mũi tên để đưa tab lên / xuống, hoặc kéo thả. Bấm Lưu để áp dụng.',
    'move_up': 'Lên',
    'move_down': 'Xuống',
    'reset_default': 'Về mặc định',
    'tab_order_saved': 'Đã lưu thứ tự tab.',

    // Review
    'review_title': 'Review cuối ngày',
    'review_sub':
        'Hôm nay đã làm gì? Ghi 1 dòng cho mỗi task (dữ liệu cho báo cáo tuần), task nào xong thì tick Done.',
    'review_none': '🎉 Không còn task nào dở dang — hôm nay quá ổn!',
    'review_skip': 'Hôm nay bỏ qua',
    'review_submit': 'Chốt sổ hôm nay',
    'done_q': 'Done?',

    // Search
    'search_title': '🔍 Tìm kiếm toàn app',
    'search_hint':
        'Gõ ít nhất 2 ký tự... (tìm trong task, log, ý tưởng, nhật ký, save, lịch)',
    'search_empty': 'Kết quả sẽ hiện ở đây.',
    'search_none': 'Không tìm thấy gì.',

    // Quick capture
    'quick_title': '⚡ Ghi nhanh',
    'quick_hint': 'Gõ xong nhấn Enter...',
    'saved_journal': '✍ Đã ghi vào Nhật ký.',
    'saved_idea': '💡 Đã lưu vào Ý tưởng.',

    // Tray
    'tray_show': 'Mở WorkSave',
    'tray_capture': 'Ghi nhanh  (Ctrl+Shift+Space)',
    'tray_exit': 'Thoát hẳn',
    'tray_tooltip': 'WorkSave — đang chạy nền',
  };

  // ---------------- English ----------------
  static const Map<String, String> _en = {
    'tab_tasks': 'Tasks',
    'tab_pomodoro': 'Pomodoro',
    'tab_saves': 'Saves',
    'tab_ideas': 'Ideas',
    'tab_journal': 'Journal',
    'tab_schedule': 'Calendar',
    'tab_report': 'Report',

    'save': 'Save',
    'cancel': 'Cancel',
    'close': 'Close',
    'delete': 'Delete',
    'add': 'Add',
    'edit': 'Edit',
    'ok': 'OK',
    'today': 'Today',
    'date': 'Date',
    'time': 'Time',
    'all_day': 'All day',
    'search_tooltip': 'Search everything',
    'settings': 'Settings',
    'review_tooltip': 'End-of-day review',

    'tasks_title': 'Tasks',
    'new_task': 'New task',
    'task_detail': 'Task details',
    'filter_all': 'All',
    'status_todo': 'To do',
    'status_doing': 'In progress',
    'status_done': 'Done',
    'status_label': 'Status: ',
    'no_tasks': 'No tasks yet. Click "New task" to create one.',
    'field_title': 'Task name *',
    'field_desc': 'Description',
    'field_context': 'Context / related systems',
    'field_blocker': 'Blocker',
    'field_direction': 'Planned approach',
    'deadline': 'Deadline: ',
    'pick_date': 'Pick a date',
    'remove_deadline': 'Remove deadline (also from Calendar)',
    'remove_time': 'Clear time (make it all-day)',
    'remind_deadline': 'Remind me about this deadline',
    'remind_on_time': 'At that time, reminds every 10 min until Done',
    'remind_on_day': 'On that day, reminds every 10 min until Done',
    'remind_off': 'Shown on Calendar only, no reminders',
    'copy_ai_tooltip': 'Copy task details for AI',
    'copied_ai': 'Prompt copied — paste it into an AI chat for suggestions.',
    'worklog_title': 'Work log (feeds the weekly report)',
    'worklog_hint': 'What did you do for this task today...',
    'log_btn': 'Log',
    'updated': 'updated',
    'has_blocker': 'has blocker',
    'cycle_status_tooltip': 'Click to change status',
    'delete_task_q': 'Delete task?',

    'unfinished_banner': 'You still have {n} task(s) not marked Done: {list}',
    'view_tasks': 'View tasks',
    'hide': 'Hide',

    'pomodoro_title': 'Pomodoro',
    'phase_focus': 'Focus',
    'phase_short': 'Short break',
    'phase_long': 'Long break',
    'start': 'Start',
    'pause': 'Pause',
    'reset': 'Reset',
    'skip': 'Skip',
    'streak': 'Streak',
    'pomo_config': 'Pomodoro settings',
    'pomo_config_tooltip': 'Configure durations',
    'pomo_focus_min': 'Focus session (minutes)',
    'pomo_short_min': 'Short break (minutes)',
    'pomo_long_min': 'Long break (minutes)',
    'pomo_cycles': 'Sessions before a long break',
    'pomo_task_label': 'Which task are you on? (optional)',
    'pomo_task_help':
        'Pick a task and each focus session logs a line for it automatically',
    'pomo_no_task': '— No task —',
    'pomo_today': 'Today: {c} session(s) · {m} focus minutes',
    'pomo_done_notif': 'WorkSave — Focus time is up 🍅',
    'pomo_break_notif': 'WorkSave — Break is over',
    'pomo_done_body': 'Take a short break, then come back!',
    'pomo_break_body': 'Time to start the next focus session.',
    'pomo_session_log': 'Pomodoro {m} minutes',

    'ideas_title': 'Ideas',
    'idea_hint': 'Jot down an idea...',
    'no_ideas': 'No ideas yet.',
    'edit_idea': 'Edit idea',
    'to_task_tooltip': 'Convert to task',
    'journal_title': 'Journal',
    'journal_sub':
        'Write down what you are thinking — different from task logs ("what you did"). Tip: Ctrl+Shift+Space captures from anywhere.',
    'journal_hint': 'What are you thinking? Write freely...',
    'no_journal': 'No entries yet.',
    'edit_journal': 'Edit entry',

    'schedule_title': 'Calendar',
    'schedule_hint': 'Click a day cell to add / edit items',
    'day_hint': 'What needs doing on this day?',
    'no_day_items': 'Nothing scheduled for this day.',
    'jump_month': 'Jump to month',
    'prev_month': 'Previous month',
    'next_month': 'Next month',
    'confirmed_done': 'Confirmed done — no more reminders',
    'remind_muted': 'Reminders off — shown on calendar only',
    'deadline_nag': 'Task deadline — reminds every 10 min when due',
    'item_nag': 'Reminds every 10 min when due',
    'confirm_done_tooltip': 'Confirm done (stop reminders)',
    'unconfirm_tooltip': 'Click to remind again',
    'mute_tooltip': 'Turn off reminders for this item',
    'unmute_tooltip': 'Turn on reminders for this item',
    'edit_in_task':
        'This is a task deadline — edit its text/date in the Tasks tab. Here you can only confirm or delete it.',

    'notif_title_deadline': 'WorkSave — Task deadline',
    'notif_title_schedule': 'WorkSave — Reminder',
    'notif_early': '⏳ Due in {d}',
    'dur_under_minute': 'less than a minute',
    'dur_minutes': '{n} min',
    'dur_hours': '{n} h',
    'dur_days': '{n} d',
    'notif_now': '🔔 Due now',
    'notif_overdue': '⚠ Overdue by {d}',
    'notif_repeat': '(repeats every {n} minutes until you confirm it is done)',
    'reminder_section': 'Reminder behaviour',
    'reminder_note':
        'Items with a time are reminded at that time; "All day" items use the day-start time below.',
    'day_start_time': 'Day-start reminder time (HH:mm)',
    'day_start_help': 'Used for items without a specific time',
    'lead_minutes': 'Remind ahead (minutes)',
    'lead_help': 'How early the first reminder fires',
    'nag_minutes': 'Repeat every (minutes)',
    'nag_help': 'Keeps repeating until you confirm it is done',
    'item_nag_time': '{lead} min early, then every {nag} min until done',

    // Saves
    'save_doing': 'In progress',
    'save_next': 'Next up',
    'save_remember': 'Remember',
    'save_latest': 'Latest save',
    'save_manual': 'Save manually',
    'save_ack': 'Got it, back to work',
    'no_saves': 'No saves yet.',
    'save_badge_ai': '🤖 Freshly summarised by AI',
    'save_badge_cached': '🤖 AI summary from today (no extra API call)',
    'save_badge_local': '📋 Local summary (no AI)',
    'ai_summary_title': 'Friday AI summary',
    'ai_generated_today': 'Generated today ✓',
    'ai_friday_ready':
        "It's Friday! Let the AI read your open tasks and write the save for you.",
    'ai_friday_cached':
        "Already summarised today — this reuses it and costs no quota.",
    'ai_not_friday':
        'The AI summary runs on Fridays only (once a week, to save quota).',
    'ai_summarise_btn': 'Summarise open work & save',
    'ai_working': 'Summarising...',

    // Report
    'report_hint':
        'The prompt below is built from this week\'s task logs. Copy it into an AI chat.',
    'report_copy_btn': 'Copy prompt',
    'report_copied': 'Weekly report prompt copied to clipboard.',
    'report_unfinished':
        '{n} task(s) still not Done — check before sending the report: {list}',
    'refresh': 'Refresh',

    // Calendar & backup
    'month_year': '{m}/{y}',
    'pick_time_help': 'Reminder time (Cancel = all day)',
    'converted_to_task': '✅ "{t}" is now a task — see the Tasks tab.',
    'backup_ok': '✅ Everything backed up to {p}',
    'backup_fail': 'Backup / restore error: {e}',
    'restore_confirm_title': '⚠ Restore from backup?',
    'restore_confirm_body':
        'All current data will be OVERWRITTEN with the contents of:\n{p}\n\nContinue?',
    'restore_confirm_btn': 'Overwrite & restore',
    'restore_done_title': '✅ Restore complete',
    'restore_done_body':
        'Your data has been reloaded. Restart the app so every screen picks it up.',

    // Praise
    'praise_task': 'Finished "{t}"!',
    'praise_pomodoro': 'That\'s one {m}-minute pomodoro done!',
    'praise_review_done': 'Closed out {n} task(s) today — well earned rest!',
    'praise_review_log': 'Day wrapped up with {n} log line(s)!',

    // Attendance
    'tab_attendance': 'Attendance',
    'attendance_title': 'Attendance reminders',
    'attendance_hint':
        'Set your daily clock-in/out reminder times and toggle them any time. Working overtime? Add a one-off override for that day.',
    'attendance_in': 'Clock in',
    'attendance_out': 'Clock out',
    'attendance_today': 'Today',
    'attendance_none_today':
        'Nothing scheduled today (turned off, wrong weekday, or set as a day off).',
    'attendance_pending': 'Not confirmed — reminders continue until you confirm',
    'attendance_done': 'Clocked ✓',
    'attendance_confirm': 'Confirm clocked',
    'attendance_undo': 'Undo confirmation',
    'attendance_ot_tag': 'override',
    'attendance_daily_section': 'Daily reminder times',
    'attendance_override_section': 'Per-day overrides (overtime / days off)',
    'attendance_override_hint':
        'An override replaces the default time on that day — use it for overtime or leave.',
    'attendance_no_override': 'No upcoming overrides.',
    'attendance_add_override': 'Add override',
    'attendance_override_title': 'Attendance override for one day',
    'attendance_skip': 'No reminder',
    'attendance_skip_title': 'No reminder that day',
    'attendance_skip_sub': 'For leave or off-site days',
    'attendance_note': 'Note (e.g. overtime for line testing)',
    'attendance_notif_title': 'WorkSave — Attendance',
    'praise_attendance': '{k} done!',

    // Personalisation
    'user_name': 'Your name',
    'user_name_help':
        'Used to address you in notifications and cheers. Leaving it blank is fine.',
    'friend': 'friend',
    'cheer_1': '🎉 Nicely done {name}!',
    'cheer_2': '🔥 Crushing it {name}!',
    'cheer_3': '🏆 Brilliant {name}!',
    'cheer_4': '💪 {name}, productivity champion!',
    'cheer_5': '⭐ Excellent {name}!',
    'cheer_6': '🎊 Another win for {name}!',

    'api_test_btn': 'Test connection & model',
    'api_key_missing': 'No API key entered yet.',
    'api_test_no_model':
        'The key works but no model is available for content generation.',
    'api_test_ok': 'Connection OK — {n} models available, using "{m}".',
    'api_test_switched': 'The old model is gone; switched to "{m}".',
    'api_test_fail': 'Could not connect: {e}',

    // Reminder diagnostics
    'diag_btn': 'Reminder diagnostics',
    'diag_title': '🩺 Reminder diagnostics',
    'diag_running': 'Loop running',
    'diag_last_run': 'Last check',
    'diag_last_fired': 'Last fired',
    'diag_last_error': 'Last error',
    'diag_config': 'Configuration',
    'diag_attendance': 'Attendance today',
    'diag_attendance_off': 'Both slots are OFF — enable them in the Attendance tab.',
    'diag_schedule': 'Unconfirmed calendar items (upcoming / overdue)',
    'diag_schedule_empty':
        'Nothing waiting for a reminder (all confirmed, or reminders muted).',
    'diag_test_btn': 'Send test notification',
    'diag_test_title': 'WorkSave — Test notification',
    'diag_test_body': 'If you can read this, the notification channel works.',
    'diag_test_sent': 'Sent. If nothing appeared, Windows is blocking the app notifications.',
    'diag_test_failed': 'Could not send the notification: {e}',

    'nudge_tone': 'Attendance nudge tone',
    'nudge_tone_help':
        'Applies to attendance notifications. Changing it regenerates the pool.',
    'tone_gentle': 'Gentle',
    'tone_sassy': 'Sassy',
    'tone_savage': 'Savage',
    'nudge_tone_changed': 'Switched to "{t}". Generating a new pool...',

    'attendance_test_btn': 'Test',
    'attendance_status_off':
        '⚠ This slot is OFF — flip the switch on the right to enable it.',
    'attendance_status_no_weekday': '⚠ No weekday selected, so it will never fire.',
    'attendance_status_none': '⚠ No reminder due in the next 14 days.',
    'attendance_status_next': 'Next reminder: {t}',
    'attendance_status_active':
        '🔔 Reminding since {t} today — confirm to stop.',
    'attendance_confirm_short': 'Clocked',

    // Notification centre
    'notif_center': 'Notifications',
    'notif_empty': 'No notifications yet.',
    'notif_mark_all': 'Mark all read',
    'notif_clear': 'Clear all',
    'notif_due_at': 'Due at {t}',
    'notif_kind_info': 'Info',

    'hotkey_failed_title': 'Could not register the hotkey',
    'hotkey_failed_body':
        '{k} is taken by another app. Use the tray right-click menu for quick capture.',
    'diag_hotkey': 'Quick-capture hotkey',
    'diag_hotkey_blocked': 'Taken by another app',

    'settings_title': 'Settings',
    'api_key': 'Google AI Studio API key',
    'api_key_hint': 'Paste the key from aistudio.google.com/apikey',
    'model': 'Model',
    'model_help':
        'Free: gemini-2.5-flash (default) or gemini-2.5-flash-lite (higher daily quota)',
    'key_note':
        'The key stays on your machine (local SQLite); the app calls the API only once, on Friday, to summarise your Save.',
    'review_time': 'End-of-day review time (HH:mm)',
    'review_time_help':
        'At this time the app opens the "what did you do today?" box (once a day)',
    'autostart': 'Launch with Windows',
    'autostart_sub': 'Start on boot so reminders and reviews keep working',
    'language': 'Ngôn ngữ / Language',
    'backup_section': 'Backup & restore',
    'backup_note':
        'Export everything (tasks, logs, ideas, journal, calendar, saves, settings) to one JSON file. Reinstalled the app or the PC? Restore from that file.',
    'export_btn': 'Back up to file...',
    'import_btn': 'Restore from file...',
    'tabs_section': 'Tab order',
    'tabs_note': 'Rearrange the tabs in the left rail to match your habits.',
    'edit_tabs_btn': 'Edit tab order...',
    'tab_order_title': 'Edit tab order',
    'tab_order_help':
        'Use the arrows to move a tab up or down, or drag it. Click Save to apply.',
    'move_up': 'Up',
    'move_down': 'Down',
    'reset_default': 'Reset to default',
    'tab_order_saved': 'Tab order saved.',

    'review_title': 'End-of-day review',
    'review_sub':
        'What did you do today? Write one line per task (this feeds the weekly report) and tick Done for finished ones.',
    'review_none': '🎉 Nothing left unfinished — great day!',
    'review_skip': 'Skip today',
    'review_submit': 'Close out today',
    'done_q': 'Done?',

    'search_title': '🔍 Search everything',
    'search_hint':
        'Type at least 2 characters... (searches tasks, logs, ideas, journal, saves, calendar)',
    'search_empty': 'Results will appear here.',
    'search_none': 'Nothing found.',

    'quick_title': '⚡ Quick capture',
    'quick_hint': 'Type, then press Enter...',
    'saved_journal': '✍ Saved to Journal.',
    'saved_idea': '💡 Saved to Ideas.',

    'tray_show': 'Open WorkSave',
    'tray_capture': 'Quick capture  (Ctrl+Shift+Space)',
    'tray_exit': 'Quit',
    'tray_tooltip': 'WorkSave — running in background',
  };
}
