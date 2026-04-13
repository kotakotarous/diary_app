import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/diary_entry.dart';
import '../services/diary_service.dart';
import '../widgets/entry_card.dart';
import '../widgets/mood_badge.dart';
import 'entry_edit_screen.dart';
import 'today_view.dart';
import 'timeline_view.dart';
import 'search_view.dart';
import 'stats_view.dart';
import 'google_calendar_view.dart';

enum _NavItem { today, timeline, calendar, search, stats, google }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = DiaryService();
  List<DiaryEntry> _entries = [];
  bool _loading = true;
  _NavItem _nav = _NavItem.today;
  DiaryEntry? _detailEntry;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await _service.loadEntries();
    setState(() {
      _entries = entries;
      _loading = false;
      final today = _entriesForDay(DateTime.now());
      if (today.isNotEmpty) _detailEntry = today.first;
    });
  }

  List<DiaryEntry> _entriesForDay(DateTime day) => _entries
      .where((e) =>
          e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day)
      .toList();

  Future<void> _openEdit({DiaryEntry? entry, DateTime? date}) async {
    final result = await Navigator.of(context).push<DiaryEntry>(
      MaterialPageRoute(
          builder: (_) => EntryEditScreen(entry: entry, initialDate: date)),
    );
    if (result != null) await _upsert(result);
  }

  Future<void> _upsert(DiaryEntry entry) async {
    final existing = _entries.any((e) => e.id == entry.id);
    final List<DiaryEntry> updated;
    if (existing) {
      updated = _entries.map((e) => e.id == entry.id ? entry : e).toList();
    } else {
      updated = [..._entries, entry];
    }
    updated.sort((a, b) => b.date.compareTo(a.date));
    await _service.saveEntries(updated);
    setState(() {
      _entries = updated;
      _detailEntry = entry;
    });
  }

  Future<void> _restore(List<DiaryEntry> entries) async {
    final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    await _service.saveEntries(sorted);
    setState(() {
      _entries = sorted;
      _detailEntry = null;
    });
  }

  Future<void> _delete(DiaryEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('削除'),
        content: const Text('この記録を削除しますか？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final updated = _entries.where((e) => e.id != entry.id).toList();
      await _service.saveEntries(updated);
      setState(() {
        _entries = updated;
        if (_detailEntry?.id == entry.id) _detailEntry = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Row(
        children: [
          // ===== ナビゲーションレール =====
          NavigationRail(
            backgroundColor: cs.surfaceContainerHighest,
            selectedIndex: _NavItem.values.indexOf(_nav),
            onDestinationSelected: (i) {
              setState(() {
                _nav = _NavItem.values[i];
                if (_nav != _NavItem.calendar) _detailEntry = null;
              });
            },
            labelType: NavigationRailLabelType.all,
            minWidth: 72,
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.wb_sunny_outlined),
                  selectedIcon: Icon(Icons.wb_sunny),
                  label: Text('今日')),
              NavigationRailDestination(
                  icon: Icon(Icons.view_timeline_outlined),
                  selectedIcon: Icon(Icons.view_timeline),
                  label: Text('一覧')),
              NavigationRailDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: Text('カレンダー')),
              NavigationRailDestination(
                  icon: Icon(Icons.search),
                  selectedIcon: Icon(Icons.search),
                  label: Text('検索')),
              NavigationRailDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: Text('統計')),
              NavigationRailDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today),
                  label: Text('Google')),
            ],
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton.small(
                    heroTag: 'add',
                    onPressed: () => _openEdit(),
                    tooltip: '新しい記録',
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1),

          // ===== メインコンテンツ =====
          Expanded(
            child: switch (_nav) {
              _NavItem.today => TodayView(
                  entries: _entries,
                  onSelect: (e) => setState(() => _detailEntry = e),
                  onEdit: (e) => _openEdit(entry: e),
                  onAdd: () => _openEdit(),
                ),
              _NavItem.timeline => _TwoPane(
                  left: TimelineView(
                    entries: _entries,
                    selected: _detailEntry,
                    onSelect: (e) => setState(() => _detailEntry = e),
                  ),
                  right: _detailEntry == null
                      ? const _EmptyDetail()
                      : _EntryDetail(
                          entry: _detailEntry!,
                          onEdit: () => _openEdit(entry: _detailEntry!),
                          onDelete: () => _delete(_detailEntry!),
                        ),
                ),
              _NavItem.calendar => _CalendarPane(
                  entries: _entries,
                  selected: _detailEntry,
                  focusedDay: _focusedDay,
                  selectedDay: _selectedDay,
                  onDaySelected: (s, f) {
                    setState(() {
                      _selectedDay = s;
                      _focusedDay = f;
                      final day = _entriesForDay(s);
                      _detailEntry = day.isNotEmpty ? day.first : null;
                    });
                  },
                  onPageChanged: (f) => setState(() => _focusedDay = f),
                  onSelect: (e) => setState(() => _detailEntry = e),
                  onAdd: (d) => _openEdit(date: d),
                  onEdit: (e) => _openEdit(entry: e),
                  onDelete: _delete,
                ),
              _NavItem.search => SearchView(
                  entries: _entries,
                  onSelect: (e) {
                    setState(() {
                      _detailEntry = e;
                      _nav = _NavItem.timeline;
                    });
                  },
                ),
              _NavItem.stats => StatsView(entries: _entries),
              _NavItem.google => GoogleCalendarView(
                  diaryEntries: _entries,
                  onAddEntry: _upsert,
                  onRestoreEntries: _restore,
                ),
            },
          ),
        ],
      ),
    );
  }
}

// 2ペインレイアウト
class _TwoPane extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _TwoPane({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 340, child: left),
        const VerticalDivider(width: 1),
        Expanded(child: right),
      ],
    );
  }
}

// カレンダーペイン
class _CalendarPane extends StatelessWidget {
  final List<DiaryEntry> entries;
  final DiaryEntry? selected;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final void Function(DateTime, DateTime) onDaySelected;
  final void Function(DateTime) onPageChanged;
  final void Function(DiaryEntry) onSelect;
  final void Function(DateTime) onAdd;
  final void Function(DiaryEntry) onEdit;
  final void Function(DiaryEntry) onDelete;

  const _CalendarPane({
    required this.entries,
    required this.selected,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.onPageChanged,
    required this.onSelect,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  List<DiaryEntry> _forDay(DateTime day) => entries
      .where((e) =>
          e.date.year == day.year &&
          e.date.month == day.month &&
          e.date.day == day.day)
      .toList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dayEntries = _forDay(selectedDay);

    return Row(
      children: [
        // 左：カレンダー + 日付リスト
        Container(
          width: 300,
          color: cs.surfaceContainerHighest,
          child: Column(
            children: [
              TableCalendar<DiaryEntry>(
                locale: 'ja_JP',
                firstDay: DateTime(2000),
                lastDay: DateTime(2100),
                focusedDay: focusedDay,
                selectedDayPredicate: (d) => isSameDay(d, selectedDay),
                eventLoader: _forDay,
                calendarFormat: CalendarFormat.month,
                availableCalendarFormats: const {CalendarFormat.month: '月'},
                headerStyle: const HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  titleTextStyle:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  leftChevronMargin: EdgeInsets.zero,
                  rightChevronMargin: EdgeInsets.zero,
                  headerPadding: EdgeInsets.symmetric(vertical: 4),
                ),
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  selectedDecoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: BoxDecoration(
                    color: cs.secondary,
                    shape: BoxShape.circle,
                  ),
                  markersMaxCount: 1,
                  markerSize: 5,
                  cellMargin: const EdgeInsets.all(2),
                  defaultTextStyle: const TextStyle(fontSize: 12),
                  weekendTextStyle:
                      TextStyle(fontSize: 12, color: cs.error),
                  outsideTextStyle:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                daysOfWeekStyle: DaysOfWeekStyle(
                  weekendStyle: TextStyle(fontSize: 11, color: cs.error),
                  weekdayStyle: const TextStyle(fontSize: 11),
                ),
                onDaySelected: onDaySelected,
                onPageChanged: onPageChanged,
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
                child: Row(
                  children: [
                    Text(
                      _dayLabel(selectedDay),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      tooltip: 'この日に追加',
                      onPressed: () => onAdd(selectedDay),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: dayEntries.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('記録なし',
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                      )
                    : ListView(
                        children: dayEntries
                            .map((e) => EntryCard(
                                  entry: e,
                                  compact: true,
                                  isSelected: selected?.id == e.id,
                                  onTap: () => onSelect(e),
                                ))
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        // 右：詳細
        Expanded(
          child: selected == null
              ? _EmptyDetail(
                  message: dayEntries.isEmpty
                      ? 'この日の記録はありません'
                      : '記録を選択してください',
                )
              : _EntryDetail(
                  entry: selected!,
                  onEdit: () => onEdit(selected!),
                  onDelete: () => onDelete(selected!),
                ),
        ),
      ],
    );
  }

  String _dayLabel(DateTime d) {
    const w = ['月', '火', '水', '木', '金', '土', '日'];
    return '${d.month}月${d.day}日（${w[d.weekday - 1]}）';
  }
}

// 空の詳細パネル
class _EmptyDetail extends StatelessWidget {
  final String message;
  const _EmptyDetail({this.message = '記録を選択してください'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.book_outlined,
              size: 56, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// エントリー詳細パネル
class _EntryDetail extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryDetail(
      {required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final w = weekdays[entry.date.weekday - 1];
    final dateStr =
        '${entry.date.year}年${entry.date.month}月${entry.date.day}日（$w）';

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー行
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr,
                        style: TextStyle(fontSize: 13, color: cs.outline)),
                    if (entry.title.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(entry.title,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              if (entry.mood != null) ...[
                MoodBadge(mood: entry.mood!, showLabel: true),
                const SizedBox(width: 8),
              ],
              IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: '編集'),
              IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '削除',
                  color: cs.error),
            ],
          ),
          // タグ
          if (entry.tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                children: entry.tags
                    .map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ),
          const Divider(height: 24),
          // 本文
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    entry.content,
                    style: const TextStyle(fontSize: 16, height: 1.8),
                  ),
                  // リンク
                  if (entry.links.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    ...entry.links.map((link) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.link,
                                  size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(link.label,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.blue,
                                            fontWeight: FontWeight.w500)),
                                    GestureDetector(
                                      onTap: () {
                                        Clipboard.setData(
                                            ClipboardData(text: link.url));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                          content: Text('URLをコピーしました'),
                                          duration: Duration(seconds: 1),
                                        ));
                                      },
                                      child: Text(link.url,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: cs.outline,
                                              decoration:
                                                  TextDecoration.underline)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                  // 文字数
                  const SizedBox(height: 16),
                  Text('${entry.wordCount}文字',
                      style: TextStyle(fontSize: 11, color: cs.outlineVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
