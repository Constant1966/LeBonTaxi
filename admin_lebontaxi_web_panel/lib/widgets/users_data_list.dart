import '../constants/app_colors.dart';
import '../methods/common_methods.dart';
import '../services/admin_log_service.dart';
import '../dashboard/side_navigation_drawer.dart';
import '../pages/communication_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

class UsersDataList extends StatefulWidget {
  final String searchQuery;
  const UsersDataList({super.key, this.searchQuery = ""});

  @override
  State<UsersDataList> createState() => _UsersDataListState();
}

class _UsersDataListState extends State<UsersDataList> {
  final supabase = Supabase.instance.client;
  CommonMethods cMethods = CommonMethods();

  Future<void> _handleBlockAction(String userId, String currentStatus, String userName) async {
    final bool isBlocking = currentStatus == "no";
    final confirmed = await cMethods.showConfirmationDialog(context,
      isBlocking ? "Bloquer l'utilisateur" : "Approuver l'utilisateur",
      isBlocking ? "Êtes-vous sûr de vouloir bloquer $userName ?" : "Êtes-vous sûr de vouloir approuver $userName ?",
    );
    if (confirmed) {
      try {
        await supabase.from("users").update({"block_status": isBlocking ? "yes" : "no"}).eq("id", userId);
        await AdminLogService.log(action: isBlocking ? 'Blocage utilisateur' : 'Déblocage utilisateur', targetType: 'user', targetId: userId, details: {'name': userName});
        if (mounted) cMethods.showSnackBar(context, isBlocking ? "Utilisateur bloqué" : "Utilisateur approuvé");
      } catch (e) {
        if (mounted) cMethods.showSnackBar(context, "Erreur : $e", isError: true);
      }
    }
  }

  Future<void> _handleSuspend(String userId, String userName) async {
    String? duration;
    await showDialog(context: context, builder: (ctx) {
      final reasonCtrl = TextEditingController();
      final dlgDark = Theme.of(context).brightness == Brightness.dark;
      return StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: dlgDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Suspendre l'utilisateur", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87)),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Suspendre $userName temporairement", style: TextStyle(color: dlgDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: dlgDark ? AppColors.darkCard : Colors.white,
            style: TextStyle(color: dlgDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(labelText: "Durée", labelStyle: TextStyle(color: dlgDark ? Colors.white70 : Colors.black54)),
            items: [
              DropdownMenuItem(value: '1h', child: Text("1 heure", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '12h', child: Text("12 heures", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '1d', child: Text("1 jour", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '3d', child: Text("3 jours", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '7d', child: Text("1 semaine", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '30d', child: Text("1 mois", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
            ],
            onChanged: (v) => setDlg(() => duration = v),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: reasonCtrl, maxLines: 2, style: TextStyle(color: dlgDark ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: "Raison", labelStyle: TextStyle(color: dlgDark ? Colors.white70 : Colors.black54))),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (duration == null) return;
              final reason = reasonCtrl.text;
              Navigator.pop(ctx);
              DateTime until = DateTime.now();
              switch (duration) {
                case '1h': until = until.add(const Duration(hours: 1)); break;
                case '12h': until = until.add(const Duration(hours: 12)); break;
                case '1d': until = until.add(const Duration(days: 1)); break;
                case '3d': until = until.add(const Duration(days: 3)); break;
                case '7d': until = until.add(const Duration(days: 7)); break;
                case '30d': until = until.add(const Duration(days: 30)); break;
              }
              try {
                await supabase.from('suspensions').insert({'target_type': 'user', 'target_id': userId, 'target_name': userName, 'reason': reason.isEmpty ? 'Non spécifiée' : reason, 'suspended_until': until.toIso8601String(), 'admin_email': supabase.auth.currentUser?.email ?? 'admin'});
                await supabase.from("users").update({"block_status": "yes"}).eq("id", userId);
                await AdminLogService.log(action: 'Suspension utilisateur', targetType: 'suspension', targetId: userId, details: {'name': userName, 'duration': duration, 'until': until.toIso8601String()});
                if (mounted) cMethods.showSnackBar(context, "Utilisateur suspendu");
              } catch (e) {
                if (mounted) cMethods.showSnackBar(context, "Erreur: $e", isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
            child: const Text("Suspendre"),
          ),
        ],
      ));
    });
  }

  Future<void> _showSuspensionHistory(String userId, String userName) async {
    try {
      final data = await supabase.from('suspensions').select().eq('target_id', userId).eq('target_type', 'user').order('suspended_at', ascending: false);
      if (!mounted) return;
      final dlgDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: dlgDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Historique — $userName", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87)),
        content: SizedBox(width: 450, child: data.isEmpty
          ? Padding(padding: const EdgeInsets.all(20), child: Text("Aucune suspension enregistrée", style: TextStyle(color: dlgDark ? Colors.white70 : Colors.black87)))
          : SizedBox(height: 300, child: ListView.builder(itemCount: data.length, itemBuilder: (c, i) {
              final s = data[i];
              final isActive = s['is_active'] == true && DateTime.tryParse(s['suspended_until'] ?? '')?.isAfter(DateTime.now()) == true;
              return ListTile(
                leading: CircleAvatar(radius: 16, backgroundColor: isActive ? (dlgDark ? const Color(0xFFEF4444).withOpacity(0.2) : Colors.red.shade100) : (dlgDark ? Colors.grey.shade800 : Colors.grey.shade200), child: Icon(isActive ? Icons.block : Icons.check, size: 16, color: isActive ? (dlgDark ? const Color(0xFFF87171) : Colors.red) : Colors.grey)),
                title: Text(s['reason']?.toString() ?? 'N/A', style: TextStyle(fontSize: 13, color: dlgDark ? Colors.white : Colors.black87)),
                subtitle: Text("Jusqu'au ${s['suspended_until']?.toString().substring(0, 10) ?? 'N/A'}", style: TextStyle(fontSize: 11, color: dlgDark ? Colors.grey.shade400 : Colors.grey.shade500)),
                trailing: isActive ? TextButton(
                  onPressed: () async {
                    await supabase.from('suspensions').update({'is_active': false, 'reactivated_at': DateTime.now().toIso8601String(), 'reactivated_by': supabase.auth.currentUser?.email}).eq('id', s['id']);
                    await supabase.from("users").update({"block_status": "no"}).eq("id", userId);
                    await AdminLogService.log(action: 'Réactivation utilisateur', targetType: 'suspension', targetId: userId, details: {'name': userName});
                    Navigator.pop(ctx);
                    if (mounted) cMethods.showSnackBar(context, "Utilisateur réactivé");
                  },
                  child: const Text("Réactiver", style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                ) : null,
              );
            }))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer"))],
      ));
    } catch (e) {
      if (mounted) cMethods.showSnackBar(context, "Erreur: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('users').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.error_outline, size: 64, color: Colors.red.shade300), const SizedBox(height: 16), const Text("Une erreur est survenue", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))])));
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), const Text("Aucun utilisateur trouvé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))])));

        List<Map<String, dynamic>> itemsList = snapshot.data!;
        if (widget.searchQuery.isNotEmpty) {
          itemsList = itemsList.where((item) {
            final name = item["name"]?.toString().toLowerCase() ?? "";
            final email = item["email"]?.toString().toLowerCase() ?? "";
            final phone = item["phone"]?.toString().toLowerCase() ?? "";
            return name.contains(widget.searchQuery) || email.contains(widget.searchQuery) || phone.contains(widget.searchQuery);
          }).toList();
        }
        if (itemsList.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(40), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.search_off, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), const Text("Aucun résultat trouvé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20))])));

        return ListView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: itemsList.length,
          itemBuilder: ((context, index) {
            final user = itemsList[index];
            final isBlocked = user["block_status"] == "yes";
            
            return Container(
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? AppColors.darkCard : Colors.grey.shade100))),
              child: Row(children: [
                cMethods.data(2, Text(user["id"]?.toString() ?? "N/A", style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: isDark ? Colors.white70 : Colors.black87)), isDark: isDark),
                cMethods.data(1, Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1), child: Text(
                    (user["name"]?.toString() != null && user["name"].toString().isNotEmpty) ? user["name"].toString()[0].toUpperCase() : "?",
                    style: const TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: Text(user["name"]?.toString() ?? "N/A", style: TextStyle(fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87))),
                ]), isDark: isDark),
                cMethods.data(1, Text(user["email"]?.toString() ?? "N/A", style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87), overflow: TextOverflow.ellipsis), isDark: isDark),
                cMethods.data(1, Text(user["phone"]?.toString().replaceAll('++', '+') ?? "N/A", style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)), isDark: isDark),
                cMethods.data(1, cMethods.buildStatusBadge(user["block_status"] ?? "no", isDark: isDark), isDark: isDark),
                cMethods.data(1, PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Color(0xFF6B7280)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'block', child: Row(children: [
                      Icon(isBlocked ? Icons.check_circle : Icons.block, size: 18, color: isBlocked ? const Color(0xFF10B981) : Colors.red),
                      const SizedBox(width: 8), Text(isBlocked ? "Approuver" : "Bloquer"),
                    ])),
                    if (!isBlocked) const PopupMenuItem(value: 'suspend', child: Row(children: [
                      Icon(Icons.timer_off, size: 18, color: Color(0xFFF59E0B)), SizedBox(width: 8), Text("Suspendre"),
                    ])),
                    const PopupMenuItem(value: 'message', child: Row(children: [
                      Icon(Icons.message, size: 18, color: Color(0xFF3B82F6)), SizedBox(width: 8), Text("Contacter"),
                    ])),
                    const PopupMenuItem(value: 'history', child: Row(children: [
                      Icon(Icons.history, size: 18, color: Color(0xFF6366F1)), SizedBox(width: 8), Text("Historique"),
                    ])),
                  ],
                  onSelected: (val) {
                    switch (val) {
                      case 'block': _handleBlockAction(user["id"]?.toString() ?? "", user["block_status"] ?? "no", user["name"]?.toString() ?? "Utilisateur"); break;
                      case 'suspend': _handleSuspend(user["id"]?.toString() ?? "", user["name"]?.toString() ?? "Utilisateur"); break;
                      case 'message':
                        final drawerState = context.findAncestorStateOfType<SideNavigationDrawerState>();
                        if (drawerState != null) {
                          drawerState.setChosenScreen(
                            CommunicationPage(
                              initialRecipientId: user["id"]?.toString(),
                            ),
                            CommunicationPage.id,
                          );
                        }
                        break;
                      case 'history': _showSuspensionHistory(user["id"]?.toString() ?? "", user["name"]?.toString() ?? "Utilisateur"); break;
                    }
                  },
                ), isDark: isDark),
              ]),
            );
          }),
        );
      },
    );
  }
}
