import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/services/local_database_service.dart';

/// Page affichant les messages/notifications de l'admin
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
    super.dispose();
  }

  /// Charger le cache SQLite d'abord (démarrage rapide), puis Supabase
  Future<void> _loadCachedThenFresh() async {
    // 1. Cache SQLite — affichage instantané
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

    // 2. Données fraîches depuis Supabase
    await _loadFromSupabase();
  }

  Future<void> _loadFromSupabase() async {
    try {
      final data = await _supabase
          .from('admin_messages')
          .select()
          .or('recipient_type.eq.all,recipient_type.eq.all_users,and(recipient_type.eq.single_user,recipient_id.eq.$_userId)')
          .order('created_at', ascending: false);

      final messages = List<Map<String, dynamic>>.from(data);

      // Sauvegarder dans SQLite pour le prochain démarrage
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _loadFromSupabase();
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

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
        title: const Text("Notifications"),
        backgroundColor: isDark ? const Color(0xFF1E1B4B) : AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_messages.isNotEmpty)
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
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _messages.isEmpty
              ? _buildEmptyState(isDark)
              : FadeTransition(
                  opacity: _fadeAnim,
                  child: RefreshIndicator(
                    onRefresh: _onRefresh,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _buildMessageCard(_messages[i], isDark, theme),
                    ),
                  ),
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
              color: (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "Aucune notification",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Les messages de l'admin apparaîtront ici",
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> msg, bool isDark, ThemeData theme) {
    final recipientType = msg['recipient_type']?.toString() ?? '';
    final isGlobal = recipientType == 'all' || recipientType == 'all_users';
    final isDirect = recipientType == 'single_user';
    final title = msg['title']?.toString() ?? 'Notification';
    final message = msg['message']?.toString() ?? '';
    final dateStr = _formatDate(msg['created_at']?.toString());

    final Color accentColor = isGlobal
        ? Colors.amber
        : isDirect
            ? AppColors.primary
            : Colors.orange;

    final IconData icon = isGlobal
        ? Icons.campaign
        : isDirect
            ? Icons.person
            : Icons.groups;

    final String badge = isGlobal ? "Tous" : isDirect ? "Privé" : "Broadcast";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Corps du message
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: theme.textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
