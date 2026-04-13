import 'package:flutter/material.dart';

const moodEmoji = {5: '😄', 4: '😊', 3: '😐', 2: '😔', 1: '😢'};
const moodLabel = {5: '最高', 4: '良い', 3: '普通', 2: '悪い', 1: '最悪'};
const moodColor = {
  5: Color(0xFF4CAF50),
  4: Color(0xFF8BC34A),
  3: Color(0xFFFFB300),
  2: Color(0xFFFF7043),
  1: Color(0xFFE53935),
};

class MoodBadge extends StatelessWidget {
  final int mood;
  final bool showLabel;

  const MoodBadge({super.key, required this.mood, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    final color = moodColor[mood] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(moodEmoji[mood] ?? '', style: const TextStyle(fontSize: 14)),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(moodLabel[mood] ?? '',
                style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
