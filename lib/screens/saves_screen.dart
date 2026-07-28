import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../models.dart';
import '../services/l10n.dart';
import '../services/gemini_service.dart';

class SavesScreen extends StatefulWidget {
  const SavesScreen({super.key});

  @override
  State<SavesScreen> createState() => _SavesScreenState();
}

class _SavesScreenState extends State<SavesScreen> {
  final _svc = GeminiService();
  List<Checkpoint> _saves = [];
  bool _generating = false;
  bool _alreadyGenToday = false;
  String? _cachedDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saves = await AppDb.instance.getCheckpoints();
    final genToday = await _svc.alreadyGeneratedToday();
    final cached = await _svc.cachedSummary();
    if (!mounted) return;
    setState(() {
      _saves = saves;
      _alreadyGenToday = genToday;
      _cachedDate = cached?.$1;
    });
  }

  /// Gọi AI tổng hợp (hoặc lấy cache/fallback), rồi mở dialog Save đã điền sẵn.
  Future<void> _aiSummarizeAndSave() async {
    setState(() => _generating = true);
    final result = await _svc.buildFridaySummary();
    if (!mounted) return;
    setState(() => _generating = false);

    if (result.warning != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.warning!),
        duration: const Duration(seconds: 6),
      ));
    }

    // Tách 2 phần nếu AI trả đúng format.
    String doing = result.text;
    String next = '';
    final idx = result.text.indexOf('VIỆC TIẾP THEO:');
    if (idx > 0) {
      doing = result.text
          .substring(0, idx)
          .replaceFirst('ĐANG LÀM DỞ:', '')
          .trim();
      next = result.text
          .substring(idx + 'VIỆC TIẾP THEO:'.length)
          .trim();
    }

    await _openSaveDialog(
      doingPrefill: doing,
      nextPrefill: next,
      badge: result.fromAi
          ? (result.fromCache
              ? '🤖 Bản AI đã tổng hợp hôm nay (không gọi lại API)'
              : '🤖 AI vừa tổng hợp')
          : '📋 Tổng hợp local (không dùng AI)',
    );
  }

  Future<void> _openSaveDialog({
    String? doingPrefill,
    String? nextPrefill,
    String? badge,
  }) async {
    final doing = TextEditingController(text: doingPrefill ?? '');
    final next = TextEditingController(text: nextPrefill ?? '');
    final remember = TextEditingController();

    if ((doingPrefill ?? '').isEmpty) {
      final doingTasks = (await AppDb.instance.getUnfinishedTasks())
          .where((t) => t.status == 'doing')
          .toList();
      if (doingTasks.isNotEmpty) {
        doing.text = doingTasks.map((t) => '- ${t.title}').join('\n');
      }
    }

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('💾 Save trạng thái làm việc'),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(badge, style: const TextStyle(fontSize: 12)),
                  ),
                TextField(
                  controller: doing,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Đang làm dở việc gì?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: next,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Thứ 2 mở máy lên thì làm gì đầu tiên?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remember,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Cần nhớ / lưu ý',
                    hintText:
                        'Đường dẫn file đang mở, ai đang chờ phản hồi, deadline...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && doing.text.trim().isNotEmpty) {
      await AppDb.instance.insertCheckpoint(Checkpoint(
        doing: doing.text.trim(),
        nextStep: next.text.trim(),
        remember: remember.text.trim(),
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFriday = _svc.isFriday;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSaveDialog(),
        icon: const Icon(Icons.save),
        label: const Text('Save thủ công'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(L10n.t('tab_saves'),
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          // ---- Khối tổng hợp T6 bằng AI ----
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            color: const Color(0xFFF5F8FF),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.smart_toy_outlined,
                          color: Color(0xFF2E5AAC)),
                      const SizedBox(width: 8),
                      const Text('Tổng hợp T6 bằng AI',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      const Spacer(),
                      if (_alreadyGenToday)
                        const Chip(
                          label: Text('Đã gen hôm nay ✓',
                              style: TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isFriday
                        ? (_alreadyGenToday
                            ? 'Hôm nay đã tổng hợp rồi — bấm nút sẽ dùng lại bản đã gen, không tốn quota.'
                            : 'Hôm nay là thứ 6! Bấm nút để AI đọc các task chưa xong và tự viết bản save.')
                        : 'AI chỉ tự tổng hợp vào thứ 6 (mỗi tuần đúng 1 lần để tiết kiệm quota).'
                            '${_cachedDate != null ? ' Bản gần nhất: $_cachedDate.' : ''}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _generating ? null : _aiSummarizeAndSave,
                    icon: _generating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome),
                    label: Text(_generating
                        ? 'Đang tổng hợp...'
                        : _alreadyGenToday
                            ? 'Xem bản đã tổng hợp & Save'
                            : 'Tổng hợp việc còn dở & Save'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _saves.isEmpty
                ? const Center(child: Text('Chưa có save nào.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: _saves.length,
                    itemBuilder: (_, i) {
                      final s = _saves[i];
                      final time =
                          '${fmtDate(s.createdAt)} ${s.createdAt.hour.toString().padLeft(2, '0')}:${s.createdAt.minute.toString().padLeft(2, '0')}';
                      return Card(
                        child: ExpansionTile(
                          leading: Icon(
                            i == 0 ? Icons.bookmark : Icons.bookmark_border,
                            color: i == 0 ? const Color(0xFF2E5AAC) : null,
                          ),
                          title: Text(i == 0 ? 'Save mới nhất — $time' : time),
                          subtitle: Text(
                            s.doing,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          childrenPadding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          expandedCrossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            _block('Đang làm dở', s.doing),
                            _block('Việc tiếp theo', s.nextStep),
                            _block('Cần nhớ', s.remember),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  if (s.id != null) {
                                    await AppDb.instance
                                        .deleteCheckpoint(s.id!);
                                    _load();
                                  }
                                },
                                icon:
                                    const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Xóa save này'),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _block(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(value),
        ],
      ),
    );
  }
}
