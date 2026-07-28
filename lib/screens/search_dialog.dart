import 'dart:async';

import 'package:flutter/material.dart';

import '../db/app_db.dart';
import '../services/l10n.dart';

/// Tìm kiếm toàn app: task, log, ý tưởng, nhật ký, save, lịch.
class SearchDialog extends StatefulWidget {
  const SearchDialog({super.key});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  final _input = TextEditingController();
  List<SearchHit> _hits = [];
  Timer? _debounce;
  bool _searched = false;

  static const Map<String, Color> _typeColors = {
    'Task': Color(0xFF2E5AAC),
    'Log': Colors.teal,
    'Ý tưởng': Colors.amber,
    'Nhật ký': Colors.purple,
    'Save': Colors.indigo,
    'Lịch': Colors.deepOrange,
  };

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().length < 2) {
      setState(() {
        _hits = [];
        _searched = false;
      });
      return;
    }
    final hits = await AppDb.instance.searchAll(q.trim());
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t('search_title')),
      content: SizedBox(
        width: 620,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _input,
              autofocus: true,
              decoration: InputDecoration(
                hintText: L10n.t('search_hint'),
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 10),
            Expanded(
              child: !_searched
                  ? Center(
                      child: Text(L10n.t('search_empty'),
                          style: const TextStyle(color: Colors.black54)))
                  : _hits.isEmpty
                      ? Center(child: Text(L10n.t('search_none')))
                      : ListView.builder(
                          itemCount: _hits.length,
                          itemBuilder: (_, i) {
                            final h = _hits[i];
                            final color =
                                _typeColors[h.type] ?? Colors.grey;
                            return Card(
                              child: ListTile(
                                dense: true,
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(h.type,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: color,
                                          fontWeight: FontWeight.bold)),
                                ),
                                title: Text(h.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                subtitle: Text('${h.date} · ${h.snippet}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('close'))),
      ],
    );
  }
}
