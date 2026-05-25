import '../constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_log_service.dart';

class CommunicationPage extends StatefulWidget {
  static const String id = "\\webPageCommunication";
  const CommunicationPage({super.key});

  @override
  State<CommunicationPage> createState() => _CommunicationPageState();
}

class _CommunicationPageState extends State<CommunicationPage> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _recipientType = 'all_drivers';
  String? _selectedDriverId;
  String? _selectedDriverName;
  String? _selectedUserId;
  String? _selectedUserName;
  List<Map<String, dynamic>> _drivers = [];
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _messageHistory = [];
  bool _isSending = false;
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDrivers();
    _loadUsers();
    _loadMessageHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    try {
      print('📡 [Communication] Chargement chauffeurs...');
      print('📡 [Communication] User connecté: ${supabase.auth.currentUser?.email}');
      final data = await supabase.from('drivers').select('id, name, phone').order('name');
      print('📡 [Communication] ${data.length} chauffeurs trouvés');
      if (mounted) setState(() => _drivers = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('❌ [Communication] Erreur chargement chauffeurs: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      final data = await supabase.from('users').select('id, name, phone, email').order('name');
      if (mounted) setState(() => _users = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      print('❌ [Communication] Erreur chargement utilisateurs: $e');
    }
  }

  Future<void> _loadMessageHistory() async {
    try {
      final data = await supabase
          .from('admin_messages')
          .select()
          .order('created_at', ascending: false);
      print('📡 [Communication] ${data.length} messages trouvés');
      if (mounted) {
        setState(() {
          _messageHistory = List<Map<String, dynamic>>.from(data);
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print('❌ [Communication] Erreur chargement messages: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_titleController.text.isEmpty || _messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez remplir le titre et le message"), backgroundColor: Colors.red),
      );
      return;
    }
    if (_recipientType == 'single_driver' && _selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner un chauffeur"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);
    try {
      String? recipientId;
      String recipientName;
      if (_recipientType == 'single_driver') {
        recipientId = _selectedDriverId;
        recipientName = _selectedDriverName ?? 'Chauffeur';
      } else if (_recipientType == 'single_user') {
        recipientId = _selectedUserId;
        recipientName = _selectedUserName ?? 'Client';
      } else if (_recipientType == 'all_drivers') {
        recipientName = 'Tous les chauffeurs';
      } else if (_recipientType == 'all_users') {
        recipientName = 'Tous les clients';
      } else {
        recipientName = 'Tout le monde';
      }

      await supabase.from('admin_messages').insert({
        'sender_admin_email': supabase.auth.currentUser?.email ?? 'admin',
        'recipient_type': _recipientType,
        'recipient_id': recipientId,
        'recipient_name': recipientName,
        'title': _titleController.text,
        'message': _messageController.text,
      });

      await AdminLogService.log(
        action: _recipientType == 'all_drivers' ? 'Message broadcast chauffeurs' : _recipientType == 'all_users' ? 'Message broadcast clients' : _recipientType == 'all' ? 'Annonce globale' : 'Message chauffeur',
        targetType: 'message',
        targetId: _selectedDriverId,
        details: {'title': _titleController.text, 'recipientType': _recipientType},
      );

      _titleController.clear();
      _messageController.clear();
      setState(() { _selectedDriverId = null; _selectedDriverName = null; _selectedUserId = null; _selectedUserName = null; });
      _loadMessageHistory(); // Rafraîchir l'historique

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Message envoyé avec succès"), backgroundColor: Colors.green),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Communication", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Envoyer des messages aux chauffeurs", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF6366F1),
            unselectedLabelColor: Colors.grey.shade500,
            indicatorColor: const Color(0xFF6366F1),
            tabs: const [
              Tab(icon: Icon(Icons.send), text: "Envoyer"),
              Tab(icon: Icon(Icons.history), text: "Historique"),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(controller: _tabController, children: [
              _buildSendTab(isDark),
              _buildHistoryTab(isDark),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildSendTab(bool isDark) {
    return SingleChildScrollView(
      child: Card(
        elevation: 0,
        color: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Nouveau message", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 24),
            // Destinataire
            Text("Destinataire", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text("Tous les chauffeurs"),
                  selected: _recipientType == 'all_drivers',
                  selectedColor: const Color(0xFF6366F1),
                  labelStyle: TextStyle(color: _recipientType == 'all_drivers' ? Colors.white : null),
                  onSelected: (_) => setState(() { _recipientType = 'all_drivers'; _selectedDriverId = null; }),
                ),
                ChoiceChip(
                  label: const Text("Tous les clients"),
                  selected: _recipientType == 'all_users',
                  selectedColor: const Color(0xFF6366F1),
                  labelStyle: TextStyle(color: _recipientType == 'all_users' ? Colors.white : null),
                  onSelected: (_) => setState(() { _recipientType = 'all_users'; _selectedDriverId = null; }),
                ),
                ChoiceChip(
                  label: const Text("Tout le monde (Annonce globale)"),
                  selected: _recipientType == 'all',
                  selectedColor: const Color(0xFFEAB308),
                  labelStyle: TextStyle(color: _recipientType == 'all' ? Colors.white : null),
                  onSelected: (_) => setState(() { _recipientType = 'all'; _selectedDriverId = null; }),
                ),
                ChoiceChip(
                  label: const Text("Un client spécifique"),
                  selected: _recipientType == 'single_user',
                  selectedColor: const Color(0xFF8B5CF6),
                  labelStyle: TextStyle(color: _recipientType == 'single_user' ? Colors.white : null),
                  onSelected: (_) => setState(() => _recipientType = 'single_user'),
                ),
                ChoiceChip(
                  label: const Text("Un chauffeur spécifique"),
                  selected: _recipientType == 'single_driver',
                  selectedColor: const Color(0xFF6366F1),
                  labelStyle: TextStyle(color: _recipientType == 'single_driver' ? Colors.white : null),
                  onSelected: (_) => setState(() => _recipientType = 'single_driver'),
                ),
              ],
            ),
            if (_recipientType == 'single_driver') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedDriverId,
                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Sélectionner un chauffeur", 
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  prefixIcon: Icon(Icons.person_search, color: isDark ? Colors.white70 : Colors.black54)
                ),
                items: _drivers.map((d) => DropdownMenuItem(
                  value: d['id']?.toString(), 
                  child: Text("${d['name']} — ${d['phone'] ?? ''}", style: TextStyle(color: isDark ? Colors.white : Colors.black87))
                )).toList(),
                onChanged: (val) {
                  final driver = _drivers.firstWhere((d) => d['id']?.toString() == val, orElse: () => {});
                  setState(() { _selectedDriverId = val; _selectedDriverName = driver['name']?.toString(); });
                },
              ),
            ],
            if (_recipientType == 'single_user') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedUserId,
                dropdownColor: isDark ? AppColors.darkCard : Colors.white,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  labelText: "Sélectionner un client",
                  labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  prefixIcon: Icon(Icons.person_search, color: isDark ? Colors.white70 : Colors.black54),
                ),
                items: _users.map((u) => DropdownMenuItem(
                  value: u['id']?.toString(),
                  child: Text("${u['name'] ?? u['email'] ?? 'Client'} — ${u['phone'] ?? ''}", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                )).toList(),
                onChanged: (val) {
                  final user = _users.firstWhere((u) => u['id']?.toString() == val, orElse: () => {});
                  setState(() { _selectedUserId = val; _selectedUserName = user['name']?.toString() ?? user['email']?.toString(); });
                },
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController, 
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Titre du message", 
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                prefixIcon: Icon(Icons.title, color: isDark ? Colors.white70 : Colors.black54)
              )
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _messageController, 
              maxLines: 5, 
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                labelText: "Message", 
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                alignLabelWithHint: true, 
                prefixIcon: Padding(padding: const EdgeInsets.only(bottom: 80), child: Icon(Icons.message, color: isDark ? Colors.white70 : Colors.black54))
              )
            ),
            const SizedBox(height: 16),
            // Templates d'annonces rapides
            Text("Templates rapides", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _templateChip("🔧 Maintenance", "Maintenance système", "Le système sera en maintenance le [date]. Merci de votre patience.", isDark),
              _templateChip("🎉 Promotion", "Nouvelle promotion", "Profitez de notre nouvelle promotion ! [détails]", isDark),
              _templateChip("⚠️ Alerte", "Alerte importante", "Attention : [message d'alerte]. Merci de prendre les mesures nécessaires.", isDark),
              _templateChip("🔒 Sécurité", "Alerte sécurité", "Pour votre sécurité : [consignes]. Restez vigilants.", isDark),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.send),
                label: Text(_isSending ? "Envoi..." : "Envoyer le message"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _templateChip(String label, String title, String message, bool isDark) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: isDark ? AppColors.darkCardHover : Colors.grey.shade100,
      side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300),
      onPressed: () {
        _titleController.text = title;
        _messageController.text = message;
      },
    );
  }

  Widget _buildHistoryTab(bool isDark) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messageHistory.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        Text("Aucun message envoyé", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _loadMessageHistory, child: const Text("Rafraîchir")),
      ]));
    }
    return ListView.builder(
      itemCount: _messageHistory.length,
      itemBuilder: (context, index) {
        final msg = _messageHistory[index];
        final isBroadcast = msg['recipient_type'] == 'all_drivers' || msg['recipient_type'] == 'all_users' || msg['recipient_type'] == 'all';
        final isGlobal = msg['recipient_type'] == 'all';
        return Card(
          elevation: 0, margin: const EdgeInsets.only(bottom: 8),
          color: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isGlobal ? const Color(0xFFEAB308).withOpacity(0.1) : isBroadcast ? const Color(0xFFF59E0B).withOpacity(0.1) : const Color(0xFF6366F1).withOpacity(0.1),
              child: Icon(isGlobal ? Icons.campaign : isBroadcast ? Icons.groups : Icons.person, color: isGlobal ? const Color(0xFFEAB308) : isBroadcast ? const Color(0xFFF59E0B) : const Color(0xFF6366F1), size: 20),
            ),
            title: Text(msg['title']?.toString() ?? 'Sans titre', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87)),
            subtitle: Text("→ ${msg['recipient_name'] ?? 'N/A'} • ${msg['created_at']?.toString().substring(0, 16) ?? ''}", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: isGlobal ? const Color(0xFFEAB308).withOpacity(0.1) : isBroadcast ? const Color(0xFFF59E0B).withOpacity(0.1) : const Color(0xFF10B981).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(isGlobal ? "Globale" : isBroadcast ? "Broadcast" : "Direct", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isGlobal ? const Color(0xFFEAB308) : isBroadcast ? const Color(0xFFF59E0B) : const Color(0xFF10B981))),
            ),
            onTap: () => showDialog(context: context, builder: (ctx) => AlertDialog(
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(msg['title']?.toString() ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text("De: ${msg['sender_admin_email']}", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                Text("À: ${msg['recipient_name'] ?? 'N/A'}", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                Text("Date: ${msg['created_at']?.toString().substring(0, 19) ?? ''}", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                const Divider(height: 24),
                Text(msg['message']?.toString() ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
              ]),
              actions: [
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
                      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                      title: const Text("Supprimer ce message ?"),
                      content: const Text("Cette action est irréversible."),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Annuler")),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(c, true),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: const Text("Supprimer"),
                        ),
                      ],
                    ));
                    if (confirm == true) {
                      try {
                        await supabase.from('admin_messages').delete().eq('id', msg['id']);
                        await AdminLogService.log(action: 'Suppression message', targetType: 'message', targetId: msg['id']?.toString());
                        _loadMessageHistory();
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message supprimé"), backgroundColor: Colors.green));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
                      }
                    }
                  },
                  child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer")),
              ],
            )),
          ),
        );
      },
    );
  }
}
