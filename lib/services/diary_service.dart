import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import 'diary_io_helper.dart' if (dart.library.html) 'diary_web_helper.dart';

class DiaryService {
  static const _prefKey = 'diary_entries';

  Future<List<DiaryEntry>> loadEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      final entries = list
          .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      entries.sort((a, b) => b.date.compareTo(a.date));
      return entries;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEntries(List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(entries.map((e) => e.toJson()).toList()));
    await _doMarkdownExport(entries);
  }

  Future<void> _doMarkdownExport(List<DiaryEntry> entries) async {
    final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    final buf = StringBuffer('# 日記\n\n---\n\n');
    for (final e in sorted) {
      final d = e.date;
      final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
      final w = weekdays[d.weekday - 1];
      buf.write(
          '## ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}（$w）');
      if (e.title.isNotEmpty) buf.write(' ${e.title}');
      if (e.tags.isNotEmpty) buf.write('  [${e.tags.join(', ')}]');
      buf.write('\n\n${e.content}\n');
      if (e.links.isNotEmpty) {
        buf.write('\n');
        for (final l in e.links) {
          buf.write('- [${l.label}](${l.url})\n');
        }
      }
      buf.write('\n---\n\n');
    }
    await exportMarkdown(buf.toString());
  }
}
