import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/concern.dart';
import '../models/comment.dart';
import '../models/audit_trail.dart';
import '../services/concern_service.dart';
import '../services/providers.dart';
import '../services/ai_service.dart';
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
  bool _isAiThinking = false;
  late bool _isPublic;

  @override
  void initState() {
    super.initState();
    // SECURE: Students only see 1 tab (Conversation). Admin sees 3 (Conversation, Details, Audit).
    _tabController = TabController(length: widget.isAdmin ? 3 : 1, vsync: this);
    _isPublic = widget.concern.isPublic;
    
    if (!widget.isAdmin) {
      Future.delayed(const Duration(seconds: 1), _triggerAiInitialGreeting);
    }

    if (widget.isAdmin && 
       (widget.concern.status == ConcernStatus.submitted || widget.concern.status == ConcernStatus.routed)) {
      Future.microtask(() => _updateStatus(ConcernStatus.read));
    }
  }

  Future<void> _updateStatus(ConcernStatus status) async {
    try {
      final userId = ref.read(userIdProvider) ?? 'user_id';
      await ref.read(concernServiceProvider).updateStatus(widget.concern.id, status, userId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  void _showResolveConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Concern?'),
        content: const Text('Are you sure you want to mark this concern as RESOLVED? This will notify the student and close the conversation.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus(ConcernStatus.resolved);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('YES, RESOLVED'),
          ),
        ],
      ),
    );
  }

  void _togglePublic(bool value) async {
    final userId = ref.read(userIdProvider) ?? 'staff_id';
    await ref.read(concernServiceProvider).togglePublicStatus(widget.concern.id, value, userId);
    setState(() => _isPublic = value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Published to Community Knowledge Base' : 'Removed from Public View'),
          backgroundColor: value ? Colors.green : Colors.grey,
        ),
      );
    }
  }

  void _sendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final text = _commentController.text.trim();
    final userId = ref.read(userIdProvider) ?? (widget.isAdmin ? 'staff_id' : widget.concern.studentId);
    
    final comment = Comment(
      id: const Uuid().v4(),
      concernId: widget.concern.id,
      senderId: userId,
      senderName: widget.isAdmin ? 'Staff Support' : (widget.concern.isAnonymous ? 'Anonymous' : widget.concern.studentName),
      message: text,
      timestamp: DateTime.now(),
      isInternal: widget.isAdmin ? _isInternalNote : false,
    );

    await ref.read(concernServiceProvider).addComment(comment);
    _commentController.clear();

    if (!widget.isAdmin) {
      _handleAiAutoReply(text);
    }
    
    if (widget.isAdmin && !_isInternalNote && widget.concern.status == ConcernStatus.read) {
      _updateStatus(ConcernStatus.screened);
    }

    setState(() => _isInternalNote = false);
  }

  void _handleAiAutoReply(String studentMessage) async {
    setState(() => _isAiThinking = true);
    final result = await ref.read(aiServiceProvider).analyzeConcern(studentMessage);
    
    if (mounted && result['suggestedSolution'] != null) {
      _sendAiResponse(result['suggestedSolution']);
    } else {
      setState(() => _isAiThinking = false);
    }
  }

  void _triggerAiInitialGreeting() async {
    final comments = await ref.read(concernServiceProvider).getComments(widget.concern.id).first;
    if (comments.isEmpty) {
      _sendAiResponse("Hello! I am the GRC Smart Assistant. 🤖\n\nI have notified our staff about your concern. While waiting, feel free to ask me questions about GRC scholarships, CCS department, or school policies!");
    }
  }

  void _sendAiResponse(String message) async {
    if (!mounted) return;
    setState(() => _isAiThinking = true);
    await Future.delayed(const Duration(seconds: 1));

    final aiComment = Comment(
      id: const Uuid().v4(),
      concernId: widget.concern.id,
      senderId: 'ai_system',
      senderName: 'GRC AI Assistant ✨',
      message: message,
      timestamp: DateTime.now(),
      isInternal: false,
    );

    await ref.read(concernServiceProvider).addComment(aiComment);
    if (mounted) setState(() => _isAiThinking = false);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: _buildAppBar(isDark),
      body: Column(
        children: [
          _buildStatusBar(isDark),
          _buildTabHeader(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildMessagesTab(isDark),
                if (widget.isAdmin) ...[
                  _buildDetailsTab(isDark),
                  _buildAuditTab(isDark),
                ],
              ],
            ),
          ),
          if (widget.concern.status != ConcernStatus.resolved) ...[
            if (_isAiThinking) 
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('AI is typing...', style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
              ),
            _buildInputArea(isDark),
          ],
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      foregroundColor: isDark ? Colors.white : const Color(0xFF1E293B),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.concern.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text('CASE ID: ${widget.concern.id.substring(0, 8).toUpperCase()}', 
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
      actions: [
        if (widget.isAdmin && widget.concern.status != ConcernStatus.resolved)
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
            onPressed: _showResolveConfirmation,
            tooltip: 'Mark as Resolved',
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatusBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          _statusBadge(widget.concern.status),
          const Spacer(),
          Icon(Icons.calendar_today, size: 12, color: isDark ? Colors.white38 : Colors.grey),
          const SizedBox(width: 6),
          Text(DateFormat('MMM dd, yyyy').format(widget.concern.createdAt), 
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTabHeader(bool isDark) {
    // If student, don't even show the tab bar to keep it clean (since it's only 1 tab)
    if (!widget.isAdmin) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: isDark ? Colors.redAccent : Colors.indigo,
        unselectedLabelColor: isDark ? Colors.white38 : Colors.grey,
        indicatorColor: isDark ? Colors.redAccent : Colors.indigo,
        indicatorWeight: 3,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        tabs: const [
          Tab(text: 'CONVERSATION'),
          Tab(text: 'CASE DETAILS'),
          Tab(text: 'AUDIT LOG'),
        ],
      ),
    );
  }

  Widget _buildMessagesTab(bool isDark) {
    final commentsStream = ref.watch(concernServiceProvider).getComments(widget.concern.id);
    return Column(
      children: [
        _buildConcernDescriptionCard(isDark),
        Expanded(
          child: StreamBuilder<List<Comment>>(
            stream: commentsStream,
            builder: (context, snapshot) {
              final comments = (snapshot.data ?? []).where((c) => widget.isAdmin || !c.isInternal).toList();
              if (comments.isEmpty) return const Center(child: Text('Connecting to GRC Support...'));
              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: comments.length,
                itemBuilder: (context, index) => _commentBubble(comments[index], isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConcernDescriptionCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.indigo.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.indigo.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('INITIAL COMPLAINT', 
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.redAccent : Colors.indigo, letterSpacing: 1)
          ),
          const SizedBox(height: 8),
          Text(widget.concern.description, 
            style: TextStyle(fontSize: 14, height: 1.5, color: isDark ? Colors.white70 : const Color(0xFF334155))
          ),
        ],
      ),
    );
  }

  Widget _commentBubble(Comment comment, bool isDark) {
    bool isMe = comment.senderId == ref.read(userIdProvider);
    bool isAi = comment.senderId == 'ai_system';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isAi ? (isDark ? Colors.indigo.withOpacity(0.2) : Colors.indigo[50]) : (isMe ? (isDark ? Colors.redAccent : Colors.indigo) : (isDark ? const Color(0xFF334155) : Colors.white)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isAi ? (isDark ? Colors.indigo.withOpacity(0.3) : Colors.indigo[100]!) : (isDark ? Colors.transparent : const Color(0xFFE2E8F0))),
          boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(comment.senderName, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isAi ? Colors.indigoAccent : (isDark ? Colors.white38 : Colors.blueGrey))),
            const SizedBox(height: 4),
            Text(comment.message, style: TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : const Color(0xFF1E293B)), fontSize: 13)),
            const SizedBox(height: 4),
            Text(DateFormat('hh:mm a').format(comment.timestamp), 
              style: TextStyle(fontSize: 9, color: isMe ? (isDark ? Colors.white60 : Colors.white60) : (isDark ? Colors.white38 : Colors.grey))),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _infoSection('Student Information', [
          _infoRow('Name', widget.concern.isAnonymous ? 'Restricted (Anonymous)' : widget.concern.studentName, isDark),
          _infoRow('Program', widget.concern.program, isDark),
          _infoRow('College', widget.concern.department, isDark),
        ], isDark),
        const SizedBox(height: 20),
        _infoSection('Routing Details', [
          _infoRow('Category', widget.concern.category.name.toUpperCase(), isDark),
          _infoRow('Assigned To', widget.concern.assignedTo ?? 'Not Assigned', isDark),
        ], isDark),
        const SizedBox(height: 20),
        if (widget.concern.status == ConcernStatus.resolved)
          _infoSection('Knowledge Base Settings', [
            SwitchListTile(
              title: const Text('Publish to Community', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: const Text('Let other students see the resolution of this concern anonymously.', style: TextStyle(fontSize: 11)),
              value: _isPublic,
              onChanged: _togglePublic,
              activeColor: Colors.green,
            ),
          ], isDark),
      ],
    );
  }

  Widget _buildAuditTab(bool isDark) {
    final auditStream = ref.watch(concernServiceProvider).getAuditTrail(widget.concern.id);
    return StreamBuilder<List<AuditLog>>(
      stream: auditStream,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        if (logs.isEmpty) return const Center(child: Text('No logs found.'));
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: logs.length,
          itemBuilder: (context, index) => _auditItem(logs[index], isDark),
        );
      },
    );
  }

  Widget _auditItem(AuditLog log, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white, 
        borderRadius: BorderRadius.circular(8), 
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFF1F5F9))
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 16, backgroundColor: isDark ? Colors.white10 : Colors.blueGrey[50]!, child: Icon(Icons.history, size: 14, color: isDark ? Colors.redAccent : Colors.blueGrey)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(log.action.replaceAll('_', ' '), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87)),
              Text(log.details, style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey)),
            ]),
          ),
          Text(DateFormat('HH:mm').format(log.timestamp), style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white, 
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)))
      ),
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
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: _isInternalNote ? 'Type private note...' : 'Send a reply...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF334155) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: _isInternalNote ? Colors.amber : (isDark ? Colors.redAccent : Colors.indigo),
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _sendComment),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<Widget> children, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: isDark ? Colors.redAccent : Colors.indigo)),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey)),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E293B))),
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
