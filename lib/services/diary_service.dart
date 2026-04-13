import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary_entry.dart';
import 'diary_io_helper.dart' if (dart.library.html) 'diary_web_helper.dart';
import 'google_drive_service.dart';

class DiaryService {
  static const _prefKey = 'diary_entries';
  final _drive = GoogleDriveService.instance;
  String? lastSyncError;

  Future<List<DiaryEntry>> loadEntries() async {
    // デスクトップ: Documentsのファイルから読み込む
    final fileEntries = await loadEntriesPlatform();
    if (fileEntries.isNotEmpty) {
      final sorted = fileEntries..sort((a, b) => b.date.compareTo(a.date));
      return sorted;
    }

    // ウェブ / ファイルが空: SharedPreferences から読み込む
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
    // デスクトップ: ファイルに保存
    await saveEntriesPlatform(entries);

    // ウェブ: SharedPreferences に保存
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefKey, jsonEncode(entries.map((e) => e.toJson()).toList()));

    await _doMarkdownExport(entries);
    _uploadToDriveInBackground(entries);
  }

  /// Drive と同期してマージした結果を返す。
  /// ログイン済みでない場合は null を返す。
  Future<List<DiaryEntry>?> syncWithDrive(List<DiaryEntry> local) async {
    // 認証情報を読み込む（起動時はまだ未ロードのため）
    await _drive.loadSaved();
    if (!_drive.isLoggedIn) return null;
    try {
      final raw = await _drive.download();
      if (raw == null) {
        // Drive にデータなし → ローカルをアップロードするだけ
        await _drive.upload(
            jsonEncode(local.map((e) => e.toJson()).toList()));
        return null;
      }
      final driveEntries = (jsonDecode(raw) as List<dynamic>)
          .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
          .toList();

      // マージ: id をキーに新しい方を採用
      final merged = <String, DiaryEntry>{};
      for (final e in local) {
        merged[e.id] = e;
      }
      for (final e in driveEntries) {
        final existing = merged[e.id];
        if (existing == null || e.updatedAt.isAfter(existing.updatedAt)) {
          merged[e.id] = e;
        }
      }

      final result = merged.values.toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      // マージ結果をローカルに保存
      await saveEntriesPlatform(result);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefKey, jsonEncode(result.map((e) => e.toJson()).toList()));

      // マージ結果を Drive にアップロード
      await _drive.upload(jsonEncode(result.map((e) => e.toJson()).toList()));

      return result;
    } catch (e) {
      lastSyncError = e.toString();
      return null;
    }
  }

  void _uploadToDriveInBackground(List<DiaryEntry> entries) {
    if (!_drive.isLoggedIn) return;
    _drive
        .upload(jsonEncode(entries.map((e) => e.toJson()).toList()))
        .ignore();
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
