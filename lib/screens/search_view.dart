import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../widgets/entry_card.dart';
import '../widgets/mood_badge.dart';

const _allTags = ['映画', '飲食店', '飲み', '買い物', '旅行', '仕事', 'その他'];

class SearchView extends StatefulWidget {
  final List<DiaryEntry> entries;
  final void Function(DiaryEntry) onSelect;

  const SearchView({super.key, required this.entries, required this.onSelect});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _selectedTags = {};
  final Set<int> _selectedMoods = {};
  DateTime? _from;
  DateTime? _to;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<DiaryEntry> get _results {
    return widget.entries.where((e) {
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        if (!e.title.toLowerCase().contains(q) &&
            !e.content.toLowerCase().contains(q) &&
            !e.tags.any((t) => t.toLowerCase().contains(q))) {
          return false;
        }
      }
      if (_selectedTags.isNotEmpty &&
          !e.tags.any((t) => _selectedTags.contains(t))) {
        return false;
      }
      if (_selectedMoods.isNotEmpty) {
        if (e.mood == null || !_selectedMoods.contains(e.mood)) return false;
      }
      if (_from != null && e.date.isBefore(_from!)) return false;
      if (_to != null && e.date.isAfter(_to!.add(const Duration(days: 1)))) {
        return false;
      }
      return true;
    }).toList();
  }

  bool get _hasFilter =>
      _query.isNotEmpty ||
      _selectedTags.isNotEmpty ||
      _selectedMoods.isNotEmpty ||
      _from != null ||
      _to != null;

  void _clearAll() {
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _selectedTags.clear();
      _selectedMoods.clear();
      _from = null;
      _to = null;
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) _from = picked;
        else _to = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final results = _results;

    return Row(
      children: [
        // 左：フィルターパネル
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border(right: BorderSide(color: cs.outlineVariant)),
          ),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Text('フィルター',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_hasFilter)
                    TextButton(
                      onPressed: _clearAll,
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 28)),
                      child: const Text('クリア', style: TextStyle(fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 日付範囲
              _FilterSection(
                title: '期間',
                child: Column(
                  children: [
                    _DateButton(
                      label: _from == null
                          ? '開始日'
                          : DateFormat('yyyy/MM/dd').format(_from!),
                      isSet: _from != null,
                      onTap: () => _pickDate(true),
                      onClear: _from == null ? null : () => setState(() => _from = null),
                    ),
                    const SizedBox(height: 4),
                    _DateButton(
                      label: _to == null
                          ? '終了日'
                          : DateFormat('yyyy/MM/dd').format(_to!),
                      isSet: _to != null,
                      onTap: () => _pickDate(false),
                      onClear: _to == null ? null : () => setState(() => _to = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // タグ
              _FilterSection(
                title: 'タグ',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _allTags.map((tag) {
                    final sel = _selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag, style: const TextStyle(fontSize: 11)),
                      selected: sel,
                      onSelected: (_) => setState(() {
                        if (sel) _selectedTags.remove(tag);
                        else _selectedTags.add(tag);
                      }),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // 気分
              _FilterSection(
                title: '気分',
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [5, 4, 3, 2, 1].map((m) {
                    final sel = _selectedMoods.contains(m);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (sel) _selectedMoods.remove(m);
                        else _selectedMoods.add(m);
                      }),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: sel
                              ? (moodColor[m] ?? cs.primary).withOpacity(0.2)
                              : cs.surface,
                          border: Border.all(
                            color: sel
                                ? (moodColor[m] ?? cs.primary)
                                : cs.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(moodEmoji[m] ?? '',
                            style: const TextStyle(fontSize: 18)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // 右：検索結果
        Expanded(
          child: Column(
            children: [
              // 検索バー
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'キーワードで検索…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                    filled: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Text('${results.length}件',
                        style: TextStyle(fontSize: 13, color: cs.outline)),
                  ],
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off, size: 48, color: cs.outlineVariant),
                            const SizedBox(height: 12),
                            const Text('見つかりませんでした',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (_, i) => EntryCard(
                          entry: results[i],
                          onTap: () => widget.onSelect(results[i]),
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

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _FilterSection({required this.title, required this.child});

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

class _DateButton extends StatelessWidget {
  final String label;
  final bool isSet;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateButton(
      {required this.label,
      required this.isSet,
      required this.onTap,
      this.onClear});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSet ? cs.primaryContainer : cs.surface,
          border: Border.all(color: isSet ? cs.primary : cs.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 13),
            const SizedBox(width: 6),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        color: isSet ? cs.primary : cs.onSurfaceVariant))),
            if (onClear != null)
              GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close, size: 13)),
          ],
        ),
      ),
    );
  }
}
