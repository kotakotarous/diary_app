import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import '../widgets/entry_card.dart';

class TimelineView extends StatelessWidget {
  final List<DiaryEntry> entries;
  final DiaryEntry? selected;
  final void Function(DiaryEntry) onSelect;

  const TimelineView({
    super.key,
    required this.entries,
    required this.selected,
    required this.onSelect,
  });

  Map<String, List<DiaryEntry>> get _grouped {
    final map = <String, List<DiaryEntry>>{};
    for (final e in entries) {
      final key = DateFormat('yyyy年M月', 'ja').format(e.date);
      map.putIfAbsent(key, () => []).add(e);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📖', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('まだ記録がありません', style: TextStyle(fontSize: 15, color: Colors.grey)),
          ],
        ),
      );
    }

    final grouped = _grouped;
    final months = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: months.length,
      itemBuilder: (_, i) {
        final month = months[i];
        final monthEntries = grouped[month]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(month,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  ),
                  const SizedBox(width: 8),
                  Text('${monthEntries.length}件',
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                ],
              ),
            ),
            ...monthEntries.map((e) => EntryCard(
                  entry: e,
                  isSelected: selected?.id == e.id,
                  onTap: () => onSelect(e),
                )),
          ],
        );
      },
    );
  }
}
