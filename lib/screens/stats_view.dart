import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../widgets/mood_badge.dart';

class StatsView extends StatelessWidget {
  final List<DiaryEntry> entries;

  const StatsView({super.key, required this.entries});

  int get _totalWords =>
      entries.fold(0, (sum, e) => sum + e.wordCount);

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

  int get _longestStreak {
    if (entries.isEmpty) return 0;
    final dates = entries.map((e) {
      final d = e.date;
      return DateTime(d.year, d.month, d.day);
    }).toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    int longest = 1, current = 1;
    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 1;
      }
    }
    return longest;
  }

  Map<String, int> get _monthlyCount {
    final now = DateTime.now();
    final map = <String, int>{};
    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      final key = DateFormat('M月', 'ja').format(d);
      map[key] = 0;
    }
    for (final e in entries) {
      final diff = (now.year - e.date.year) * 12 + now.month - e.date.month;
      if (diff >= 0 && diff < 6) {
        final key = DateFormat('M月', 'ja').format(e.date);
        map[key] = (map[key] ?? 0) + 1;
      }
    }
    return map;
  }

  Map<String, int> get _tagCount {
    final map = <String, int>{};
    for (final e in entries) {
      for (final t in e.tags) {
        map[t] = (map[t] ?? 0) + 1;
      }
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(6));
  }

  Map<int, int> get _moodCount {
    final map = <int, int>{};
    for (final e in entries) {
      if (e.mood != null) {
        map[e.mood!] = (map[e.mood!] ?? 0) + 1;
      }
    }
    return map;
  }

  Map<int, int> get _weekdayCount {
    final map = <int, int>{for (int i = 1; i <= 7; i++) i: 0};
    for (final e in entries) {
      map[e.date.weekday] = (map[e.date.weekday] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final monthly = _monthlyCount;
    final maxMonthly = monthly.values.fold(0, (a, b) => a > b ? a : b);
    final tags = _tagCount;
    final maxTag = tags.values.fold(0, (a, b) => a > b ? a : b);
    final moods = _moodCount;
    final weekday = _weekdayCount;
    final maxWd = weekday.values.fold(0, (a, b) => a > b ? a : b);
    final weekdayNames = ['月', '火', '水', '木', '金', '土', '日'];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('統計', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),

        // サマリーカード
        Row(
          children: [
            _StatCard(icon: '📝', label: '総記録数', value: '${entries.length}件', color: cs.primaryContainer),
            const SizedBox(width: 12),
            _StatCard(icon: '🔥', label: '現在の連続', value: '$_currentStreak日', color: cs.secondaryContainer),
            const SizedBox(width: 12),
            _StatCard(icon: '🏆', label: '最長連続', value: '$_longestStreak日', color: cs.tertiaryContainer),
            const SizedBox(width: 12),
            _StatCard(icon: '✍️', label: '総文字数', value: '${_totalWords}文字', color: cs.surfaceContainerHighest),
          ],
        ),
        const SizedBox(height: 28),

        // 月別棒グラフ
        _ChartSection(
          title: '月別記録数（直近6ヶ月）',
          child: SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: monthly.entries.map((e) {
                final ratio = maxMonthly == 0 ? 0.0 : e.value / maxMonthly;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (e.value > 0)
                          Text('${e.value}',
                              style: TextStyle(fontSize: 10, color: cs.primary)),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: ratio * 80,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(e.key,
                            style: TextStyle(fontSize: 10, color: cs.outline)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 20),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // タグランキング
            Expanded(
              child: _ChartSection(
                title: 'タグ上位',
                child: tags.isEmpty
                    ? const Text('タグなし', style: TextStyle(color: Colors.grey))
                    : Column(
                        children: tags.entries.map((e) {
                          final ratio = maxTag == 0 ? 0.0 : e.value / maxTag;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                    width: 48,
                                    child: Text(e.key,
                                        style: const TextStyle(fontSize: 12))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(4),
                                          )),
                                      FractionallySizedBox(
                                        widthFactor: ratio,
                                        child: Container(
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: cs.secondary,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${e.value}',
                                    style: TextStyle(fontSize: 11, color: cs.outline)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(width: 16),

            // 気分分布
            Expanded(
              child: _ChartSection(
                title: '気分の記録',
                child: moods.isEmpty
                    ? const Text('気分の記録なし', style: TextStyle(color: Colors.grey))
                    : Column(
                        children: [5, 4, 3, 2, 1].where((m) => moods.containsKey(m)).map((m) {
                          final count = moods[m] ?? 0;
                          final total = moods.values.fold(0, (a, b) => a + b);
                          final pct = total == 0 ? 0.0 : count / total;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text(moodEmoji[m] ?? '', style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: cs.surfaceContainerHighest,
                                            borderRadius: BorderRadius.circular(4),
                                          )),
                                      FractionallySizedBox(
                                        widthFactor: pct,
                                        child: Container(
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: (moodColor[m] ?? cs.primary).withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('$count',
                                    style: TextStyle(fontSize: 11, color: cs.outline)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 曜日別
        _ChartSection(
          title: '曜日別記録数',
          child: SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final wd = i + 1;
                final count = weekday[wd] ?? 0;
                final ratio = maxWd == 0 ? 0.0 : count / maxWd;
                final isSat = wd == 6;
                final isSun = wd == 7;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (count > 0)
                          Text('$count',
                              style: TextStyle(fontSize: 9, color: cs.outline)),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          height: ratio * 50 + (count > 0 ? 4 : 0),
                          decoration: BoxDecoration(
                            color: isSun
                                ? cs.error
                                : isSat
                                    ? cs.tertiary
                                    : cs.primary,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(weekdayNames[i],
                            style: TextStyle(
                                fontSize: 11,
                                color: isSun
                                    ? cs.error
                                    : isSat
                                        ? cs.tertiary
                                        : cs.onSurface)),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
