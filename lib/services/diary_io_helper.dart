import 'dart:io';

Future<void> exportMarkdown(String content) async {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
  if (home.isNotEmpty) {
    await File('$home/diary.md').writeAsString(content);
  }
}
