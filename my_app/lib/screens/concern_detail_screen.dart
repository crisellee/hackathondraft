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

class _ConcernDetailScreenState extends ConsumerState<ConcernDetailScreen> with TickerProviderStateMixin {
  final _commentController = TextEditingController();
  late TabController _tabController;
  bool _isInternalNote = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isAdmin ? 3 : 2, vsync: this);
    
    // Auto-mark as READ if admin opens a new/routed concern
    if (widget.isAdmin && 
       (widget.concern.status == ConcernStatus.submitted || widget.concern.status == ConcernStatus.routed)) {
      Future.microtask(() => _updateStatus(ConcernStatus.read));
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _updateStatus(ConcernStatus status) async {
    final userId = ref.read(userIdProvider) ?? 'admin_user';
    await ref.read(concernServiceProvider).updateStatus(widget.concern.id, status, userId);
  }

  void _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final userId = ref.read(userIdProvider) ?? (widget.isAdmin ? 'staff_id' : widget.concern.studentId);
    
    final comment = Comment(
      id: const Uuid().v4(),
      concernId: widget.concern.id,
      senderId: userId,
      senderName: widget.isAdmin ? 'Staff Support' : (widget.concern.isAnonymous ? 'Anonymous' : widget.concern.studentName),
      message: _commentController.text.trim(),
      timestamp: DateTime.now(),
      isInternal: widget.isAdmin ? _isInternalNote : false,
    );

    await ref.read(concernServiceProvider).addComment(comment);
    
    if (widget.isAdmin && !_isInternalNote && widget.concern.status == ConcernStatus.read) {
      _updateStatus(ConcernStatus.screened);
    }

    _commentController.clear();
    setState(() => _isInternalNote = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatusBar(),
          _buildTabHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMessagesTab(),
                if (widget.isAdmin) _buildDetailsTab(),
                _buildAuditTab(),
              ],
            ),
          ),
          if (widget.concern.status != ConcernStatus.resolved) _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.concern.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('CASE ID: ${widget.concern.id.substring(0, 8).toUpperCase()}', 
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
      actions: [
        if (widget.isAdmin)
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
            onPressed: () => _updateStatus(ConcernStatus.resolved),
            tooltip: 'Mark as Resolved',
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _statusBadge(widget.concern.status),
          const Spacer(),
          const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
          const SizedBox(width: 6),
          Text(DateFormat('MMM dd, yyyy').format(widget.concern.createdAt), 
            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTabHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.indigo,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.indigo,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        tabs: [
          const Tab(text: 'CONVERSATION'),
          if (widget.isAdmin) const Tab(text: 'CASE DETAILS'),
          const Tab(text: 'AUDIT LOG'),
        ],
      ),
    );
  }

  Widget _buildMessagesTab() {
    final commentsStream = ref.watch(concernServiceProvider).getComments(widget.concern.id);
    return Column(
      children: [
        _buildConcernDescriptionCard(),
        Expanded(
          child: StreamBuilder<List<Comment>>(
            stream: commentsStream,
            builder: (context, snapshot) {
              final comments = (snapshot.data ?? []).where((c) => widget.isAdmin || !c.isInternal).toList();
              if (comments.isEmpty) return const Center(child: Text('No messages yet.'));
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: comments.length,
                itemBuilder: (context, index) => _commentBubble(comments[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConcernDescriptionCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('INITIAL COMPLAINT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.indigo, letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(widget.concern.description, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF334155))),
        ],
      ),
    );
  }

  Widget _commentBubble(Comment comment) {
    bool isMe = comment.senderId == ref.read(userIdProvider) || 
                (widget.isAdmin && comment.senderName == 'Staff Support');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: comment.isInternal ? Colors.amber[50] : (isMe ? Colors.indigo : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: comment.isInternal ? Colors.amber[200]! : const Color(0xFFE2E8F0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (comment.isInternal)
              const Text('INTERNAL NOTE', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.amber)),
            if (!isMe)
              Text(comment.senderName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: comment.isInternal ? Colors.brown : Colors.indigo)),
            const SizedBox(height: 4),
            Text(comment.message, style: TextStyle(color: isMe ? Colors.white : const Color(0xFF1E293B), fontSize: 13)),
            const SizedBox(height: 4),
            Text(DateFormat('hh:mm a').format(comment.timestamp), 
              style: TextStyle(fontSize: 9, color: isMe ? Colors.white60 : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoSection('Student Information', [
          _infoRow('Name', widget.concern.isAnonymous ? 'Restricted (Anonymous)' : widget.concern.studentName),
          _infoRow('Program', widget.concern.program),
          _infoRow('College', widget.concern.department),
        ]),
        const SizedBox(height: 20),
        _infoSection('Routing Details', [
          _infoRow('Category', widget.concern.category.name.toUpperCase()),
          _infoRow('Assigned To', widget.concern.assignedTo ?? 'Not Assigned'),
        ]),
      ],
    );
  }

  Widget _buildAuditTab() {
    final auditStream = ref.watch(concernServiceProvider).getAuditTrail(widget.concern.id);
    return StreamBuilder<List<AuditLog>>(
      stream: auditStream,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) return const Center(child: Text('No logs found.'));
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: logs.length,
          itemBuilder: (context, index) => _auditItem(logs[index]),
        );
      },
    );
  }

  Widget _auditItem(AuditLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFF1F5F9))),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: Colors.blueGrey[50]!, child: const Icon(Icons.history, size: 14, color: Colors.blueGrey)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(log.action.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(log.details, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ]),
          ),
          Text(DateFormat('HH:mm').format(log.timestamp), style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
      child: Column(
        children: [
          if (widget.isAdmin)
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 14, color: Colors.amber),
                const SizedBox(width: 6),
                const Text('Internal Note', style: TextStyle(fontSize: 11, color: Colors.amber, fontWeight: FontWeight.bold)),
                const Spacer(),
                Switch(
                  value: _isInternalNote, 
                  onChanged: (v) => setState(() => _isInternalNote = v),
                  activeColor: Colors.amber,
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _isInternalNote ? 'Type private note...' : 'Send a reply...',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _isInternalNote ? Colors.amber : Colors.indigo,
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _sendComment),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.indigo)),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }

  Widget _statusBadge(ConcernStatus status) {
    Color color = Colors.blue;
    if (status == ConcernStatus.resolved) color = Colors.green;
    if (status == ConcernStatus.escalated) color = Colors.red;
    if (status == ConcernStatus.read) color = Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}
