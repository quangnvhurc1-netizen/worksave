import 'package:meta/meta.dart';

import '../enums.dart';

/// Một kết quả của tìm kiếm toàn app.
@immutable
class SearchHit {
  final SearchHitKind kind;
  final String title;
  final String snippet;
  final DateTime date;

  const SearchHit({
    required this.kind,
    required this.title,
    required this.snippet,
    required this.date,
  });
}
