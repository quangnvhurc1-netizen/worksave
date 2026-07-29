import 'dart:convert';
import 'dart:math';

import '../data/repositories/repositories.dart';
import '../domain/enums.dart';
import 'gemini_service.dart';
import 'l10n.dart';
import 'user_profile.dart';

/// Sinh câu nhắc chấm công theo kiểu Duolingo: mỗi lần một câu khác nhau,
/// và đúng giọng người dùng chọn (nhẹ nhàng / cà khịa / gắt).
///
/// Không gọi API lúc bắn thông báo (chậm và tốn quota). AI sinh sẵn một kho
/// câu, app giữ trong bộ nhớ và bốc ngẫu nhiên; kho tự làm mới mỗi tuần hoặc
/// khi đổi giọng, và luôn có kho viết sẵn để dùng khi chưa có key hay mất mạng.
class NudgeService {
  const NudgeService({GeminiService gemini = const GeminiService()})
      : _gemini = gemini;

  final GeminiService _gemini;

  static const Duration _refreshAfter = Duration(days: 7);
  static const int _linesPerBucket = 10;
  static const String _namePlaceholder = '{name}';

  static final Random _random = Random();

  /// Kho câu và giọng đang dùng, giữ sẵn trong bộ nhớ để lúc bắn thông báo
  /// không phải chờ đọc DB.
  static Map<String, dynamic>? _cachedPool;
  static NudgeTone _tone = NudgeTone.sassy;
  static bool _primed = false;

  static NudgeTone get tone => _tone;

  /// Nạp giọng và kho câu vào bộ nhớ ngay khi mở app.
  Future<void> prime() async {
    _tone = await Repos.settings.nudgeTone();
    final raw = await Repos.settings.nudgePoolJson();
    final poolTone = await Repos.settings.nudgePoolTone();
    _cachedPool = (raw == null || poolTone != _tone) ? null : _decode(raw);
    _primed = true;
  }

  /// Đổi giọng: kho cũ không còn hợp nên bỏ đi và sinh lại nền.
  Future<void> setTone(NudgeTone value) async {
    _tone = value;
    _cachedPool = null;
    await Repos.settings.saveNudgeTone(value);
    await refreshIfStale(force: true);
  }

  /// Câu nhắc cho một mốc chấm công. [minutesLeft] > 0 là còn sớm, < 0 là trễ.
  /// Hoàn toàn đọc từ bộ nhớ nên không làm chậm thông báo.
  String attendanceLine(AttendanceKind kind, int minutesLeft) {
    final bucket = _bucketKey(kind, minutesLeft);
    final pool = _poolFor(bucket);
    final line = pool[_random.nextInt(pool.length)];
    return line.replaceAll(_namePlaceholder, _displayName());
  }

  String _displayName() =>
      UserProfile.hasName ? UserProfile.name.value.trim() : L10n.t('friend');

  static String _bucketKey(AttendanceKind kind, int minutesLeft) =>
      '${kind.dbValue}_${minutesLeft < 0 ? 'late' : 'soon'}';

  Map<String, dynamic>? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  List<String> _poolFor(String bucket) {
    final pool = _cachedPool;
    if (pool != null) {
      final section = pool[L10n.language.value.code];
      if (section is Map) {
        final lines = section[bucket];
        if (lines is List && lines.isNotEmpty) {
          return lines.map((line) => '$line').toList();
        }
      }
    }
    return _fallback(bucket);
  }

  /// Gọi AI sinh kho câu mới nếu quá hạn, đổi giọng, hoặc [force].
  /// Thất bại thì im lặng — kho viết sẵn vẫn dùng được.
  Future<void> refreshIfStale({bool force = false}) async {
    if (!_primed) await prime();

    final settings = Repos.settings;
    final apiKey = (await settings.geminiApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) return;

    if (!force) {
      final poolTone = await settings.nudgePoolTone();
      final generatedAt = await settings.nudgePoolDate();
      final fresh = generatedAt != null &&
          DateTime.now().difference(generatedAt) < _refreshAfter;
      if (fresh && poolTone == _tone && _cachedPool != null) return;
    }

    try {
      final generated = await _generatePool(apiKey, _tone);
      if (generated == null) return;
      await settings.saveNudgePool(jsonEncode(generated), _tone);
      _cachedPool = generated;
    } on Object {
      // Không có kho mới cũng không sao.
    }
  }

  Future<Map<String, dynamic>?> _generatePool(
      String apiKey, NudgeTone tone) async {
    final buckets = [
      for (final kind in AttendanceKind.values)
        for (final when in ['soon', 'late']) '${kind.dbValue}_$when',
    ];

    final prompt = StringBuffer()
      ..writeln(_toneBrief(tone))
      ..writeln()
      ..writeln('Sinh $_linesPerBucket câu cho MỖI nhóm dưới đây, cho cả '
          'tiếng Việt (vi) và tiếng Anh (en):')
      ..writeln('- in_soon: sắp tới giờ chấm công VÀO')
      ..writeln('- in_late: đã quá giờ chấm công VÀO mà chưa chấm')
      ..writeln('- out_soon: sắp tới giờ chấm công RA (tan làm)')
      ..writeln('- out_late: đã quá giờ chấm công RA mà chưa chấm')
      ..writeln()
      ..writeln('Yêu cầu bắt buộc:')
      ..writeln('- Mỗi câu DƯỚI 90 ký tự, có đúng một chỗ giữ tên là '
          '$_namePlaceholder.')
      ..writeln('- Được dùng emoji, tối đa 1 cái mỗi câu.')
      ..writeln('- Không lặp ý giữa các câu.')
      ..writeln('- Chỉ đá đểu chuyện quên chấm công, KHÔNG chê bai con người, '
          'ngoại hình, năng lực hay đe dọa.')
      ..writeln('- CHỈ trả về JSON thuần, không markdown, không giải thích, '
          'theo đúng cấu trúc:')
      ..writeln('{"vi":{${buckets.map((b) => '"$b":["..."]').join(',')}},'
          '"en":{${buckets.map((b) => '"$b":["..."]').join(',')}}}');

    final raw = await _gemini.generateRaw(apiKey, prompt.toString());
    if (raw == null) return null;

    final decoded =
        _decode(raw.replaceAll('```json', '').replaceAll('```', '').trim());
    if (decoded == null) return null;

    // Chỉ nhận kho đủ nhóm, tránh lưu dữ liệu nửa vời.
    for (final language in ['vi', 'en']) {
      final section = decoded[language];
      if (section is! Map) return null;
      for (final bucket in buckets) {
        final lines = section[bucket];
        if (lines is! List || lines.isEmpty) return null;
      }
    }
    return decoded;
  }

  static String _toneBrief(NudgeTone tone) => switch (tone) {
        NudgeTone.gentle =>
          'Bạn viết câu nhắc cho một app năng suất, giọng vui vẻ và thân thiện '
              'như Duolingo, động viên nhẹ nhàng.',
        NudgeTone.sassy =>
          'Bạn viết câu nhắc cho một app năng suất, giọng cà khịa hài hước như '
              'con cú Duolingo: châm chọc, hơi hờn dỗi, nhây, nhưng vẫn dễ '
              'thương và khiến người đọc bật cười rồi đi làm việc.',
        NudgeTone.savage =>
          'Bạn viết câu nhắc cho một app năng suất, giọng mỉa mai gắt và bốp '
              'chát như một người bạn thân hay đá xoáy: mỉa mai thẳng, chấm '
              'biếm mạnh, có thể dùng câu hỏi tu từ để dí. Vẫn là đùa giữa bạn '
              'bè, không xúc phạm nhân phẩm.',
      };

  // ---------------- Kho viết sẵn ----------------

  List<String> _fallback(String bucket) {
    final pools = L10n.isEn ? _en[_tone]! : _vi[_tone]!;
    return pools[bucket] ?? const ['{name}!'];
  }

  static const Map<NudgeTone, Map<String, List<String>>> _vi = {
    NudgeTone.gentle: {
      'in_soon': [
        'Chào buổi sáng {name}! Sắp tới giờ chấm công vào rồi ☀️',
        '{name} ơi, nhớ chấm công vào trước khi bắt tay vào việc nhé!',
        'Một ngày mới bắt đầu — {name} chấm công vào thôi 💪',
      ],
      'in_late': [
        '{name} ơi, quá giờ chấm công vào rồi đó!',
        'Máy chấm công vẫn đang đợi {name} kìa 👀',
        '{name} vào làm rồi mà quên chấm công phải không?',
      ],
      'out_soon': [
        'Sắp hết giờ rồi {name}, nhớ chấm công ra nhé!',
        '{name} ơi, dọn bàn và chấm công ra thôi 🎒',
        'Hôm nay vậy là đủ rồi {name} — đừng quên chấm công ra!',
      ],
      'out_late': [
        '{name} về chưa? Chấm công ra kẻo quên nhé!',
        'Quá giờ rồi {name}, chấm công ra rồi nghỉ ngơi thôi 🌙',
        '{name} ơi, còn mỗi việc chấm công ra nữa thôi!',
      ],
    },
    NudgeTone.sassy: {
      'in_soon': [
        'Sắp tới giờ rồi đó {name}, đừng để tôi phải nói lần hai 👀',
        '{name} định vào làm hay định để cái máy chấm công cô đơn?',
        'Đồng hồ chạy rồi {name}, cà phê uống sau cũng được mà.',
      ],
      'in_late': [
        'Trễ rồi {name}. Máy chấm công nó nhớ hết đấy 🙂',
        '{name} làm việc chăm ghê, chăm tới mức quên chấm công luôn.',
        'Không chấm công thì hôm nay {name} coi như vô hình nhé.',
      ],
      'out_soon': [
        'Sắp tan rồi {name}, lần này nhớ chấm công ra giùm cái 🙏',
        '{name} ơi, về thì về nhưng ghé máy chấm công một cái đã.',
        'Tôi biết {name} đang tính chuồn thẳng ra cửa đấy 👀',
      ],
      'out_late': [
        '{name} về mất rồi đúng không. Máy chấm công vẫn đứng đây.',
        'Lại quên chấm công ra rồi {name}. Bất ngờ chưa 🙃',
        'Ngày mai {name} lại đi giải trình đấy, tôi nhắc rồi nhé.',
      ],
    },
    NudgeTone.savage: {
      'in_soon': [
        'Chưa chấm công mà tính làm việc hả {name}?',
        '{name} tính để cái máy chấm công chờ tới bao giờ nữa đây?',
        'Giờ này còn chưa chấm công, {name} định lập kỷ lục gì vậy?',
      ],
      'in_late': [
        'Trễ rồi {name}. Cần tôi nhắc thêm bao nhiêu lần nữa?',
        'Chưa chấm công mà đòi tính công à {name}?',
        '{name} nhớ mọi thứ trừ cái máy chấm công, tài thật.',
      ],
      'out_soon': [
        'Sắp về rồi đó {name}, đừng lặp lại thảm họa hôm trước nhé.',
        '{name} chuẩn bị quên chấm công ra rồi phải không, quen quá.',
        'Lần này chấm công ra hẳn hoi, đừng để tôi nói tiếp {name}.',
      ],
      'out_late': [
        '{name} về rồi mà quên chấm công. Kinh điển.',
        'Lại quên nữa {name}. Cuối tháng đừng hỏi vì sao thiếu công.',
        'Tôi nhắc bao nhiêu lần rồi {name}? Chấm công ra đi.',
      ],
    },
  };

  static const Map<NudgeTone, Map<String, List<String>>> _en = {
    NudgeTone.gentle: {
      'in_soon': [
        'Morning {name}! Time to clock in soon ☀️',
        '{name}, remember to clock in before you dive in!',
        'New day, {name} — clock in and off we go 💪',
      ],
      'in_late': [
        '{name}, you are past your clock-in time!',
        'The time clock is still waiting for you, {name} 👀',
        'Started working but forgot to clock in, {name}?',
      ],
      'out_soon': [
        'Almost done {name} — do not forget to clock out!',
        '{name}, pack up and clock out 🎒',
        'That is enough for today {name} — clock out!',
      ],
      'out_late': [
        'Heading home, {name}? Clock out first!',
        'Past your time {name} — clock out and rest 🌙',
        '{name}, one last thing: clock out!',
      ],
    },
    NudgeTone.sassy: {
      'in_soon': [
        'Clock is ticking {name}, do not make me say it twice 👀',
        '{name}, are you coming in or is the time clock on its own today?',
        'Coffee can wait {name}. The clock cannot.',
      ],
      'in_late': [
        'You are late {name}. The time clock keeps receipts 🙂',
        'So hardworking {name} — too busy working to clock in.',
        'No clock-in means you were never here today, {name}.',
      ],
      'out_soon': [
        'Almost home time {name} — try clocking out this once 🙏',
        '{name}, leave if you must, but tap the clock first.',
        'I can see you eyeing the door, {name} 👀',
      ],
      'out_late': [
        'You left already {name}. The time clock is still here.',
        'Forgot to clock out again {name}. Shocking 🙃',
        'Enjoy explaining this tomorrow {name}. I did warn you.',
      ],
    },
    NudgeTone.savage: {
      'in_soon': [
        'Planning to work without clocking in, {name}?',
        'How long should the time clock keep waiting, {name}?',
        'Still not clocked in {name}. Going for a record?',
      ],
      'in_late': [
        'Late again {name}. How many reminders do you need?',
        'No clock-in but you want the hours counted, {name}?',
        '{name} remembers everything except the time clock. Impressive.',
      ],
      'out_soon': [
        'Almost out {name} — do not repeat last time.',
        'About to forget clocking out again, {name}? Classic.',
        'Clock out properly this time {name}, do not make me continue.',
      ],
      'out_late': [
        '{name} left without clocking out. Iconic.',
        'Forgot again {name}. Do not ask about your hours later.',
        'How many times now, {name}? Go clock out.',
      ],
    },
  };
}
