import '../constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_log_service.dart';

class CommunicationPage extends StatefulWidget {
  static const String id = "\\webPageCommunication";

  /// Optional: pre-select a message in history and open reply
  final String? initialMessageId;
  final String? initialRecipientId;
  final int initialTab;

  const CommunicationPage({
    super.key,
    this.initialMessageId,
    this.initialRecipientId,
    this.initialTab = 0,
  });

  @override
  State<CommunicationPage> createState() => _CommunicationPageState();
}

class _CommunicationPageState extends State<CommunicationPage> {
  final supabase = Supabase.instance.client;
  
  // Controllers
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _historyScrollController = ScrollController();
  final _chatInputController = TextEditingController();

  // Selected states
  String? _selectedConversationId;
  Map<String, dynamic>? _selectedConversationUser;
  bool _isWritingAnnouncement = false;
  String _recipientType = 'all_drivers'; // 'all_drivers', 'all_users', 'all'

  // DB raw lists
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _conversationsList = [];
  
  // App UI states
  bool _isLoading = true;
  bool _isSending = false;
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'driver', 'user'

  String? _highlightedMessageId;

  @override
  void initState() {
    super.initState();
    _highlightedMessageId = widget.initialMessageId;
    _initData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _historyScrollController.dispose();
    _chatInputController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await _loadDrivers();
    await _loadUsers();
    await _loadConversations();

    if (widget.initialRecipientId != null) {
      final matchingConv = _conversationsList.firstWhere(
        (c) => c['id'] == widget.initialRecipientId,
        orElse: () => <String, dynamic>{},
      );
      if (matchingConv.isNotEmpty) {
        _selectConversation(matchingConv);
      }
    }
    
    // Set UI loading done
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDrivers() async {
    try {
      final data = await supabase.from('drivers').select('id, name, phone').order('name');
      if (mounted) _drivers = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('❌ [Communication] Erreur chargement chauffeurs: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final data = await supabase.from('users').select('id, name, phone, email').order('name');
      if (mounted) _users = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      print('❌ [Communication] Erreur chargement utilisateurs: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      // Fetch all messages (sent and received)
      final data = await supabase
          .from('admin_messages')
          .select()
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(data);
      final Map<String, Map<String, dynamic>> grouped = {};

      // Initialize the broadcast category
      grouped['broadcast_announcements'] = {
        'id': 'broadcast_announcements',
        'name': 'Diffusions & Annonces',
        'type': 'broadcast',
        'phone': '',
        'email': '',
        'last_message': 'Aucune diffusion récente',
        'last_time': '',
        'unread_count': 0,
        'messages': <Map<String, dynamic>>[],
      };

      for (final msg in messages) {
        final recipientId = msg['recipient_id']?.toString();
        final recipientType = msg['recipient_type']?.toString() ?? '';
        
        // Broadcasts (sent to all) go to Diffusions & Annonces
        final isBroadcast = recipientId == null || recipientType == 'all_drivers' || recipientType == 'all_users' || recipientType == 'all';
        
        if (isBroadcast) {
          final list = grouped['broadcast_announcements']!['messages'] as List<Map<String, dynamic>>;
          list.add(msg);
          final msgTime = msg['created_at']?.toString() ?? '';
          final msgText = msg['message']?.toString() ?? '';
          
          final currentLastTime = grouped['broadcast_announcements']!['last_time']?.toString() ?? '';
          if (currentLastTime.isEmpty || msgTime.compareTo(currentLastTime) > 0) {
            grouped['broadcast_announcements']!['last_time'] = msgTime;
            grouped['broadcast_announcements']!['last_message'] = msgText;
          }
          continue;
        }

        // Direct messages (single_user or single_driver)
        final isUser = msg['recipient_type'] == 'single_user';
        
        // Lookup profile and clean name
        String resolvedName = '';
        String phone = '';
        String email = '';
        if (isUser) {
          final userMatch = _users.firstWhere((u) => u['id']?.toString() == recipientId, orElse: () => {});
          if (userMatch.isNotEmpty) {
            resolvedName = userMatch['name']?.toString() ?? '';
            phone = userMatch['phone']?.toString() ?? '';
            email = userMatch['email']?.toString() ?? '';
          }
        } else {
          final driverMatch = _drivers.firstWhere((d) => d['id']?.toString() == recipientId, orElse: () => {});
          if (driverMatch.isNotEmpty) {
            resolvedName = driverMatch['name']?.toString() ?? '';
            phone = driverMatch['phone']?.toString() ?? '';
          }
        }

        if (resolvedName.isEmpty) {
          final recipientNameRaw = msg['recipient_name']?.toString() ?? '';
          resolvedName = recipientNameRaw
              .replaceFirst('↩', '')
              .replaceFirst('Réponse de', '')
              .trim();
          if (resolvedName.isEmpty) {
            resolvedName = 'Utilisateur $recipientId';
          }
        }

        final lastMsgText = msg['message']?.toString() ?? '';
        final lastMsgTime = msg['created_at']?.toString() ?? '';
        final isRead = msg['is_read'] ?? false;
        final recipientNameRaw = msg['recipient_name']?.toString() ?? '';
        final isReceived = recipientNameRaw.startsWith('↩');

        if (!grouped.containsKey(recipientId)) {
          grouped[recipientId] = {
            'id': recipientId,
            'name': resolvedName,
            'type': isUser ? 'user' : 'driver',
            'phone': phone,
            'email': email,
            'last_message': lastMsgText,
            'last_time': lastMsgTime,
            'unread_count': (!isRead && isReceived) ? 1 : 0,
            'messages': <Map<String, dynamic>>[msg],
          };
        } else {
          final list = grouped[recipientId]!['messages'] as List<Map<String, dynamic>>;
          list.add(msg);
          // Update details if empty
          if (grouped[recipientId]!['phone'] == null || grouped[recipientId]!['phone'].toString().isEmpty) {
            grouped[recipientId]!['phone'] = phone;
          }
          if (grouped[recipientId]!['email'] == null || grouped[recipientId]!['email'].toString().isEmpty) {
            grouped[recipientId]!['email'] = email;
          }
          if (!isRead && isReceived) {
            grouped[recipientId]!['unread_count'] = (grouped[recipientId]!['unread_count'] as int) + 1;
          }
        }
      }

      // Add driver profiles who have no messages yet so the admin can write to them
      for (final d in _drivers) {
        final id = d['id']?.toString();
        if (id != null && !grouped.containsKey(id)) {
          grouped[id] = {
            'id': id,
            'name': d['name']?.toString() ?? 'Chauffeur',
            'type': 'driver',
            'phone': d['phone']?.toString() ?? '',
            'email': '',
            'last_message': 'Démarrer une conversation...',
            'last_time': '',
            'unread_count': 0,
            'messages': <Map<String, dynamic>>[],
          };
        }
      }

      // Add user profiles who have no messages yet
      for (final u in _users) {
        final id = u['id']?.toString();
        if (id != null && !grouped.containsKey(id)) {
          grouped[id] = {
            'id': id,
            'name': u['name']?.toString() ?? u['email']?.toString() ?? 'Client',
            'type': 'user',
            'phone': u['phone']?.toString() ?? '',
            'email': u['email']?.toString() ?? '',
            'last_message': 'Démarrer une conversation...',
            'last_time': '',
            'unread_count': 0,
            'messages': <Map<String, dynamic>>[],
          };
        }
      }

      final list = grouped.values.toList();
      
      // Sort conversations: active ones first (by last_time desc), then others alphabetically
      list.sort((a, b) {
        if (a['id'] == 'broadcast_announcements') return -1;
        if (b['id'] == 'broadcast_announcements') return 1;
        
        final aTime = a['last_time']?.toString() ?? '';
        final bTime = b['last_time']?.toString() ?? '';
        if (aTime.isNotEmpty && bTime.isNotEmpty) {
          return bTime.compareTo(aTime);
        } else if (aTime.isNotEmpty) {
          return -1;
        } else if (bTime.isNotEmpty) {
          return 1;
        } else {
          final aName = a['name']?.toString() ?? '';
          final bName = b['name']?.toString() ?? '';
          return aName.compareTo(bName);
        }
      });

      if (mounted) {
        setState(() {
          _conversationsList = list;
          
          if (_selectedConversationId != null) {
            final updatedConv = _conversationsList.firstWhere(
              (c) => c['id'] == _selectedConversationId,
              orElse: () => <String, dynamic>{},
            );
            if (updatedConv.isNotEmpty) {
              _selectedConversationUser = updatedConv;
            }
          }
        });

        // Trigger selection if we clicked a notification message
        if (_highlightedMessageId != null) {
          _handleInitialMessage(_highlightedMessageId!);
          // Do not nullify _highlightedMessageId here, we'll clear it after 3s in _handleInitialMessage
        }
      }
    } catch (e) {
      print("❌ Erreur _loadConversations: $e");
    }
  }

  void _handleInitialMessage(String msgId) async {
    try {
      final msg = await supabase
          .from('admin_messages')
          .select()
          .eq('id', msgId)
          .maybeSingle();

      if (msg != null) {
        final recipientId = msg['recipient_id']?.toString();
        if (recipientId != null) {
          final recipientNameRaw = msg['recipient_name']?.toString() ?? '';
          
          String resolvedName = '';
          final isUser = msg['recipient_type'] == 'single_user';
          if (isUser) {
            final u = _users.firstWhere((usr) => usr['id']?.toString() == recipientId, orElse: () => {});
            if (u.isNotEmpty) resolvedName = u['name']?.toString() ?? '';
          } else {
            final d = _drivers.firstWhere((drv) => drv['id']?.toString() == recipientId, orElse: () => {});
            if (d.isNotEmpty) resolvedName = d['name']?.toString() ?? '';
          }

          if (resolvedName.isEmpty) {
            resolvedName = recipientNameRaw
                .replaceFirst('↩', '')
                .replaceFirst('Réponse de', '')
                .trim();
            if (resolvedName.isEmpty) resolvedName = 'Utilisateur';
          }

          final conv = {
            'id': recipientId,
            'name': resolvedName,
            'type': isUser ? 'user' : 'driver',
          };
          
          setState(() {
            _highlightedMessageId = msgId;
          });
          
          _selectConversation(conv);
          await _markAsRead(msgId);
          await _loadConversations();
          _scrollToBottom();

          // Clear highlight after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                if (_highlightedMessageId == msgId) {
                  _highlightedMessageId = null;
                }
              });
            }
          });
        } else {
          // If recipient_id is null, it's a broadcast
          setState(() {
            _selectedConversationId = 'broadcast_announcements';
            _selectedConversationUser = {
              'id': 'broadcast_announcements',
              'name': 'Diffusions & Annonces',
              'type': 'broadcast',
            };
            _isWritingAnnouncement = false;
          });
          _scrollToBottom();
        }
      }
    } catch (e) {
      print("⚠️ Erreur _handleInitialMessage: $e");
    }
  }

  void _selectConversation(Map<String, dynamic> conv) {
    setState(() {
      _selectedConversationId = conv['id'];
      _selectedConversationUser = conv;
      _isWritingAnnouncement = false;
    });

    // Mark unread messages as read
    final List<dynamic> messages = conv['messages'] ?? [];
    for (final msg in messages) {
      final recipientName = msg['recipient_name']?.toString() ?? '';
      final isReceived = recipientName.startsWith('↩');
      final isUnread = msg['is_read'] != true;

      if (isReceived && isUnread) {
        final msgId = msg['id']?.toString();
        if (msgId != null) {
          _markAsRead(msgId);
        }
      }
    }

    // Set local unread count to 0 instantly
    conv['unread_count'] = 0;

    _scrollToBottom();
  }

  Future<void> _markAsRead(String msgId) async {
    try {
      await supabase.from('admin_messages').update({'is_read': true}).eq('id', msgId);
    } catch (e) {
      print("⚠️ Erreur _markAsRead: $e");
    }
  }

  Future<void> _sendDirectMessage(String text) async {
    if (text.trim().isEmpty || _selectedConversationId == null || _isSending) return;
    final trimmed = text.trim();
    _chatInputController.clear();
    setState(() => _isSending = true);

    try {
      final recipientId = _selectedConversationId!;
      final recipientName = _selectedConversationUser?['name']?.toString() ?? 'Destinataire';
      final type = _selectedConversationUser?['type'] == 'user' ? 'single_user' : 'single_driver';

      await supabase.from('admin_messages').insert({
        'sender_admin_email': supabase.auth.currentUser?.email ?? 'admin',
        'recipient_type': type,
        'recipient_id': recipientId,
        'recipient_name': recipientName,
        'title': 'Message Direct',
        'message': trimmed,
        'is_read': true, // Marked as read for admin
      });

      await AdminLogService.log(
        action: 'Envoi message direct admin',
        targetType: 'message',
        targetId: recipientId,
        details: {'message': trimmed, 'recipient': recipientName},
      );

      await _loadConversations();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur d'envoi: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir le titre et le message"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      String recipientName;
      if (_recipientType == 'all_drivers') {
        recipientName = 'Tous les chauffeurs';
      } else if (_recipientType == 'all_users') {
        recipientName = 'Tous les clients';
      } else {
        recipientName = 'Tout le monde';
      }

      await supabase.from('admin_messages').insert({
        'sender_admin_email': supabase.auth.currentUser?.email ?? 'admin',
        'recipient_type': _recipientType,
        'recipient_id': null,
        'recipient_name': recipientName,
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
      });

      await AdminLogService.log(
        action: _recipientType == 'all_drivers' ? 'Message broadcast chauffeurs' : _recipientType == 'all_users' ? 'Message broadcast clients' : 'Annonce globale',
        targetType: 'message',
        details: {'title': _titleController.text, 'recipientType': _recipientType},
      );

      _titleController.clear();
      _messageController.clear();
      setState(() => _isWritingAnnouncement = false);
      
      await _loadConversations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Diffusion lancée avec succès"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_historyScrollController.hasClients) {
        _historyScrollController.animateTo(
          _historyScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Color _getAvatarColor(String name) {
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final double h = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, h, 0.55, 0.45).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Communication", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text("Messagerie instantanée avec les chauffeurs et clients", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _isWritingAnnouncement = true;
                            _selectedConversationId = null;
                            _selectedConversationUser = null;
                          });
                        },
                        icon: const Icon(Icons.campaign, size: 20),
                        label: const Text("NOUVELLE DIFFUSION", style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Main Body split
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sidebar Conversations
                        Container(
                          width: 350,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                          ),
                          child: _buildSidebar(isDark),
                        ),
                        
                        const SizedBox(width: 20),
                        
                        // Right Chat Area
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkCard : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                            ),
                            child: _buildChatArea(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildRoleBadge(String type, bool isDark) {
    final isDriver = type == 'driver';
    final label = isDriver ? 'CHAUFFEUR' : 'CLIENT';
    final color = isDriver ? AppColors.success : AppColors.purple;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSidebar(bool isDark) {
    // Filter list
    final filtered = _conversationsList.where((conv) {
      if (conv['id'] == 'broadcast_announcements') return true;
      
      final name = conv['name']?.toString().toLowerCase() ?? '';
      final query = _searchQuery.toLowerCase();
      if (query.isNotEmpty && !name.contains(query)) return false;

      if (_filterType == 'driver' && conv['type'] != 'driver') return false;
      if (_filterType == 'user' && conv['type'] != 'user') return false;

      return true;
    }).toList();

    return Column(
      children: [
        // Search & Filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "Rechercher...",
                  hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _filterChip("Tous", 'all', isDark),
                  _filterChip("Chauffeurs", 'driver', isDark),
                  _filterChip("Clients", 'user', isDark),
                ],
              ),
            ],
          ),
        ),
        
        const Divider(height: 1),
        
        // Scrollable List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, i) {
              final conv = filtered[i];
              final isSelected = conv['id'] == _selectedConversationId;
              final isBroadcast = conv['id'] == 'broadcast_announcements';
              
              final unreadCount = conv['unread_count'] as int? ?? 0;
              final lastMsg = conv['last_message']?.toString() ?? '';
              final lastTime = conv['last_time']?.toString() ?? '';
              
              String timeFormatted = '';
              if (lastTime.isNotEmpty) {
                try {
                  timeFormatted = lastTime.substring(11, 16);
                } catch (_) {}
              }

              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                selected: isSelected,
                selectedTileColor: isDark ? AppColors.darkCardHover : Colors.indigo.shade50.withValues(alpha: 0.4),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isBroadcast
                        ? const LinearGradient(
                            colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [
                              _getAvatarColor(conv['name']?.toString() ?? 'L'),
                              _getAvatarColor(conv['name']?.toString() ?? 'L').withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isBroadcast
                        ? const Icon(Icons.campaign, color: Colors.white, size: 20)
                        : Text(
                            (conv['name']?.toString() ?? 'L').substring(0, 1).toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              conv['name']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isBroadcast) ...[
                            const SizedBox(width: 8),
                            _buildRoleBadge(conv['type']?.toString() ?? '', isDark),
                          ],
                        ],
                      ),
                    ),
                    if (timeFormatted.isNotEmpty)
                      Text(
                        timeFormatted,
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                      ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastMsg,
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "$unreadCount",
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                onTap: () => _selectConversation(conv),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value, bool isDark) {
    final isSelected = _filterType == value;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
      ),
      backgroundColor: isDark ? AppColors.darkCardHover : Colors.grey.shade200,
      onSelected: (_) => setState(() => _filterType = value),
    );
  }

  Widget _buildChatArea(bool isDark) {
    if (_isWritingAnnouncement) {
      return _buildAnnouncementComposer(isDark);
    }

    if (_selectedConversationId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, size: 56, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              "Vos conversations",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              "Sélectionnez une discussion à gauche ou composez une annonce pour commencer.",
              style: TextStyle(fontSize: 13, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final isBroadcast = _selectedConversationId == 'broadcast_announcements';
    final activeConv = _conversationsList.firstWhere(
        (c) => c['id'] == _selectedConversationId,
        orElse: () => <String, dynamic>{});
    
    final List<Map<String, dynamic>> messages = List<Map<String, dynamic>>.from(activeConv['messages'] ?? []);
    
    // Sort oldest first for chat flow
    messages.sort((a, b) => (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));

    final phone = _selectedConversationUser?['phone']?.toString() ?? '';
    final email = _selectedConversationUser?['email']?.toString() ?? '';
    final contactInfo = [
      if (phone.isNotEmpty) phone,
      if (email.isNotEmpty) email,
    ].join(' • ');

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: isBroadcast
                            ? const LinearGradient(
                                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  _getAvatarColor(_selectedConversationUser?['name']?.toString() ?? 'L'),
                                  _getAvatarColor(_selectedConversationUser?['name']?.toString() ?? 'L').withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: isBroadcast
                            ? const Icon(Icons.campaign, color: Colors.white, size: 20)
                            : Text(
                                (_selectedConversationUser?['name']?.toString() ?? 'L').substring(0, 1).toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  _selectedConversationUser?['name']?.toString() ?? '',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isBroadcast) ...[
                                const SizedBox(width: 8),
                                _buildRoleBadge(_selectedConversationUser?['type']?.toString() ?? '', isDark),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isBroadcast
                                ? "Messages généraux diffusés à tous"
                                : contactInfo.isNotEmpty ? contactInfo : "Aucune coordonnée",
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (isBroadcast)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isWritingAnnouncement = true),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Créer une annonce", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                )
              else ...[
                if (phone.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.copy_all, color: AppColors.primary, size: 20),
                    tooltip: "Copier le numéro de téléphone",
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Téléphone copié : $phone"),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          width: 280,
                        ),
                      );
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary, size: 20),
                  tooltip: "Rafraîchir",
                  onPressed: _loadConversations,
                ),
              ],
            ],
          ),
        ),
        
        // Chat History Message List
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        "Aucun message dans ce chat",
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _historyScrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final recipientName = msg['recipient_name']?.toString() ?? '';
                    final isReceived = recipientName.startsWith('↩');
                    final isHighlighted = msg['id']?.toString() == _highlightedMessageId;
                    
                    final bubble = Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.45,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: isReceived
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: isReceived
                            ? (isDark ? AppColors.darkCardHover : Colors.grey.shade100)
                            : null,
                        border: isHighlighted
                            ? Border.all(color: Colors.amber, width: 2)
                            : null,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isReceived ? 4 : 16),
                          bottomRight: Radius.circular(isReceived ? 16 : 4),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isHighlighted 
                                ? Colors.amber.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.04),
                            blurRadius: isHighlighted ? 8 : 4,
                            spreadRadius: isHighlighted ? 2 : 0,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: isReceived ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: [
                          // Show title for broadcasts
                          if (isBroadcast && msg['title'] != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                msg['title'].toString().toUpperCase(),
                                style: TextStyle(
                                  color: isDark ? Colors.yellow.shade200 : Colors.indigo.shade800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          Text(
                            msg['message']?.toString() ?? '',
                            style: TextStyle(
                              color: isReceived
                                  ? (isDark ? Colors.white : Colors.black87)
                                  : Colors.white,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );

                    if (isReceived) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isBroadcast) ...[
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      _getAvatarColor(_selectedConversationUser?['name']?.toString() ?? 'L'),
                                      _getAvatarColor(_selectedConversationUser?['name']?.toString() ?? 'L').withValues(alpha: 0.7),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    (_selectedConversationUser?['name']?.toString() ?? 'L').substring(0, 1).toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                bubble,
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    (msg['created_at'] != null && msg['created_at'].toString().length >= 16)
                                        ? "${msg['created_at'].toString().substring(8, 10)}/${msg['created_at'].toString().substring(5, 7)} à ${msg['created_at'].toString().substring(11, 16)}"
                                        : '',
                                    style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 10),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            bubble,
                            const SizedBox(height: 4),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                (msg['created_at'] != null && msg['created_at'].toString().length >= 16)
                                    ? "${msg['created_at'].toString().substring(8, 10)}/${msg['created_at'].toString().substring(5, 7)} à ${msg['created_at'].toString().substring(11, 16)}"
                                    : '',
                                style: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400, fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
        ),

        // Chat templates and input bar
        if (!isBroadcast) ...[
          // Template chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade100)),
            ),
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chatTemplateChip("🔧 Maintenance", "Le système sera en maintenance aujourd'hui de [heure] à [heure]. Merci de votre patience.", isDark),
                const SizedBox(width: 8),
                _chatTemplateChip("🎉 Promotion", "Profitez de notre code promo exclusif LeBonTaxi aujourd'hui !", isDark),
                const SizedBox(width: 8),
                _chatTemplateChip("⚠️ Alerte", "Attention: merci de prendre les mesures nécessaires pour votre course.", isDark),
              ],
            ),
          ),
          
          // Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBg : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
                    ),
                    child: TextField(
                      controller: _chatInputController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Écrire un message à ${_selectedConversationUser?['name']}...",
                        hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: _sendDirectMessage,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _isSending ? Colors.grey : AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _isSending
                        ? null
                        : () => _sendDirectMessage(_chatInputController.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _chatTemplateChip(String label, String messageText, bool isDark) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: isDark ? AppColors.darkCardHover : Colors.grey.shade100,
      side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        _chatInputController.text = messageText;
      },
    );
  }

  Widget _buildAnnouncementComposer(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Nouvelle diffusion / annonce", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _isWritingAnnouncement = false),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text("Destinataire de la diffusion", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text("Tous les chauffeurs"),
                selected: _recipientType == 'all_drivers',
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _recipientType == 'all_drivers' ? Colors.white : null),
                onSelected: (_) => setState(() => _recipientType = 'all_drivers'),
              ),
              ChoiceChip(
                label: const Text("Tous les clients"),
                selected: _recipientType == 'all_users',
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: _recipientType == 'all_users' ? Colors.white : null),
                onSelected: (_) => setState(() => _recipientType = 'all_users'),
              ),
              ChoiceChip(
                label: const Text("Annonce globale"),
                selected: _recipientType == 'all',
                selectedColor: const Color(0xFFEAB308),
                labelStyle: TextStyle(color: _recipientType == 'all' ? Colors.white : null),
                onSelected: (_) => setState(() => _recipientType = 'all'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _titleController,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Titre de l'annonce",
              labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              prefixIcon: Icon(Icons.title, color: isDark ? Colors.white70 : Colors.black54),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _messageController,
            maxLines: 6,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Message de l'annonce",
              labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text("Gabarits rapides", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _templateChip("🔧 Maintenance", "Maintenance système", "Le système sera en maintenance le [date]. Merci de votre patience.", isDark),
              _templateChip("🎉 Promotion", "Nouvelle promotion", "Profitez de notre nouvelle promotion ! [détails]", isDark),
              _templateChip("⚠️ Alerte", "Alerte importante", "Attention : [message]. Merci de prendre les mesures nécessaires.", isDark),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendMessage,
              icon: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_isSending ? "Diffusion en cours..." : "Lancer la diffusion"),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _templateChip(String label, String title, String message, bool isDark) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: isDark ? AppColors.darkCardHover : Colors.grey.shade100,
      side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onPressed: () {
        _titleController.text = title;
        _messageController.text = message;
      },
    );
  }
}
