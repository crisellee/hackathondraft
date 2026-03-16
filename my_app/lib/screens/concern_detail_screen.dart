import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/concern.dart';
import '../models/comment.dart';
import '../services/concern_service.dart';
import 'package:intl/intl.dart';


class ConcernDetailScreen extends ConsumerStatefulWidget {
  final Concern concern;
  final bool isAdmin;


  const ConcernDetailScreen({
    super.key,
    required this.concern,
    this.isAdmin = false,
  });


  @override
  ConsumerState<ConcernDetailScreen> createState() => _ConcernDetailScreenState();
}


class _ConcernDetailScreenState extends ConsumerState<ConcernDetailScreen> {
  final _commentController = TextEditingController();


  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }


  void _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;


    final comment = Comment(
      id: const Uuid().v4(),
      concernId: widget.concern.id,
      senderId: widget.isAdmin ? 'admin_id' : widget.concern.studentId,
      senderName: widget.isAdmin ? 'Admin/Staff' : (widget.concern.isAnonymous ? 'Anonymous Student' : widget.concern.studentName),
      message: _commentController.text.trim(),
      timestamp: DateTime.now(),
    );


    await ref.read(concernServiceProvider).addComment(comment);
    _commentController.clear();
  }


  @override
  Widget build(BuildContext context) {
    final commentsStream = ref.watch(concernServiceProvider).getComments(widget.concern.id);


    return Scaffold(
      appBar: AppBar(
        title: Text(widget.concern.title),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Comment>>(
              stream: commentsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.red));
                }

                final comments = snapshot.data ?? [];

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildConcernInfo();
                    }
                    final comment = comments[index - 1];
                    final isMe = comment.senderId == (widget.isAdmin ? 'admin_id' : widget.concern.studentId);

                    return _buildCommentBubble(comment, isMe);
                  },
                );
              },
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }


  Widget _buildConcernInfo() {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: \${widget.concern.category.name.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(widget.concern.description),
            const Divider(height: 24),
            const Text('Interaction History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
      ),
    );
  }


  Widget _buildCommentBubble(Comment comment, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.red.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              comment.senderName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMe ? Colors.red : Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(comment.message),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(comment.timestamp),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.red),
            onPressed: _sendComment,
          ),
        ],
      ),
    );
  }
}

