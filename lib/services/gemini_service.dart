import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/date_x.dart';
import '../data/repositories/repositories.dart';
import '../domain/models/task.dart';

/// Lỗi khi gọi Gemini, phân biệt hết quota với lỗi khác để xử lý riêng.
sealed class GeminiFailure implements Exception {
  const GeminiFailure(this.message);
  final String message;
}

class GeminiQuotaExceeded extends GeminiFailure {
  const GeminiQuotaExceeded(super.message);
}

class GeminiRequestFailed extends GeminiFailure {
  const GeminiRequestFailed(super.message);
}

/// Model không tồn tại / không phục vụ cho key này (HTTP 404).
/// Dòng model của Gemini đổi tên theo thế hệ nên đây là lỗi phải tự phục hồi.
class GeminiModelNotFound extends GeminiFailure {
  const GeminiModelNotFound(super.message);
}

/// Nguồn gốc của bản tổng hợp, để UI nói đúng chuyện với người dùng.
enum SummarySource { ai, aiCached, local }

class FridaySummary {
  const FridaySummary({
    required this.text,
    required this.source,
    this.warning,
  });

  final String text;
  final SummarySource source;
  final String? warning;

  bool get isFromAi =>
      source == SummarySource.ai || source == SummarySource.aiCached;
}

/// Gọi Google AI Studio để tổng hợp việc còn dở dang vào thứ 6.
///
/// Quy tắc tiết kiệm quota: chỉ gọi API vào thứ 6 và mỗi ngày một lần;
/// mọi lỗi đều rơi về bản tổng hợp local thay vì chặn người dùng.
class GeminiService {
  const GeminiService({http.Client? client}) : _client = client;
  final http.Client? _client;

  static const Duration _timeout = Duration(seconds: 45);
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models';

  bool get isFriday => DateTime.now().weekday == DateTime.friday;

  /// Thứ tự ưu tiên khi tự chọn model: bản flash mới nhất trước, vì rẻ và
  /// đủ nhanh cho các tác vụ của app.
  static const List<String> preferredModels = [
    'gemini-3.6-flash',
    'gemini-3.1-flash',
    'gemini-3-flash',
    'gemini-2.5-flash',
    'gemini-2.0-flash',
  ];

  /// Hỏi API xem key này dùng được những model nào cho generateContent.
  Future<List<String>> listModels(String apiKey) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse('$_endpoint?key=$apiKey&pageSize=200'))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw GeminiRequestFailed(
            'HTTP ${response.statusCode}: ${_extractError(response.body) ?? ''}');
      }
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic> || body['models'] is! List) {
        return const [];
      }
      final models = <String>[];
      for (final entry in body['models'] as List) {
        if (entry is! Map) continue;
        final methods = entry['supportedGenerationMethods'];
        if (methods is! List || !methods.contains('generateContent')) continue;
        final name = '${entry['name']}'.replaceFirst('models/', '');
        models.add(name);
      }
      return models;
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Chọn model dùng được: ưu tiên theo [preferredModels], sau đó bất kỳ bản
  /// flash nào, cuối cùng là model đầu tiên khả dụng.
  Future<String?> resolveUsableModel(String apiKey) async {
    final available = await listModels(apiKey);
    if (available.isEmpty) return null;

    for (final candidate in preferredModels) {
      if (available.contains(candidate)) return candidate;
    }
    final flash = available.where((m) =>
        m.contains('flash') &&
        !m.contains('image') &&
        !m.contains('tts') &&
        !m.contains('live'));
    return flash.isNotEmpty ? flash.first : available.first;
  }

  /// Gọi model đang chọn; nếu model đó không còn tồn tại thì tự tìm model
  /// khác, lưu lại và thử lại một lần.
  Future<String> _generateWithAutoModel(String apiKey, String prompt) async {
    final model = await Repos.settings.geminiModel();
    try {
      return await _generate(apiKey, model, prompt);
    } on GeminiModelNotFound {
      final resolved = await resolveUsableModel(apiKey);
      if (resolved == null || resolved == model) rethrow;
      await Repos.settings.saveGeminiModel(resolved);
      return _generate(apiKey, resolved, prompt);
    }
  }

  Future<FridaySummary> buildFridaySummary({bool force = false}) async {
    final unfinished = await Repos.tasks.unfinished();
    if (unfinished.isEmpty) {
      return const FridaySummary(
        text: 'Không còn task nào dở dang. Tuần sau bắt đầu mới hoàn toàn 🎉',
        source: SummarySource.local,
      );
    }

    final localText = _buildLocalSummary(unfinished);
    final settings = Repos.settings;

    if (!force && await settings.isFridaySummaryGeneratedToday()) {
      final cached = await settings.cachedFridaySummary();
      if (cached != null) {
        return FridaySummary(
            text: cached.text, source: SummarySource.aiCached);
      }
    }

    if (!force && !isFriday) {
      final cached = await settings.cachedFridaySummary();
      if (cached != null) {
        return FridaySummary(
          text: cached.text,
          source: SummarySource.aiCached,
          warning: 'Hôm nay không phải thứ 6 — đang hiển thị bản AI đã tổng '
              'hợp ngày ${cached.date}.',
        );
      }
      return FridaySummary(
        text: localText,
        source: SummarySource.local,
        warning: 'AI chỉ tự tổng hợp vào thứ 6. Đây là bản liệt kê local.',
      );
    }

    final apiKey = (await settings.geminiApiKey())?.trim() ?? '';
    if (apiKey.isEmpty) {
      return FridaySummary(
        text: localText,
        source: SummarySource.local,
        warning: 'Chưa có API key. Vào Settings (⚙) dán key từ '
            'aistudio.google.com/apikey.',
      );
    }

    final prompt = await _buildPrompt(unfinished);

    try {
      final text = await _generateWithAutoModel(apiKey, prompt);
      await settings.saveFridaySummary(text);
      return FridaySummary(text: text, source: SummarySource.ai);
    } on GeminiQuotaExceeded catch (quota) {
      try {
        final text = await _generate(
            apiKey, SettingsRepository.fallbackGeminiModel, prompt);
        await settings.saveFridaySummary(text);
        return FridaySummary(
          text: text,
          source: SummarySource.ai,
          warning: 'Model chính hết quota, đã tự chuyển sang '
              '${SettingsRepository.fallbackGeminiModel}.',
        );
      } on GeminiFailure {
        return FridaySummary(
          text: localText,
          source: SummarySource.local,
          warning: 'Hết quota API (${quota.message}). Dùng bản liệt kê local.',
        );
      }
    } on GeminiFailure catch (failure) {
      return FridaySummary(
        text: localText,
        source: SummarySource.local,
        warning: 'Lỗi API: ${failure.message}. Dùng bản liệt kê local.',
      );
    } catch (error) {
      return FridaySummary(
        text: localText,
        source: SummarySource.local,
        warning: 'Không gọi được AI (mất mạng?): $error.',
      );
    }
  }

  String _buildLocalSummary(List<Task> tasks) {
    final buffer = StringBuffer('CÁC VIỆC CÒN DỞ DANG:\n');
    for (final task in tasks) {
      buffer.writeln('- ${task.title}');
      if (task.hasBlocker) buffer.writeln('    Vướng: ${task.blocker.trim()}');
      if (task.direction.trim().isNotEmpty) {
        buffer.writeln('    Hướng xử lý: ${task.direction.trim()}');
      }
    }
    return buffer.toString();
  }

  Future<String> _buildPrompt(List<Task> tasks) async {
    final buffer = StringBuffer()
      ..writeln('Bạn là trợ lý cá nhân. Hôm nay là thứ 6, tôi chuẩn bị nghỉ '
          'cuối tuần. Dưới đây là các task tôi CHƯA hoàn thành, kèm nhật ký '
          'gần nhất. Hãy tổng hợp thành bản "save" ngắn gọn để sáng thứ 2 '
          'đọc lại là nhớ ngay mình đang ở đâu.')
      ..writeln()
      ..writeln('Trả lời bằng tiếng Việt, ĐÚNG cấu trúc 2 phần sau, '
          'không thêm lời dẫn:')
      ..writeln('ĐANG LÀM DỞ:')
      ..writeln('- (mỗi task 1 gạch đầu dòng, nêu trạng thái + đang kẹt gì)')
      ..writeln('VIỆC TIẾP THEO:')
      ..writeln('- (các bước cụ thể nên làm đầu tuần, xếp theo ưu tiên)')
      ..writeln()
      ..writeln('=== DỮ LIỆU TASK ===');

    for (final task in tasks) {
      buffer.writeln('* ${task.title}');
      if (task.description.trim().isNotEmpty) {
        buffer.writeln('  Mô tả: ${task.description.trim()}');
      }
      if (task.hasBlocker) {
        buffer.writeln('  Vướng mắc: ${task.blocker.trim()}');
      }
      if (task.direction.trim().isNotEmpty) {
        buffer.writeln('  Hướng giải quyết: ${task.direction.trim()}');
      }
      final id = task.id;
      if (id == null) continue;
      for (final log in (await Repos.tasks.logsOf(id)).take(3)) {
        buffer.writeln('  Log ${formatDate(log.logDate)}: ${log.content.trim()}');
      }
    }
    return buffer.toString();
  }

  /// Gọi model một lần và trả về text thô. Trả null nếu lỗi — dùng cho các
  /// tính năng phụ không được phép làm hỏng trải nghiệm khi API trục trặc.
  Future<String?> generateRaw(String apiKey, String prompt) async {
    try {
      return await _generateWithAutoModel(apiKey, prompt);
    } on Object {
      return null;
    }
  }

  Future<String> _generate(String apiKey, String model, String prompt) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('$_endpoint/$model:generateContent?key=$apiKey'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': 0.3,
                'maxOutputTokens': 1024,
              },
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 429) {
        throw GeminiQuotaExceeded(_extractError(response.body) ?? 'HTTP 429');
      }
      if (response.statusCode == 404) {
        throw GeminiModelNotFound(
            _extractError(response.body) ?? 'Model $model không khả dụng');
      }
      if (response.statusCode != 200) {
        throw GeminiRequestFailed(
            'HTTP ${response.statusCode}: ${_extractError(response.body) ?? ''}');
      }

      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) {
        throw const GeminiRequestFailed('Phản hồi không đúng định dạng.');
      }
      final candidates = body['candidates'];
      if (candidates is! List || candidates.isEmpty) {
        throw const GeminiRequestFailed('API không trả về nội dung nào.');
      }
      final parts = (candidates.first as Map)['content']?['parts'];
      final text = (parts is List)
          ? parts
              .map((part) => (part as Map)['text'] as String? ?? '')
              .join('\n')
              .trim()
          : '';
      if (text.isEmpty) {
        throw const GeminiRequestFailed(
            'Nội dung trả về rỗng (có thể hết output token).');
      }
      return text;
    } finally {
      if (_client == null) client.close();
    }
  }

  String? _extractError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        return decoded['error']['message'] as String?;
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}
