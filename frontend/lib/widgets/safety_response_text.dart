import 'package:flutter/material.dart';

/// Menampilkan jawaban model yang menggunakan Markdown ringan.
/// Tidak menjalankan HTML, tautan, kode, maupun markup lain dari model.
class SafetyResponseText extends StatelessWidget {
  const SafetyResponseText(
    this.message, {
    super.key,
    required this.style,
  });

  final String message;
  final TextStyle style;

  static final RegExp _inlineBold = RegExp(r'\*\*(.+?)\*\*|__(.+?)__');
  static final RegExp _bullet = RegExp(r'^\s*[-*•]\s+');
  static final RegExp _number = RegExp(r'^\s*\d{1,2}[.)]\s+');
  static final RegExp _heading = RegExp(r'^\s*#{1,4}\s+');

  @override
  Widget build(BuildContext context) {
    final lines = message.replaceAll('\r\n', '\n').trim().split('\n');
    final widgets = <Widget>[];

    for (final raw in lines) {
      var line = raw.trim();
      if (line.isEmpty) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 8));
        }
        continue;
      }

      final heading = _heading.hasMatch(line);
      if (heading) line = line.replaceFirst(_heading, '');
      final bullet = _bullet.hasMatch(line);
      final numbered = _number.hasMatch(line);
      final match = numbered ? _number.firstMatch(line) : null;
      final prefix = bullet ? '•  ' : (match?.group(0)?.trim() ?? '');
      if (bullet) line = line.replaceFirst(_bullet, '');
      if (numbered) line = line.replaceFirst(_number, '');
      if (prefix.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prefix, style: style.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 5),
              Expanded(child: _rich(line, heading: heading)),
            ],
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _rich(line, heading: heading),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _rich(String line, {bool heading = false}) {
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in _inlineBold.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1) ?? match.group(2) ?? '',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      cursor = match.end;
    }
    if (cursor < line.length) spans.add(TextSpan(text: line.substring(cursor)));
    return Text.rich(TextSpan(children: spans), style: heading
        ? style.copyWith(fontWeight: FontWeight.w800)
        : style);
  }
}
