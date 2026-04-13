import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../widgets/entry_card.dart';

class TodayView extends StatelessWidget {
  final List<DiaryEntry> entries;
  final void Function(DiaryEntry) onSelect;
  final void Function(DiaryEntry) onEdit;
  final VoidCallback onAdd;

  const TodayView({
    super.key,
    required this.entries,
    required this.onSelect,
    required this.onEdit,
    required this.onAdd,
  });

  List<DiaryEntry> get _todayEntries {
    final now = DateTime.now();
    return entries
        .where((e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day)
        .toList();
  }

  List<DiaryEntry> get _onThisDay {
    final now = DateTime.now();
    return entries
        .where((e) =>
            e.date.month == now.month &&
            e.date.day == now.day &&
            e.date.year != now.year)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int get _currentStreak {
    if (entries.isEmpty) return 0;
    final dates = entries.map((e) {
      final d = e.date;
      return DateTime(d.year, d.month, d.day);
    }).toSet().toList()
      ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    DateTime check = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    for (final d in dates) {
      if (d == check) {
        streak++;
        check = check.subtract(const Duration(days: 1));
      } else if (d.isBefore(check)) {
        break;
      }
    }
    return streak;
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 5) return 'おやすみなさい';
    if (h < 12) return 'おはようございます';
    if (h < 17) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = _todayEntries;
    final onThisDay = _onThisDay;
    final streak = _currentStreak;
    final now = DateTime.now();
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final dateStr = DateFormat('yyyy年M月d日', 'ja').format(now) +
        '（${weekdays[now.weekday - 1]}）';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ヘッダー
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting,
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            const Spacer(),
            if (streak > 0)
              _StreakBadge(streak: streak),
          ],
        ),
        const SizedBox(height: 24),

        // 今日の記録
        Row(
          children: [
            Text('今日の記録',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const Spacer(),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('追加', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (today.isEmpty)
          _EmptyToday(onAdd: onAdd)
        else
          ...today.map((e) => EntryCard(
                entry: e,
                onTap: () => onSelect(e),
              )),

        // On This Day
        if (onThisDay.isNotEmpty) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              const Icon(Icons.history, size: 18),
              const SizedBox(width: 8),
              Text('過去の今日',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          ...onThisDay.map((e) {
            final yearsAgo = now.year - e.date.year;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 0, 0),
                  child: Text(
                    '$yearsAgo年前（${e.date.year}年）',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ),
                EntryCard(entry: e, onTap: () => onSelect(e)),
              ],
            );
          }),
        ],
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text('$streak日連続',
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyToday({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Text('📝', style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text('今日の記録をつけましょう',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text('日々の出来事を記録してみましょう',
              style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('書き始める'),
          ),
        ],
      ),
    );
  }
}
