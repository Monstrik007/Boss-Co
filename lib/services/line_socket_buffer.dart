import 'dart:convert';

/// Безопасный буфер строк по байтам (не ломает UTF-8 на границах чанков).
class LineSocketBuffer {
  final _bytes = <int>[];

  void add(List<int> data) => _bytes.addAll(data);

  List<String> drainLines() {
    final lines = <String>[];
    while (true) {
      final index = _bytes.indexOf(10);
      if (index < 0) break;

      final lineBytes = _bytes.sublist(0, index);
      _bytes.removeRange(0, index + 1);

      if (lineBytes.isEmpty) continue;
      lines.add(utf8.decode(lineBytes));
    }
    return lines;
  }

  void clear() => _bytes.clear();
}
