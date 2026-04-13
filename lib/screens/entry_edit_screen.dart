import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../widgets/mood_badge.dart';

const _presetTags = ['映画', '飲食店', '飲み', '買い物', '旅行', '仕事', 'その他'];

class EntryEditScreen extends StatefulWidget {
  final DiaryEntry? entry;
  final DateTime? initialDate;
  const EntryEditScreen({super.key, this.entry, this.initialDate});

  @override
  State<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends State<EntryEditScreen> {
  late DateTime _date;
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late List<String> _tags;
  late List<DiaryLink> _links;
  int? _mood;

  @override
  void initState() {
    super.initState();
    _date = widget.entry?.date ?? widget.initialDate ?? DateTime.now();
    _titleCtrl = TextEditingController(text: widget.entry?.title ?? '');
    _contentCtrl = TextEditingController(text: widget.entry?.content ?? '');
    _tags = List<String>.from(widget.entry?.tags ?? []);
    _links = List<DiaryLink>.from(widget.entry?.links ?? []);
    _mood = widget.entry?.mood;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _toggleTag(String tag) => setState(() {
        if (_tags.contains(tag)) {
          _tags.remove(tag);
        } else {
          _tags.add(tag);
        }
      });

  Future<void> _addLink() async {
    final labelCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    final result = await showDialog<DiaryLink>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('リンクを追加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(
                    labelText: 'ラベル（例：公式サイト）', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(
                    labelText: 'URL', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              if (urlCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx, DiaryLink(
                  label: labelCtrl.text.trim().isEmpty
                      ? urlCtrl.text.trim()
                      : labelCtrl.text.trim(),
                  url: urlCtrl.text.trim(),
                ));
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
    if (result != null) setState(() => _links.add(result));
  }

  void _save() {
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('内容を入力してください')));
      return;
    }
    Navigator.of(context).pop(DiaryEntry(
      id: widget.entry?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: _date,
      title: _titleCtrl.text.trim(),
      content: _contentCtrl.text.trim(),
      tags: _tags,
      links: _links,
      mood: _mood,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(widget.entry == null ? '新しい記録' : '編集'),
        actions: [
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, size: 18),
            label: const Text('保存'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // メイン入力エリア
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日付
                  TextButton.icon(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                      DateFormat('yyyy年M月d日（E）', 'ja').format(_date),
                      style: const TextStyle(fontSize: 15),
                    ),
                    onPressed: _pickDate,
                  ),
                  const SizedBox(height: 8),
                  // タイトル
                  TextField(
                    controller: _titleCtrl,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: 'タイトル（省略可）',
                      border: InputBorder.none,
                      hintStyle: TextStyle(fontWeight: FontWeight.normal),
                    ),
                  ),
                  const Divider(),
                  // 本文
                  Expanded(
                    child: TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(fontSize: 15, height: 1.8),
                      decoration: const InputDecoration(
                        hintText: '今日はどんな一日でしたか…',
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // サイドパネル
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border(left: BorderSide(color: cs.outlineVariant)),
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 気分
                _SideSection(
                  title: '気分',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [5, 4, 3, 2, 1].map((m) {
                      final selected = _mood == m;
                      return GestureDetector(
                        onTap: () => setState(() => _mood = selected ? null : m),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selected
                                ? (moodColor[m] ?? cs.primary).withOpacity(0.2)
                                : cs.surface,
                            border: Border.all(
                              color: selected
                                  ? (moodColor[m] ?? cs.primary)
                                  : cs.outlineVariant,
                              width: selected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(moodEmoji[m] ?? '', style: const TextStyle(fontSize: 16)),
                              const SizedBox(width: 4),
                              Text(moodLabel[m] ?? '',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: selected
                                          ? (moodColor[m] ?? cs.primary)
                                          : cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                // タグ
                _SideSection(
                  title: 'タグ',
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _presetTags.map((tag) {
                      final selected = _tags.contains(tag);
                      return FilterChip(
                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                        selected: selected,
                        onSelected: (_) => _toggleTag(tag),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                // リンク
                _SideSection(
                  title: 'リンク',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._links.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.link, size: 13, color: Colors.blue),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(e.value.label,
                                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                GestureDetector(
                                  onTap: () => setState(() => _links.removeAt(e.key)),
                                  child: const Icon(Icons.close, size: 14),
                                ),
                              ],
                            ),
                          )),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 28)),
                        icon: const Icon(Icons.add_link, size: 16),
                        label: const Text('追加', style: TextStyle(fontSize: 12)),
                        onPressed: _addLink,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _SideSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.outline,
                letterSpacing: 0.5)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
