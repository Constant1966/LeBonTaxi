import '../constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLogsPage extends StatefulWidget {
  static const String id = "\\webPageAdminLogs";
  const AdminLogsPage({super.key});

  @override
  State<AdminLogsPage> createState() => _AdminLogsPageState();
}

class _AdminLogsPageState extends State<AdminLogsPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _filterType = 'all';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('admin_logs').select();
      if (_filterType != 'all') {
        query = query.eq('target_type', _filterType);
      }
      final data = await query.order('created_at', ascending: false).limit(200);
      if (mounted) setState(() { _logs = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _actionColor(String? type) {
    switch (type) {
      case 'driver': return const Color(0xFF3B82F6);
      case 'user': return const Color(0xFF8B5CF6);
      case 'document': return const Color(0xFF6366F1);
      case 'pricing': return const Color(0xFF10B981);
      case 'discount': return const Color(0xFFF59E0B);
      case 'message': return const Color(0xFF6366F1);
      case 'review': return const Color(0xFFEC4899);
      case 'suspension': return const Color(0xFFEF4444);
      default: return const Color(0xFF6B7280);
    }
  }

  IconData _actionIcon(String? type) {
    switch (type) {
      case 'driver': return Icons.local_taxi;
      case 'user': return Icons.person;
      case 'document': return Icons.folder_special;
      case 'pricing': return Icons.attach_money;
      case 'discount': return Icons.discount;
      case 'message': return Icons.message;
      case 'review': return Icons.reviews;
      case 'suspension': return Icons.block;
      default: return Icons.history;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final types = ['all', 'driver', 'user', 'document', 'pricing', 'discount', 'message', 'review', 'suspension'];
    final labels = {'all': 'Tous', 'driver': 'Chauffeurs', 'user': 'Utilisateurs', 'document': 'Documents', 'pricing': 'Tarifs', 'discount': 'Rabais', 'message': 'Messages', 'review': 'Avis', 'suspension': 'Suspensions'};

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Logs d'administration", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Historique de toutes les actions admin", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            ]),
            IconButton(onPressed: _loadLogs, icon: const Icon(Icons.refresh), tooltip: "Rafraîchir"),
          ]),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: types.map((t) {
              final isActive = _filterType == t;
              final c = t == 'all' ? const Color(0xFF6366F1) : _actionColor(t);
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: isActive, selectedColor: c, checkmarkColor: Colors.white,
                  label: Text(labels[t] ?? t),
                  labelStyle: TextStyle(color: isActive ? Colors.white : null, fontSize: 12, fontWeight: FontWeight.w500),
                  backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                  side: BorderSide(color: isActive ? c : (isDark ? AppColors.darkBorder : Colors.grey.shade300)),
                  onSelected: (_) { setState(() => _filterType = t); _loadLogs(); },
                ),
              );
            }).toList()),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text("Aucun log trouvé", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                      ]))
                    : ListView.builder(itemCount: _logs.length, itemBuilder: (ctx, i) {
                        final log = _logs[i];
                        final color = _actionColor(log['target_type']);
                        return Card(
                          elevation: 0, margin: const EdgeInsets.only(bottom: 6),
                          color: isDark ? AppColors.darkCard : Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: color.withOpacity(0.1),
                              child: Icon(_actionIcon(log['target_type']), color: color, size: 18),
                            ),
                            title: Text(log['action']?.toString() ?? 'Action', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                            subtitle: Row(children: [
                              Icon(Icons.person_outline, size: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(log['admin_email']?.toString() ?? '', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
                              const SizedBox(width: 12),
                              Icon(Icons.access_time, size: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(log['created_at']?.toString().substring(0, 16) ?? '', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
                            ]),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                              child: Text(log['target_type']?.toString() ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
                            ),
                            onTap: () {
                              showDialog(context: context, builder: (c) => AlertDialog(
                                backgroundColor: isDark ? AppColors.darkCard : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                title: Text(log['action']?.toString() ?? '', style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                                content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _logDetail("Admin", log['admin_email']?.toString() ?? '', isDark),
                                  _logDetail("Type", log['target_type']?.toString() ?? '', isDark),
                                  _logDetail("Cible", log['target_id']?.toString() ?? 'N/A', isDark),
                                  _logDetail("Date", log['created_at']?.toString() ?? '', isDark),
                                  if (log['details'] != null) ...[
                                    const Divider(),
                                    Text("Détails:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
                                    const SizedBox(height: 8),
                                    Text(log['details'].toString(), style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: isDark ? Colors.white : Colors.black87)),
                                  ],
                                ]),
                                actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Fermer"))],
                              ));
                            },
                          ),
                        );
                      }),
          ),
        ]),
      ),
    );
  }

  Widget _logDetail(String label, String value, bool isDark) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 70, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87))),
    ]),
  );
}
