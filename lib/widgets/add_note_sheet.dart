// lib/widgets/add_note_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../services/note_service.dart';

class AddNoteSheet extends StatefulWidget {
  final Map<String, dynamic>? existingNote;
  const AddNoteSheet({Key? key, this.existingNote}) : super(key: key);

  @override
  State<AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends State<AddNoteSheet> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  bool pinned = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existingNote?['title'] ?? '');
    _content = TextEditingController(text: widget.existingNote?['content'] ?? '');
    pinned = widget.existingNote?['pinned'] == true;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final svc = context.read<NoteService>();
    final title = _title.text.trim();
    final content = _content.text.trim();

    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add a title or content')));
      return;
    }

    setState(() => saving = true);
    bool ok = false;
    if (widget.existingNote != null) {
      final id = widget.existingNote!['_id'] ?? widget.existingNote!['id'];
      ok = await svc.updateNote(id, {'title': title, 'content': content, 'pinned': pinned});
    } else {
      ok = await svc.createNote(title: title, content: content, pinned: pinned);
    }
    setState(() => saving = false);
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save note')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = 18.0;
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.vertical(top: Radius.circular(radius))),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SafeArea(
            top: false,
            child: ListView(
              controller: scrollCtrl,
              children: [
                Center(
                  child: Container(width: 60, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(8))),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(widget.existingNote != null ? 'Edit note' : 'New note', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Row(children: [
                    IconButton(
                      onPressed: () => setState(() => pinned = !pinned),
                      icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined, color: pinned ? Colors.amber : Colors.white54),
                    ),
                    IconButton(onPressed: () {
                      if (widget.existingNote != null) {
                        // delete confirmation
                        showDialog(context: context, builder: (ctx) {
                          return AlertDialog(
                            title: const Text('Delete note?'),
                            content: const Text('This cannot be undone'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              TextButton(onPressed: () async {
                                Navigator.pop(ctx);
                                final svc = context.read<NoteService>();
                                final id = widget.existingNote!['_id'] ?? widget.existingNote!['id'];
                                final ok = await svc.deleteNote(id);
                                if (ok) Navigator.of(context).pop(true);
                                else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
                              }, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                            ],
                          );
                        });
                      } else {
                        _title.clear();
                        _content.clear();
                      }
                    }, icon: const Icon(Icons.delete_outline, color: Colors.white54)),
                  ],)
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Title',
                    hintStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: const Color(0xFF121212),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _content,
                  maxLines: 10,
                  style: const TextStyle(color: Colors.white70),
                  decoration: InputDecoration(
                    hintText: 'Write your notes here...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F0F10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.existingNote != null ? 'Save changes' : 'Create note', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
