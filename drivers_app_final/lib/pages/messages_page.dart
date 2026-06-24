import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';
import '../widgets/snackbar_helper.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with AutomaticKeepAliveClientMixin<MessagesPage> {
  final _supabase = Supabase.instance.client;
  List<_ConversationItem> _conversations = [];
  List<Map<String, dynamic>> _adminMessages = [];
  bool _isLoading = true;
  String? _myId;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Realtime channels
  RealtimeChannel? _adminChannel;
  RealtimeChannel? _driverMsgChannel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _myId = _supabase.auth.currentUser?.id;
    _loadAll();
    _subscribeToRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _adminChannel?.unsubscribe();
    _driverMsgChannel?.unsubscribe();
    super.dispose();
  }

  // ── Data Loading ──────────────────────────────────────────────

  Future<void> _loadAll() async {
    await Future.wait([_loadAdminMessages(), _loadConversations()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAdminMessages() async {
    try {
      final data = await _supabase.from('admin_messages').select()
          .or('recipient_type.eq.all_drivers,recipient_type.eq.all,and(recipient_type.eq.single_driver,recipient_id.eq.$_myId)')
          .not('is_deleted_by_recipient', 'eq', true)
          .order('created_at', ascending: false)
          .limit(50);
      if (mounted) {
        setState(() => _adminMessages = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      print('❌ Erreur admin messages: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      final data = await _supabase.from('driver_messages')
          .select()
          .or('sender_id.eq.$_myId,receiver_id.eq.$_myId')
          .order('created_at', ascending: false);

      final Map<String, _ConversationItem> convos = {};
      for (final msg in data) {
        final partnerId = msg['sender_id'] == _myId
            ? msg['receiver_id']?.toString()
            : msg['sender_id']?.toString();
        if (partnerId == null) continue;
        if (!convos.containsKey(partnerId)) {
          final partnerName = msg['sender_id'] == _myId
              ? (msg['receiver_name'] ?? 'Chauffeur')
              : (msg['sender_name'] ?? 'Chauffeur');
          convos[partnerId] = _ConversationItem(
            partnerId: partnerId,
            partnerName: partnerName.toString(),
            lastMessage: msg['message']?.toString() ?? '',
            lastMessageTime: msg['created_at']?.toString() ?? '',
            isFromMe: msg['sender_id'] == _myId,
            unreadCount: 0,
          );
        }
      }
      if (mounted) {
        setState(() => _conversations = convos.values.toList());
      }
    } catch (e) {
      print('❌ Erreur conversations: $e');
    }
  }

  // ── Realtime ──────────────────────────────────────────────────

  void _subscribeToRealtime() {
    if (_myId == null) return;

    _adminChannel = _supabase
        .channel('msg_page_admin_$_myId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'admin_messages',
      callback: (payload) {
        if (!mounted) return;
        final msg = payload.newRecord;
        final recipientType = msg['recipient_type']?.toString();
        final recipientId = msg['recipient_id']?.toString();
        final isForMe = recipientType == 'all_drivers' ||
            recipientType == 'all' ||
            (recipientType == 'single_driver' && recipientId == _myId);
        if (isForMe) {
          setState(() => _adminMessages.insert(0, msg));
        }
      },
    ).subscribe();

    _driverMsgChannel = _supabase
        .channel('msg_page_drivers_$_myId')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'driver_messages',
      callback: (payload) {
        if (!mounted) return;
        _loadConversations(); // Refresh conversation list
      },
    ).subscribe();
  }

  // ── Helpers ───────────────────────────────────────────────────

  String _formatTime(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return "maintenant";
      if (diff.inMinutes < 60) return "${diff.inMinutes} min";
      if (diff.inHours < 24) return "${diff.inHours}h";
      if (diff.inDays < 7) return "${diff.inDays}j";
      return "${date.day}/${date.month}";
    } catch (_) {
      return '';
    }
  }

  List<_ConversationItem> get _filteredConversations {
    if (_searchQuery.isEmpty) return _conversations;
    return _conversations
        .where((c) => c.partnerName.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // ── Navigate to driver list to start new conversation ────────

  void _showNewConversationSheet() async {
    try {
      final drivers = await _supabase
          .from('drivers')
          .select('id, name, phone')
          .neq('id', _myId ?? '')
          .order('name');

      if (!mounted) return;
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text("Nouvelle conversation",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: List<Map<String, dynamic>>.from(drivers).length,
                  itemBuilder: (_, i) {
                    final d = drivers[i];
                    final name = d['name']?.toString() ?? 'Chauffeur';
                    return ListTile(
                      leading: _buildAvatar(name, AppColors.primary),
                      title: Text(name, style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge?.color)),
                      subtitle: Text(d['phone']?.toString() ?? '',
                          style: TextStyle(fontSize: 13,
                              color: theme.textTheme.bodySmall?.color)),
                      onTap: () {
                        Navigator.pop(ctx);
                        _openChat(d['id'].toString(), name);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, "Erreur: $e");
      }
    }
  }

  void _openChat(String partnerId, String partnerName) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _DriverChatScreen(
        driverId: partnerId,
        driverName: partnerName,
        myId: _myId!,
      ),
    )).then((_) => _loadConversations());
  }

  void _openAdminChat() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _AdminChatScreen(
        adminMessages: _adminMessages,
        myId: _myId!,
        onReply: () => _loadAdminMessages(),
      ),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme, isDark),
            _buildSearchBar(theme, isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadAll,
                      child: ListView(
                        children: [
                          // Admin messages thread
                          if (_adminMessages.isNotEmpty)
                            _buildAdminThread(isDark, theme),

                          // Driver conversations
                          if (_filteredConversations.isEmpty && _adminMessages.isEmpty)
                            _buildEmptyState(isDark)
                          else
                            ..._filteredConversations.map((c) =>
                                _buildConversationTile(c, isDark, theme)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewConversationSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Messages", style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                Text("${_conversations.length} conversations",
                    style: TextStyle(fontSize: 14,
                        color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(22),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v),
          style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15),
          decoration: InputDecoration(
            hintText: "Rechercher...",
            hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade500, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  // ── Admin thread tile ─────────────────────────────────────────

  Widget _buildAdminThread(bool isDark, ThemeData theme) {
    final lastMsg = _adminMessages.first;
    final unread = _adminMessages.where((m) =>
        m['recipient_name']?.toString().startsWith('↩') != true && m['is_read'] != true).length;

    return InkWell(
      onTap: _openAdminChat,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : const Color(0xFFFFF8E1),
          border: Border(
            bottom: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.campaign, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("Le Bon Taxi",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                              color: theme.textTheme.bodyLarge?.color)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("Admin", style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            color: Color(0xFF6366F1))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg['title']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13,
                        color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_formatTime(lastMsg['created_at']?.toString()),
                    style: TextStyle(fontSize: 11,
                        color: theme.textTheme.bodySmall?.color)),
                const SizedBox(height: 4),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(unread > 9 ? "9+" : "$unread",
                        style: const TextStyle(color: Colors.white,
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Conversation tile ─────────────────────────────────────────

  Widget _buildConversationTile(_ConversationItem conv, bool isDark, ThemeData theme) {
    return InkWell(
      onTap: () => _openChat(conv.partnerId, conv.partnerName),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: isDark ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100),
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(conv.partnerName, AppColors.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv.partnerName, style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 4),
                  Text(
                    conv.isFromMe ? "Vous: ${conv.lastMessage}" : conv.lastMessage,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13,
                        color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
            Text(_formatTime(conv.lastMessageTime),
                style: TextStyle(fontSize: 11,
                    color: theme.textTheme.bodySmall?.color)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, Color color) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(initial, style: TextStyle(
            color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          Text("Aucune conversation",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500)),
          const SizedBox(height: 8),
          Text("Appuyez sur + pour démarrer une conversation",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

// ── Data class ──────────────────────────────────────────────────

class _ConversationItem {
  final String partnerId;
  final String partnerName;
  final String lastMessage;
  final String lastMessageTime;
  final bool isFromMe;
  final int unreadCount;

  _ConversationItem({
    required this.partnerId,
    required this.partnerName,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.isFromMe,
    required this.unreadCount,
  });
}

// ═══════════════════════════════════════════════════════════════
// Admin Chat Screen — affiche les messages admin comme un chat
// ═══════════════════════════════════════════════════════════════

class _AdminChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>> adminMessages;
  final String myId;
  final VoidCallback onReply;

  const _AdminChatScreen({
    required this.adminMessages,
    required this.myId,
    required this.onReply,
  });

  @override
  State<_AdminChatScreen> createState() => _AdminChatScreenState();
}

class _AdminChatScreenState extends State<_AdminChatScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  late List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    // Reverse so oldest is first (chat order)
    _messages = List.from(widget.adminMessages.reversed);
    _scrollToBottom();
    _markMessagesAsRead();
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _supabase.from('admin_messages')
          .update({'is_read': true})
          .eq('recipient_id', widget.myId)
          .eq('recipient_type', 'single_driver')
          .eq('is_read', false);
      widget.onReply();
    } catch (e) {
      print('❌ Erreur lors du marquage des messages comme lus: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      final myEmail = _supabase.auth.currentUser?.email ?? 'driver';
      final myData = await _supabase.from('drivers')
          .select('name').eq('id', widget.myId).maybeSingle();
      final myName = myData?['name']?.toString() ?? 'Chauffeur';

      await _supabase.from('admin_messages').insert({
        'sender_admin_email': myEmail,
        'recipient_type': 'single_driver',
        'recipient_id': widget.myId,
        'recipient_name': '↩ Réponse de $myName',
        'title': 'RE: Message',
        'message': text,
      });

      setState(() {
        _messages.add({
          'recipient_name': '↩ Réponse de $myName',
          'message': text,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom();
      widget.onReply();
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, "Erreur d'envoi : $e");
      }
    }
  }

  Future<void> _showClearChatConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 10),
            Text("Effacer la discussion"),
          ],
        ),
        content: const Text("Êtes-vous sûr de vouloir effacer l'historique de cette discussion ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Effacer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('admin_messages')
            .update({'is_deleted_by_recipient': true})
            .eq('recipient_id', widget.myId)
            .eq('recipient_type', 'single_driver');
        
        if (mounted) {
          SnackBarHelper.showSuccess(context, "Discussion effacée avec succès");
          Navigator.pop(context);
          widget.onReply();
        }
      } catch (e) {
        if (mounted) {
          SnackBarHelper.showError(context, "Erreur: $e");
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            tooltip: "Effacer la discussion",
            onPressed: _showClearChatConfirmation,
          ),
        ],
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.campaign, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Le Bon Taxi", style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color)),
                Text("Administration", style: TextStyle(
                    fontSize: 12, color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(child: Text("Aucun message",
                    style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      final isReply = msg['recipient_name']
                              ?.toString()
                              .startsWith('↩') ==
                          true;
                      return _buildBubble(msg, isReply, isDark, theme);
                    },
                  ),
          ),
          _buildInputBar(isDark, theme),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool isMe, bool isDark, ThemeData theme) {
    final time = msg['created_at'] != null
        ? DateTime.tryParse(msg['created_at'].toString())
        : null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 6, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && msg['title'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(msg['title'].toString(),
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87)),
              ),
            Text(msg['message']?.toString() ?? '',
                style: TextStyle(
                    color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                    fontSize: 14, height: 1.5)),
            if (time != null) ...[
              const SizedBox(height: 6),
              Text(
                "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                style: TextStyle(fontSize: 10,
                    color: isMe ? Colors.white60 : Colors.grey.shade500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark, ThemeData theme) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 8,
          MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06),
              blurRadius: 10, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: "Répondre à l'admin...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
              ),
              onSubmitted: (_) => _sendReply(),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendReply,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Driver Chat Screen — Chat entre deux chauffeurs (Realtime)
// ═══════════════════════════════════════════════════════════════

class _DriverChatScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String myId;

  const _DriverChatScreen({
    required this.driverId,
    required this.driverName,
    required this.myId,
  });

  @override
  State<_DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<_DriverChatScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _myName;
  RealtimeChannel? _chatChannel;

  static const List<String> _quickMessages = [
    "Salut 👋",
    "OK, compris 👍",
    "Tu es où ?",
    "Merci !",
    "On se voit bientôt",
  ];

  @override
  void initState() {
    super.initState();
    _loadMyName();
    _loadMessages();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _chatChannel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMyName() async {
    try {
      final data = await _supabase.from('drivers')
          .select('name').eq('id', widget.myId).single();
      _myName = data['name']?.toString();
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase.from('driver_messages').select()
          .or('and(sender_id.eq.${widget.myId},receiver_id.eq.${widget.driverId}),and(sender_id.eq.${widget.driverId},receiver_id.eq.${widget.myId})')
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    _chatChannel = _supabase
        .channel('chat_${widget.myId}_${widget.driverId}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'driver_messages',
      callback: (payload) {
        if (!mounted) return;
        final msg = payload.newRecord;
        final senderId = msg['sender_id']?.toString();
        final receiverId = msg['receiver_id']?.toString();
        // Only add if it's part of this conversation
        final isThisConvo =
            (senderId == widget.myId && receiverId == widget.driverId) ||
            (senderId == widget.driverId && receiverId == widget.myId);
        if (isThisConvo && !_messages.any((m) => m['id'] == msg['id'])) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      },
    ).subscribe();
  }

  Future<void> _send([String? text]) async {
    final msg = text ?? _controller.text.trim();
    if (msg.isEmpty) return;
    if (text == null) _controller.clear();

    try {
      await _supabase.from('driver_messages').insert({
        'sender_id': widget.myId,
        'sender_name': _myName ?? 'Moi',
        'receiver_id': widget.driverId,
        'receiver_name': widget.driverName,
        'message': msg,
      });
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showError(context, "Erreur d'envoi : $e");
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: theme.textTheme.bodyLarge?.color,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(
                widget.driverName.isNotEmpty ? widget.driverName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary,
                    fontWeight: FontWeight.bold, fontSize: 16),
              )),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.driverName, style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyLarge?.color)),
                Text("Chauffeur", style: TextStyle(
                    fontSize: 12, color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _messages.isEmpty
                    ? Center(child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 48,
                              color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text("Démarrer la conversation",
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                        ],
                      ))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) => _buildBubble(_messages[i], isDark, theme),
                      ),
          ),

          // Quick messages
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickMessages.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(_quickMessages[i],
                      style: const TextStyle(fontSize: 12, color: AppColors.primary)),
                  backgroundColor: AppColors.primary.withOpacity(0.08),
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  onPressed: () => _send(_quickMessages[i]),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Input bar
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 8,
                MediaQuery.of(context).padding.bottom + 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06),
                    blurRadius: 10, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: "Écrire un message...",
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool isDark, ThemeData theme) {
    final isMe = msg['sender_id'] == widget.myId;
    final time = msg['created_at'] != null
        ? DateTime.tryParse(msg['created_at'].toString())
        : null;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 4, offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(msg['message']?.toString() ?? '',
                style: TextStyle(
                    color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color,
                    fontSize: 14, height: 1.4)),
            if (time != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(fontSize: 10,
                        color: isMe ? Colors.white60 : Colors.grey.shade500),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all, size: 14,
                        color: Colors.white.withOpacity(0.6)),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
