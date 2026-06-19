import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/services/local_database_service.dart';

/// Page de notifications/messages admin avec réponses — style messagerie
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _userId;
  final _replyController = TextEditingController();
  final _scrollController = ScrollController();

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _userId = _supabase.auth.currentUser?.id;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _loadCachedThenFresh();
  }

  @override
  void dispose() {
    _animController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Charger le cache SQLite d'abord, puis Supabase
  Future<void> _loadCachedThenFresh() async {
    try {
      final cached = await LocalDatabaseService.getCachedAdminMessages();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _messages = cached;
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      print('⚠️ Cache SQLite non disponible: $e');
    }
    await _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    try {
      final data = await _supabase
          .from('admin_messages')
          .select()
          .or('recipient_type.eq.all,recipient_type.eq.all_users,and(recipient_type.eq.single_user,recipient_id.eq.$_userId)')
          .or('is_deleted_by_recipient.eq.false,is_deleted_by_recipient.is.null')
          .order('created_at', ascending: false);

      final messages = List<Map<String, dynamic>>.from(data);
      await LocalDatabaseService.saveAdminMessages(messages);

      if (mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
          _isRefreshing = false;
        });
        if (!_animController.isCompleted) _animController.forward();
      }
    } catch (e) {
      print('❌ Erreur chargement notifications: $e');
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  Future<void> _onRefresh() async {
    await _loadFromSupabase();
  }

  Future<void> _showClearChatConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Effacer l'historique"),
        content: const Text("Êtes-vous sûr de vouloir effacer votre historique de messages ? Les messages personnels seront définitivement masqués."),
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
      setState(() => _isLoading = true);
      try {
        if (_userId != null) {
          await _supabase.from('admin_messages')
              .update({'is_deleted_by_recipient': true})
              .eq('recipient_id', _userId!)
              .eq('recipient_type', 'single_user');
        }
        
        await LocalDatabaseService.clearAdminMessages();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Historique effacé"), backgroundColor: Colors.green),
          );
          _loadFromSupabase();
        }
      } catch (e) {
        print('❌ Erreur effacement historique: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Erreur lors de l'effacement : $e"), backgroundColor: Colors.red),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    _replyController.clear();

    try {
      final myEmail = _supabase.auth.currentUser?.email ?? 'user';
      final myData = await _supabase.from('users')
          .select('name').eq('id', _userId!).maybeSingle();
      final myName = myData?['name']?.toString() ?? 'Client';

      await _supabase.from('admin_messages').insert({
        'sender_admin_email': myEmail,
        'recipient_type': 'single_user',
        'recipient_id': _userId,
        'recipient_name': '↩ Message de $myName',
        'title': 'Message Support',
        'message': text,
      });

      if (mounted) {
        _loadFromSupabase();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return "maintenant";
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'il y a ${diff.inDays}j';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: theme.textTheme.bodyLarge?.color,
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
                Text("Le Bon Taxi",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color)),
                Text("Notifications",
                    style: TextStyle(fontSize: 12,
                        color: theme.textTheme.bodySmall?.color)),
              ],
            ),
          ],
        ),
        actions: [
          if (_messages.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: "Tout marquer comme lu",
              onPressed: () async {
                await LocalDatabaseService.markAllMessagesRead();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("✅ Tous les messages marqués comme lus"),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              tooltip: "Effacer l'historique",
              onPressed: _showClearChatConfirmation,
            ),
          ],
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1,
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : FadeTransition(
                        opacity: _fadeAnim,
                        child: RefreshIndicator(
                          onRefresh: _onRefresh,
                          child: ListView.builder(
                            reverse: true, // Messages are loaded descending, so reverse puts newest at bottom
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) => _buildMessageBubble(
                                _messages[i], isDark, theme),
                          ),
                        ),
                      ),
          ),
          _buildInputBar(isDark, theme),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_off_outlined,
                size: 64,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Text("Aucune notification",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text("Les messages de l'admin apparaîtront ici",
              style: TextStyle(fontSize: 14,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> msg, bool isDark, ThemeData theme) {
    final recipientName = msg['recipient_name']?.toString() ?? '';
    final isReply = recipientName.startsWith('↩');
    final isDirect = msg['recipient_type'] == 'single_user';
    final title = msg['title']?.toString() ?? '';
    final message = msg['message']?.toString() ?? '';
    final dateStr = _formatDate(msg['created_at']?.toString());
    final time = msg['created_at'] != null
        ? DateTime.tryParse(msg['created_at'].toString())
        : null;

    return Align(
      alignment: isReply ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Column(
          crossAxisAlignment:
              isReply ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isReply
                    ? AppColors.primary
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isReply ? 18 : 4),
                  bottomRight: Radius.circular(isReply ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                    blurRadius: 6, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isReply ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Title for admin messages
                  if (!isReply && title.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDirect ? Icons.person : Icons.campaign,
                            size: 14,
                            color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(title,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13,
                                    color: isDark ? const Color(0xFF818CF8) : const Color(0xFF6366F1))),
                          ),
                        ],
                      ),
                    ),

                  // Message body
                  Text(message,
                      style: TextStyle(
                          color: isReply
                              ? Colors.white
                              : theme.textTheme.bodyLarge?.color,
                          fontSize: 14, height: 1.5)),

                  // Time
                  if (time != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} • $dateStr",
                      style: TextStyle(fontSize: 10,
                          color: isReply
                              ? Colors.white60
                              : Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12).copyWith(
          bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10, offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _replyController,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 15),
              decoration: InputDecoration(
                hintText: "Votre message...",
                hintStyle: TextStyle(color: Colors.grey.shade500),
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
