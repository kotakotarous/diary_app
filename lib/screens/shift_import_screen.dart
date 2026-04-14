import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../services/shift_import_service.dart';

class ShiftImportScreen extends StatefulWidget {
  final Future<void> Function(DiaryEntry) onAddEntry;

  const ShiftImportScreen({super.key, required this.onAddEntry});

  @override
  State<ShiftImportScreen> createState() => _ShiftImportScreenState();
}

class _ShiftImportScreenState extends State<ShiftImportScreen> {
  final _svc = ShiftImportService.instance;
  final _apiKeyCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  List<ShiftEntry> _shifts = [];
  final Set<int> _selected = {};
  final Set<int> _imported = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await _svc.loadApiKey();
    setState(() {});
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    if (key.isEmpty) return;
    await _svc.saveApiKey(key);
    setState(() {});
  }

  Future<void> _pickAndAnalyze(ImageSource source) async {
    setState(() { _loading = true; _error = null; _shifts = []; _selected.clear(); });
    try {
      final picker = ImagePicker();
      XFile? file;
      try {
        file = await picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1920,
        );
      } catch (_) {
        // camera 非対応の場合は gallery にフォールバック
        file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1920,
          maxHeight: 1920,
        );
      }
      if (file == null) {
        setState(() => _loading = false);
        return;
      }
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mimeType = file.mimeType ?? 'image/jpeg';

      final shifts = await _svc.extractShifts(
          base64Image, mimeType, _nameCtrl.text.trim());

      setState(() {
        _shifts = shifts;
        _selected.addAll(List.generate(shifts.length, (i) => i));
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _importSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _loading = true);
    try {
      for (final i in _selected.toList()..sort()) {
        if (_imported.contains(i)) continue;
        final s = _shifts[i];
        final content = s.start.isNotEmpty && s.end.isNotEmpty
            ? '勤務時間: ${s.start}〜${s.end}${s.note.isNotEmpty ? '\n${s.note}' : ''}'
            : s.note.isNotEmpty
                ? s.note
                : '勤務';
        await widget.onAddEntry(DiaryEntry(
          id: 'shift_${s.date.millisecondsSinceEpoch}_$i',
          date: s.date,
          title: '仕事',
          content: content,
          tags: ['仕事'],
          updatedAt: DateTime.now().toUtc(),
        ));
        _imported.add(i);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_selected.length}件を日記に追加しました')));
        setState(() { _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_svc.hasApiKey) {
      return _SetupView(
        ctrl: _apiKeyCtrl,
        onSave: _saveApiKey,
      );
    }

    return Column(
      children: [
        // ===== ヘッダー =====
        Container(
          padding: const EdgeInsets.all(16),
          color: cs.surfaceContainerHighest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('シフト表を読み取る',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '自分の名前（任意）',
                  hintText: '例: 田中　→ 自分のシフトだけ抽出',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              if (kIsWeb)
                // ウェブ: 1ボタン（スマホでは自動でカメラ/ライブラリ選択が出る）
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading
                        ? null
                        : () => _pickAndAnalyze(ImageSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('画像を選択（カメラ or ライブラリ）'),
                  ),
                )
              else
                // デスクトップ: ギャラリーとカメラを分けて表示
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _loading
                            ? null
                            : () => _pickAndAnalyze(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('ファイルを選択'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: _loading
                            ? null
                            : () => _pickAndAnalyze(ImageSource.camera),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt_outlined, size: 18),
                            SizedBox(width: 6),
                            Text('カメラで撮影'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _svc.saveApiKey('').then((_) => setState(() {})),
                child: const Text('APIキーを変更', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),

        // ===== 結果 =====
        Expanded(
          child: _loading
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('AIが解析中...'),
                    ],
                  ),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: cs.error),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: TextStyle(color: cs.error),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () =>
                                  setState(() => _error = null),
                              child: const Text('戻る'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _shifts.isEmpty
                      ? const Center(
                          child: Text('画像を選択するとシフトが表示されます'),
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Text('${_shifts.length}件のシフトを検出',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      if (_selected.length == _shifts.length) {
                                        _selected.clear();
                                      } else {
                                        _selected.addAll(List.generate(
                                            _shifts.length, (i) => i));
                                      }
                                    }),
                                    child: Text(
                                        _selected.length == _shifts.length
                                            ? '全て解除'
                                            : '全て選択'),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.separated(
                                itemCount: _shifts.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (ctx, i) {
                                  final s = _shifts[i];
                                  final done = _imported.contains(i);
                                  final weekdays = [
                                    '月', '火', '水', '木', '金', '土', '日'
                                  ];
                                  final w =
                                      weekdays[s.date.weekday - 1];
                                  return CheckboxListTile(
                                    value: _selected.contains(i),
                                    onChanged: done
                                        ? null
                                        : (v) => setState(() {
                                              if (v == true) {
                                                _selected.add(i);
                                              } else {
                                                _selected.remove(i);
                                              }
                                            }),
                                    title: Text(
                                      '${DateFormat('M月d日', 'ja').format(s.date)}（$w）',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: done ? cs.outline : null),
                                    ),
                                    subtitle: Text(
                                      [
                                        if (s.start.isNotEmpty &&
                                            s.end.isNotEmpty)
                                          s.timeRange,
                                        if (s.note.isNotEmpty) s.note,
                                      ].join('  '),
                                      style: TextStyle(
                                          color: done ? cs.outline : null),
                                    ),
                                    secondary: done
                                        ? Icon(Icons.check_circle,
                                            color: cs.primary)
                                        : null,
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _selected.isEmpty
                                      ? null
                                      : _importSelected,
                                  icon: const Icon(Icons.add),
                                  label: Text(
                                      '選択した${_selected.length}件を日記に追加'),
                                ),
                              ),
                            ),
                          ],
                        ),
        ),
      ],
    );
  }
}

class _SetupView extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onSave;

  const _SetupView({required this.ctrl, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('シフト読み取りの設定',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Gemini APIキーが必要です（無料で取得できます）。\n'
                'aistudio.google.com → 「Get API key」で取得してください。',
                style: TextStyle(
                    fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Gemini API Key',
                  hintText: 'AIza...',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onSave,
                child: const Text('保存'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
