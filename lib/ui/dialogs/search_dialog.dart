import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/date_x.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/enums.dart';
import '../../domain/models/search_hit.dart';
import '../../services/l10n.dart';
import '../theme.dart';

/// Tìm kiếm xuyên mọi loại dữ liệu.
class SearchDialog extends StatefulWidget {
  const SearchDialog({super.key});

  @override
  State<SearchDialog> createState() => _SearchDialogState();
}

class _SearchDialogState extends State<SearchDialog> {
  static const Duration _debounce = Duration(milliseconds: 350);

  final _input = TextEditingController();
  Timer? _debounceTimer;
  List<SearchHit> _hits = const [];
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () => unawaited(_search(query)));
  }

  Future<void> _search(String query) async {
    final hits = await Repos.search.search(query);
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _hasSearched = query.trim().length >= 2;
    });
  }

  static Color _colorOf(SearchHitKind kind) => switch (kind) {
        SearchHitKind.task => AppColors.primary,
        SearchHitKind.workLog => Colors.teal,
        SearchHitKind.idea => Colors.amber,
        SearchHitKind.journal => Colors.purple,
        SearchHitKind.checkpoint => Colors.indigo,
        SearchHitKind.schedule => Colors.deepOrange,
      };

  static String _labelOf(SearchHitKind kind) =>
      kind.isL10nKey ? L10n.t(kind.label) : kind.label;

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
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildResults()),
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

  Widget _buildResults() {
    if (!_hasSearched) {
      return Center(
          child: Text(L10n.t('search_empty'),
              style: const TextStyle(color: Colors.black54)));
    }
    if (_hits.isEmpty) return Center(child: Text(L10n.t('search_none')));

    return ListView.builder(
      itemCount: _hits.length,
      itemBuilder: (context, index) {
        final hit = _hits[index];
        final color = _colorOf(hit.kind);
        return Card(
          child: ListTile(
            dense: true,
            leading: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_labelOf(hit.kind),
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.bold)),
            ),
            title:
                Text(hit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(hit.snippet.isEmpty
                ? formatDate(hit.date)
                : '${formatDate(hit.date)} · ${hit.snippet}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
        );
      },
    );
  }
}
