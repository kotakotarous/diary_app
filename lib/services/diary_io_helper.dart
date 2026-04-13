import 'dart:convert';
import 'dart:io';
import '../models/diary_entry.dart';

String _docsPath() {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
  return '$home/Documents/diary_data.json';
}

Future<List<DiaryEntry>> loadEntriesPlatform() async {
  try {
    final file = File(_docsPath());
    if (!file.existsSync()) return [];
    final raw = await file.readAsString();
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

Future<void> saveEntriesPlatform(List<DiaryEntry> entries) async {
  try {
    await File(_docsPath()).writeAsString(
        jsonEncode(entries.map((e) => e.toJson()).toList()));
  } catch (_) {}
}

Future<void> exportMarkdown(String content) async {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
  if (home.isNotEmpty) {
    await File('$home/diary.md').writeAsString(content);
  }
}
