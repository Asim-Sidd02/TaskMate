// lib/widgets/note_card.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NoteCard extends StatelessWidget {
  final Map<String, dynamic> note;
  const NoteCard({Key? key, required this.note}) : super(key: key);

  String _formatDate(dynamic d) {
    try {
      final dt = DateTime.tryParse(d.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return DateFormat('d MMM').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = note['pinned'] == true ? Colors.amber.shade50 : const Color(0xFF121212);
    final textColor = note['pinned'] == true ? Colors.black : Colors.white;
    final tags = (note['tags'] ?? []) is List ? List<String>.from(note['tags']) : <String>[];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 6))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(note['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontWeight: FontWeight.bold))),
              if (note['pinned'] == true) Icon(Icons.push_pin, size: 18, color: Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              (note['content'] ?? '').toString(),
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor == Colors.white ? Colors.white70 : Colors.black87),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (tags.isNotEmpty)
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: tags.take(3).map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8)),
                      child: Text(t, style: TextStyle(color: textColor == Colors.white ? Colors.white70 : Colors.black87, fontSize: 11)),
                    )).toList(),
                  ),
                ),
              Spacer(),
              Text(_formatDate(note['updatedAt'] ?? note['createdAt'] ?? DateTime.now().toIso8601String()), style: TextStyle(color: textColor == Colors.white ? Colors.white54 : Colors.black54, fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }
}
