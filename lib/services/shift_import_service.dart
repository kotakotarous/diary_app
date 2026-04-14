import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _prefGeminiKey = 'gemini_api_key';

class ShiftEntry {
  final DateTime date;
  final String start; // "09:00"
  final String end;   // "18:00"
  final String note;

  ShiftEntry({
    required this.date,
    required this.start,
    required this.end,
    this.note = '',
  });

  String get timeRange => '$start〜$end';
}

class ShiftImportService {
  static final instance = ShiftImportService._();
  ShiftImportService._();

  String? _apiKey;

  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  Future<void> loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString(_prefGeminiKey);
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefGeminiKey, key);
  }

  /// 画像（base64）からシフトを抽出する
  Future<List<ShiftEntry>> extractShifts(
      String base64Image, String mimeType, String myName) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      throw Exception('Gemini APIキーが未設定です');
    }

    final nameHint =
        myName.isNotEmpty ? '「$myName」という名前の人のシフトを探してください。' : '';

    final prompt = '''
この画像はシフト表（勤務スケジュール表）です。$nameHint
各シフトの情報を抽出して、以下のJSON形式のみで返してください（説明文は不要）:
[
  {"date": "YYYY-MM-DD", "start": "HH:mm", "end": "HH:mm", "note": "備考や仕事種別など"},
  ...
]
日付は西暦で補完してください（例：4/1 → ${DateTime.now().year}-04-01）。
時間が読み取れない場合はnullにせず空文字にしてください。
シフトが見つからない場合は [] を返してください。
''';

    final response = await http.post(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': mimeType,
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.0,
        }
      }),
    );

    if (response.statusCode != 200) {
      String message;
      try {
        final err = jsonDecode(response.body) as Map<String, dynamic>;
        message = err['error']?['message'] as String? ??
            'APIエラー (${response.statusCode})';
      } catch (_) {
        message = 'APIエラー (${response.statusCode})';
      }
      throw Exception(message);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = body['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('AIからの応答がありませんでした（安全フィルターにより遮断された可能性があります）');
    }
    final content = candidates[0]['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts?.isNotEmpty == true
        ? parts![0]['text'] as String?
        : null;
    if (text == null || text.isEmpty) {
      throw Exception('AIの応答テキストが空でした');
    }

    // JSON部分だけ抽出
    final jsonStr = _extractJson(text);
    final List<dynamic> list;
    try {
      list = jsonDecode(jsonStr) as List<dynamic>;
    } on FormatException {
      // JSONとして解析できない場合はシフトなしとして扱う
      return [];
    }

    return list.map((e) {
      final map = e as Map<String, dynamic>;
      final dateStr = map['date'] as String? ?? '';
      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        date = DateTime.now();
      }
      return ShiftEntry(
        date: date,
        start: (map['start'] as String?) ?? '',
        end: (map['end'] as String?) ?? '',
        note: (map['note'] as String?) ?? '',
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  String _extractJson(String text) {
    // ```json ... ``` または [ ... ] を取り出す
    final codeBlock = RegExp(r'```(?:json)?\s*([\s\S]*?)```');
    final match = codeBlock.firstMatch(text);
    if (match != null) return match.group(1)!.trim();
    final start = text.indexOf('[');
    final end = text.lastIndexOf(']');
    if (start >= 0 && end > start) return text.substring(start, end + 1);
    return '[]';
  }
}
