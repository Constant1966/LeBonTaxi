import 'dart:async';
import 'package:flutter/material.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/theme/app_colors.dart';

/// Page de chat en temps réel entre utilisateur et chauffeur
class TripChatPage extends StatefulWidget {
  final String tripId;
  final String driverName;
  final String driverPhoto;

  const TripChatPage({
    super.key,
    required this.tripId,
    required this.driverName,
    this.driverPhoto = '',
  });

  @override
  State<TripChatPage> createState() => _TripChatPageState();
}

class _TripChatPageState extends State<TripChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, dynamic>> _messages = [];
  StreamSubscription? _messagesSubscription;
  bool _isLoading = true;
  bool _isSending = false;

  String? get _currentUserId => SupabaseService.userId;

  // Messages rapides prédéfinis
  final List<String> _quickMessages = [
    "Je suis en route",
    "J'arrive dans 2 min",
    "Je vous attends",
    "OK, merci !",
    "Où êtes-vous exactement ?",
    "Je suis devant l'entrée",
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenToMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _messagesSubscription?.cancel();
    super.dispose();
  }

  /// Charger les messages existants
  Future<void> _loadMessages() async {
    try {
      final response = await SupabaseService.supabase
          .from('trip_messages')
          .select()
          .eq('trip_id', widget.tripId)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print("❌ Erreur chargement messages: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Écouter les nouveaux messages en temps réel
  void _listenToMessages() {
    _messagesSubscription = SupabaseService.supabase
        .from('trip_messages')
        .stream(primaryKey: ['id'])
        .eq('trip_id', widget.tripId)
        .order('created_at', ascending: true)
        .listen((data) {
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
        });
        _scrollToBottom();
      }
    });
  }

  /// Envoyer un message
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final trimmed = text.trim();
    _messageController.clear();

    setState(() => _isSending = true);

    try {
      await SupabaseService.supabase.from('trip_messages').insert({
        'trip_id': widget.tripId,
        'sender_id': _currentUserId,
        'sender_type': 'user',
        'message': trimmed,
        'created_at': DateTime.now().toIso8601String(),
      });

      _scrollToBottom();
    } catch (e) {
      print("❌ Erreur envoi message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Erreur d'envoi du message"),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Remettre le texte dans le champ
        _messageController.text = trimmed;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _messages.isEmpty
                    ? _buildEmptyState()
                    : _buildMessagesList(),
          ),

          // Messages rapides
          _buildQuickMessages(),

          // Champ de saisie
          _buildInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textPrimary,
      elevation: 0.5,
      titleSpacing: 0,
      title: Row(
        children: [
          // Photo chauffeur
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: widget.driverPhoto.isNotEmpty
                ? NetworkImage(widget.driverPhoto)
                : null,
            child: widget.driverPhoto.isEmpty
                ? const Icon(Icons.person, size: 20, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driverName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  "Chauffeur",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "Commencez la conversation",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Envoyez un message à ${widget.driverName}",
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message['sender_type'] == 'user';
        final showAvatar = index == 0 ||
            _messages[index - 1]['sender_type'] != message['sender_type'];

        return _buildMessageBubble(message, isMe, showAvatar);
      },
    );
  }

  Widget _buildMessageBubble(
    Map<String, dynamic> message,
    bool isMe,
    bool showAvatar,
  ) {
    final text = message['message'] as String? ?? '';
    final createdAt = message['created_at'] as String?;
    String timeText = '';

    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        timeText = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 12 : 4,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar chauffeur
          if (!isMe && showAvatar)
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.info.withOpacity(0.1),
              child: const Icon(Icons.person, size: 16, color: AppColors.info),
            )
          else if (!isMe)
            const SizedBox(width: 28),

          const SizedBox(width: 8),

          // Bulle de message
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  if (timeText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe
                              ? Colors.white.withOpacity(0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMessages() {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _quickMessages.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(
                _quickMessages[index],
                style: const TextStyle(fontSize: 13),
              ),
              backgroundColor: Colors.white,
              side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () => _sendMessage(_quickMessages[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          // Champ texte
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: "Écrire un message...",
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Bouton envoyer
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isSending ? Colors.grey.shade300 : AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 20),
              color: Colors.white,
              onPressed: _isSending
                  ? null
                  : () => _sendMessage(_messageController.text),
            ),
          ),
        ],
      ),
    );
  }
}
