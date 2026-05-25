import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_colors.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with AutomaticKeepAliveClientMixin<MessagesPage>, SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;
  List<Map<String, dynamic>> _adminMessages = [];
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;
  String? _myId;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _myId = _supabase.auth.currentUser?.id;
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadAdminMessages(), _loadDrivers(), _loadConversations()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAdminMessages() async {
    try {
      final data = await _supabase.from('admin_messages').select()
          .or('recipient_type.eq.all_drivers,recipient_type.eq.all,and(recipient_type.eq.single_driver,recipient_id.eq.$_myId)')
          .order('created_at', ascending: false);
      if (mounted) setState(() => _adminMessages = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('❌ Erreur admin messages: $e');
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final data = await _supabase.from('drivers').select('id, name, phone')
          .neq('id', _myId ?? '').order('name');
      if (mounted) setState(() => _drivers = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('❌ Erreur drivers: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      final data = await _supabase.from('driver_messages')
          .select()
          .or('sender_id.eq.$_myId,receiver_id.eq.$_myId')
          .order('created_at', ascending: false);
      // Group by conversation partner
      final Map<String, Map<String, dynamic>> convos = {};
      for (final msg in data) {
        final partnerId = msg['sender_id'] == _myId ? msg['receiver_id'] : msg['sender_id'];
        if (partnerId != null && !convos.containsKey(partnerId)) {
          convos[partnerId.toString()] = msg;
        }
      }
      if (mounted) setState(() => _conversations = convos.values.toList());
    } catch (e) {
      print('❌ Erreur conversations: $e');
    }
  }

  Future<void> _replyToAdmin(Map<String, dynamic> msg) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Répondre", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: TextField(
            controller: controller, maxLines: 3, autofocus: true,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              hintText: "Votre réponse...",
              hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text("Envoyer", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      try {
        final myEmail = _supabase.auth.currentUser?.email ?? 'driver';
        final myData = await _supabase.from('drivers').select('name').eq('id', _myId!).maybeSingle();
        final myName = myData?['name']?.toString() ?? 'Chauffeur';
        await _supabase.from('admin_messages').insert({
          'sender_admin_email': myEmail,
          'recipient_type': 'single_driver',
          'recipient_id': _myId,
          'recipient_name': '↩ Réponse de $myName',
          'title': 'RE: ${msg['title'] ?? ''}',
          'message': result.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Réponse envoyée"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _openDriverChat(Map<String, dynamic> driver) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _DriverChatScreen(
        driverId: driver['id'].toString(),
        driverName: driver['name']?.toString() ?? 'Chauffeur',
        myId: _myId!,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Messages", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 4),
              Text("Communications et échanges", style: TextStyle(fontSize: 15, color: theme.textTheme.bodySmall?.color)),
            ]),
          ),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(icon: const Icon(Icons.campaign, size: 20), text: "Admin (${_adminMessages.length})"),
              Tab(icon: const Icon(Icons.chat_bubble_outline, size: 20), text: "Conversations"),
              const Tab(icon: Icon(Icons.people_outline, size: 20), text: "Chauffeurs"),
            ],
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(controller: _tabController, children: [
                    _buildAdminTab(isDark, theme),
                    _buildConversationsTab(isDark, theme),
                    _buildDriversTab(isDark, theme),
                  ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildAdminTab(bool isDark, ThemeData theme) {
    if (_adminMessages.isEmpty) {
      return _emptyState(Icons.campaign_outlined, "Aucun message de l'admin");
    }
    return RefreshIndicator(
      onRefresh: _loadAdminMessages,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _adminMessages.length,
        itemBuilder: (_, i) {
          final msg = _adminMessages[i];
          final isGlobal = msg['recipient_type'] == 'all';
          final isDirect = msg['recipient_type'] == 'single_driver';
          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 10),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isGlobal ? Colors.amber : isDirect ? AppColors.primary : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isGlobal ? Icons.campaign : isDirect ? Icons.person : Icons.groups,
                      color: isGlobal ? Colors.amber : isDirect ? AppColors.primary : Colors.orange, size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(msg['title']?.toString() ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.bodyLarge?.color)),
                    Text(msg['created_at']?.toString().substring(0, 16) ?? '', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isGlobal ? Colors.amber : isDirect ? AppColors.primary : Colors.orange).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(isGlobal ? "Globale" : isDirect ? "Privé" : "Broadcast",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: isGlobal ? Colors.amber.shade700 : isDirect ? AppColors.primary : Colors.orange)),
                  ),
                ]),
                const SizedBox(height: 12),
                Text(msg['message']?.toString() ?? '', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color, height: 1.4)),
                if (isDirect) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _replyToAdmin(msg),
                      icon: const Icon(Icons.reply, size: 18),
                      label: const Text("Répondre"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildConversationsTab(bool isDark, ThemeData theme) {
    if (_conversations.isEmpty) {
      return _emptyState(Icons.chat_bubble_outline, "Aucune conversation");
    }
    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _conversations.length,
        itemBuilder: (_, i) {
          final msg = _conversations[i];
          final partnerId = msg['sender_id'] == _myId ? msg['receiver_id'] : msg['sender_id'];
          final partnerName = msg['sender_id'] == _myId ? (msg['receiver_name'] ?? 'Chauffeur') : (msg['sender_name'] ?? 'Chauffeur');
          return ListTile(
            onTap: () => _openDriverChat({'id': partnerId, 'name': partnerName}),
            leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(partnerName.toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
            title: Text(partnerName.toString(), style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
            subtitle: Text(msg['message']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: theme.textTheme.bodySmall?.color, fontSize: 13)),
            trailing: Text(msg['created_at']?.toString().substring(11, 16) ?? '', style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color)),
          );
        },
      ),
    );
  }

  Widget _buildDriversTab(bool isDark, ThemeData theme) {
    if (_drivers.isEmpty) {
      return _emptyState(Icons.people_outline, "Aucun chauffeur trouvé");
    }
    return RefreshIndicator(
      onRefresh: _loadDrivers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drivers.length,
        itemBuilder: (_, i) {
          final d = _drivers[i];
          final name = d['name']?.toString() ?? 'Chauffeur';
          return Card(
            elevation: 0, margin: const EdgeInsets.only(bottom: 8),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
            child: ListTile(
              onTap: () => _openDriverChat(d),
              leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(0.1), child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
              title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
              subtitle: Text(d['phone']?.toString() ?? '', style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color)),
              trailing: IconButton(icon: const Icon(Icons.chat, color: AppColors.primary, size: 22), onPressed: () => _openDriverChat(d)),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyState(IconData icon, String text) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 64, color: Colors.grey.shade400),
      const SizedBox(height: 16),
      Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade500)),
    ]));
  }
}

// ─── Chat screen entre deux chauffeurs ──────────────────────────
class _DriverChatScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String myId;
  const _DriverChatScreen({required this.driverId, required this.driverName, required this.myId});
  @override
  State<_DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<_DriverChatScreen> {
  final _supabase = Supabase.instance.client;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  Timer? _pollTimer;
  String? _myName;

  @override
  void initState() {
    super.initState();
    _loadMyName();
    _loadMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadMessages());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMyName() async {
    try {
      final data = await _supabase.from('drivers').select('name').eq('id', widget.myId).single();
      _myName = data['name']?.toString();
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase.from('driver_messages').select()
          .or('and(sender_id.eq.${widget.myId},receiver_id.eq.${widget.driverId}),and(sender_id.eq.${widget.driverId},receiver_id.eq.${widget.myId})')
          .order('created_at', ascending: true);
      if (mounted) {
        final newLen = data.length;
        final oldLen = _messages.length;
        setState(() { _messages = List<Map<String, dynamic>>.from(data); _isLoading = false; });
        if (newLen > oldLen) _scrollToBottom();
      }
    } catch (e) {
      print('❌ Chat load error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await _supabase.from('driver_messages').insert({
        'sender_id': widget.myId,
        'sender_name': _myName ?? 'Moi',
        'receiver_id': widget.driverId,
        'receiver_name': widget.driverName,
        'message': text,
      });
      await _loadMessages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.driverName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(children: [
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(child: Text("Démarrer la conversation", style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        final isMe = msg['sender_id'] == widget.myId;
                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                                bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
                              ),
                            ),
                            child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                              Text(msg['message']?.toString() ?? '', style: TextStyle(color: isMe ? Colors.white : theme.textTheme.bodyLarge?.color, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(msg['created_at']?.toString().substring(11, 16) ?? '', style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey.shade500)),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: SafeArea(
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "Écrire un message...",
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppColors.primary,
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _send),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
