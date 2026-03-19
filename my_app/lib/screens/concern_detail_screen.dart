import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/concern.dart';
import '../models/comment.dart';
import '../models/audit_trail.dart';
import '../services/concern_service.dart';
import '../services/providers.dart';
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
  bool _isInternalNote = false; // NEW: Toggle for private admin notes

  @override
  void initState() {
    super.initState();
    // AUTOMATIC READ: If admin opens a new/routed concern, mark it as READ
    if (widget.isAdmin && 
       (widget.concern.status == ConcernStatus.submitted || widget.concern.status == ConcernStatus.routed)) {
      Future.microtask(() => _updateStatus(ConcernStatus.read));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final userId = ref.read(userIdProvider) ?? (widget.isAdmin ? 'admin_id' : widget.concern.studentId);
    
    final comment = Comment(
      id: const Uuid().v4(),
      concernId: widget.concern.id,
      senderId: userId,
      senderName: widget.isAdmin ? 'Admin/Staff' : (widget.concern.isAnonymous ? 'Anonymous Student' : widget.concern.studentName),
      message: _commentController.text.trim(),
      timestamp: DateTime.now(),
      isInternal: widget.isAdmin ? _isInternalNote : false,
    );

    await ref.read(concernServiceProvider).addComment(comment);
    
    // AUTOMATIC SCREENED: If admin replies publicly, change status to SCREENED
    if (widget.isAdmin && !_isInternalNote && widget.concern.status == ConcernStatus.read) {
      _updateStatus(ConcernStatus.screened);
    }

    _commentController.clear();
    setState(() => _isInternalNote = false);
  }

  void _updateStatus(ConcernStatus status) async {
    final userId = ref.read(userIdProvider) ?? 'admin_user';
    await ref.read(concernServiceProvider).updateStatus(widget.concern.id, status, userId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to ${status.name.toUpperCase()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsStream = ref.watch(concernServiceProvider).getComments(widget.concern.id);
    final auditStream = ref.watch(concernServiceProvider).getAuditTrail(widget.concern.id);
    final currentUserId = ref.watch(userIdProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.concern.title),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.chat), text: 'Messages'),
              Tab(icon: Icon(Icons.history), text: 'Audit Trail'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                _buildStatusTracker(),
                _buildConcernHeader(),
                Expanded(
                  child: StreamBuilder<List<Comment>>(
                    stream: commentsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Colors.red));
                      }
                      var comments = snapshot.data ?? [];
                      
                      // SECURITY: Hide internal notes from students
                      if (!widget.isAdmin) {
                        comments = comments.where((c) => !c.isInternal).toList();
                      }

                      if (comments.isEmpty) {
                        return const Center(child: Text('No messages yet.', style: TextStyle(color: Colors.grey)));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          final isMe = comment.senderId == currentUserId || 
                                       (currentUserId == null && comment.senderId == (widget.isAdmin ? 'admin_id' : widget.concern.studentId));
                          return _buildCommentBubble(comment, isMe);
                        },
                      );
                    },
                  ),
                ),
                if (widget.concern.status != ConcernStatus.resolved) ...[
                  _buildCommentInput(),
                  if (widget.isAdmin) _buildAdminStatusActions(),
                ] else ...[
                  _buildResolvedSection(),
                ],
              ],
            ),
            
            // Tab 2: Audit Trail
            StreamBuilder<List<AuditLog>>(
              stream: auditStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.red));
                }
                final logs = snapshot.data ?? [];
                if (logs.isEmpty) {
                  return const Center(child: Text('No audit logs available.', style: TextStyle(color: Colors.grey)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getActionColor(log.action),
                          child: Icon(_getActionIcon(log.action), color: Colors.white, size: 20),
                        ),
                        title: Text(log.action.replaceAll('_', ' ').toUpperCase(), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.details, style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text('Actor: ${log.actorId}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        trailing: Text(DateFormat('MMM dd, HH:mm').format(log.timestamp), 
                          style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTracker() {
    final statuses = [
      ConcernStatus.submitted,
      ConcernStatus.read,
      ConcernStatus.screened,
      ConcernStatus.resolved,
    ];

    int currentIndex = statuses.indexOf(widget.concern.status);
    if (widget.concern.status == ConcernStatus.routed) currentIndex = 0;
    if (widget.concern.status == ConcernStatus.escalated) currentIndex = 2;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: List.generate(statuses.length, (index) {
          bool isCompleted = index <= currentIndex;
          bool isLast = index == statuses.length - 1;
          Color color = isCompleted ? Colors.red : Colors.grey[300]!;

          return Expanded(
            child: Row(
              children: [
                Column(
                  children: [
                    Icon(
                      isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: color,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statuses[index].name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(bottom: 15),
                      color: index < currentIndex ? Colors.red : Colors.grey[200],
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildConcernHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                child: Text(widget.concern.category.name.toUpperCase(), 
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
              ),
              const SizedBox(width: 8),
              Text('ID: ${widget.concern.id.substring(0, 8).toUpperCase()}', 
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(widget.concern.description, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(Comment comment, bool isMe) {
    Color bubbleColor = isMe ? Colors.red : Colors.grey[200]!;
    Color textColor = isMe ? Colors.white : Colors.black87;

    // Style for INTERNAL NOTES (Yellowish background)
    if (comment.isInternal) {
      bubbleColor = Colors.amber.shade100;
      textColor = Colors.black87;
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(12),
          border: comment.isInternal ? Border.all(color: Colors.amber.shade300) : null,
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment.isInternal)
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock, size: 10, color: Colors.amber),
                  SizedBox(width: 4),
                  Text('INTERNAL NOTE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.amber)),
                ],
              ),
            if (!isMe && !comment.isInternal)
              Text(comment.senderName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(comment.message, style: TextStyle(color: textColor)),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(comment.timestamp),
              style: TextStyle(fontSize: 9, color: isMe ? Colors.white70 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey[200]!))),
      child: Column(
        children: [
          if (widget.isAdmin)
            Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('Private Note', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isInternalNote,
                    onChanged: (v) => setState(() => _isInternalNote = v),
                    activeColor: Colors.amber,
                  ),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _isInternalNote ? 'Type a private admin note...' : 'Type your message...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: _isInternalNote ? Colors.amber : Colors.red),
                onPressed: _sendComment
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        border: Border(top: BorderSide(color: Colors.green[100]!)),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('CONCERN RESOLVED', 
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
          if (!widget.isAdmin) ...[
            const SizedBox(height: 12),
            const Text('Not satisfied with the resolution?', style: TextStyle(fontSize: 12, color: Colors.black54)),
            TextButton(
              onPressed: () => _updateStatus(ConcernStatus.screened),
              child: const Text('REOPEN CONCERN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminStatusActions() {
    final statuses = [
      ConcernStatus.read,
      ConcernStatus.screened,
      ConcernStatus.resolved,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('UPDATE STATUS:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: statuses.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(s.name.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey[300]!),
                  onPressed: () => _updateStatus(s),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor(String action) {
    switch (action) {
      case 'SUBMITTED': return Colors.blue;
      case 'ROUTED': return Colors.purple;
      case 'STATUS_UPDATE': return Colors.orange;
      case 'MESSAGE': return Colors.teal;
      case 'ESCALATION': return Colors.red;
      case 'DEPARTMENT_UPDATE': return Colors.brown;
      default: return Colors.grey;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'SUBMITTED': return Icons.send;
      case 'ROUTED': return Icons.alt_route;
      case 'STATUS_UPDATE': return Icons.update;
      case 'MESSAGE': return Icons.message;
      case 'ESCALATION': return Icons.warning;
      case 'DEPARTMENT_UPDATE': return Icons.business;
      default: return Icons.history;
    }
  }
}
