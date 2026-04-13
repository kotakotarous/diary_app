import '../models/diary_entry.dart';

// ウェブではファイルI/O不要 — SharedPreferencesで管理
Future<List<DiaryEntry>> loadEntriesPlatform() async => [];
Future<void> saveEntriesPlatform(List<DiaryEntry> entries) async {}
Future<void> exportMarkdown(String content) async {}
