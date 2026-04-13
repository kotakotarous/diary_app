import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';
import 'mood_badge.dart';

class EntryCard extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool compact;

  const EntryCard({
    super.key,
    required this.entry,
    this.onTap,
    this.isSelected = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final w = weekdays[entry.date.weekday - 1];
    final dateStr = DateFormat('yyyy年M月d日', 'ja').format(entry.date) + '（$w）';

    return Card(
      margin: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: isSelected ? 3 : 1,
      color: isSelected ? cs.primaryContainer : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: cs.primary, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                  const Spacer(),
                  if (entry.mood != null) MoodBadge(mood: entry.mood!),
                ],
              ),
              if (entry.title.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(entry.title,
                    style: TextStyle(
                        fontSize: compact ? 13 : 15,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
              ],
              const SizedBox(height: 4),
              Text(
                entry.content,
                maxLines: compact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    color: cs.onSurfaceVariant,
                    height: 1.5),
              ),
              if (entry.tags.isNotEmpty || entry.links.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    ...entry.tags.take(3).map((tag) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: _TagChip(tag: tag),
                        )),
                    if (entry.links.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.link, size: 13, color: cs.primary),
                      Text(' ${entry.links.length}',
                          style: TextStyle(fontSize: 11, color: cs.primary)),
                    ],
                    const Spacer(),
                    Text('${entry.wordCount}文字',
                        style: TextStyle(fontSize: 10, color: cs.outlineVariant)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(tag,
          style: TextStyle(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSecondaryContainer)),
    );
  }
}
