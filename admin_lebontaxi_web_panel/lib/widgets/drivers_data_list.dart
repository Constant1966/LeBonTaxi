import 'dart:async';
import '../constants/app_colors.dart';
import '../methods/common_methods.dart';
import '../services/admin_log_service.dart';
import '../widgets/document_review_card.dart';
import '../dashboard/side_navigation_drawer.dart';
import '../pages/communication_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget note chauffeur (inchangé)
// ─────────────────────────────────────────────────────────────────────────────
class DriverRatingWidget extends StatelessWidget {
  final String driverId;
  final bool isDark;
  const DriverRatingWidget({super.key, required this.driverId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Supabase.instance.client.from('ratings').select('rating').eq('driver_id', driverId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
        }
        final ratings = snapshot.data!;
        if (ratings.isEmpty) {
          return Row(children: [
            const Icon(Icons.star_border, color: Colors.amber, size: 16),
            const SizedBox(width: 4),
            Text("N/A", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)),
          ]);
        }
        double total = 0;
        for (var r in ratings) { total += (r['rating'] as num).toDouble(); }
        final avg = total / ratings.length;
        return Row(children: [
          const Icon(Icons.star, color: Colors.amber, size: 16),
          const SizedBox(width: 4),
          Text(avg.toStringAsFixed(1),
              style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          Text(" (${ratings.length})",
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey)),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DriversDataList
// ─────────────────────────────────────────────────────────────────────────────
class DriversDataList extends StatefulWidget {
  final String searchQuery;
  const DriversDataList({super.key, this.searchQuery = ""});

  @override
  State<DriversDataList> createState() => _DriversDataListState();
}

class _DriversDataListState extends State<DriversDataList> {
  final supabase = Supabase.instance.client;
  CommonMethods cMethods = CommonMethods();

  // ── Données chauffeurs (polling) ───────────────────────────────────────────
  List<Map<String, dynamic>> _driversList = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorText = '';
  Timer? _pollTimer;

  // ── Filtre admin par EMAIL ─────────────────────────────────────────────────
  Set<String> _adminEmails = {};

  @override
  void initState() {
    super.initState();
    _loadAdminEmails();
    _loadDrivers();
    // Polling toutes les 5 secondes pour avoir les données fraîches
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _loadDrivers());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// Charger la liste des chauffeurs depuis Supabase (polling)
  Future<void> _loadDrivers() async {
    try {
      final data = await supabase
          .from('drivers')
          .select()
          .order('name', ascending: true);
      final onlineCount = data.where((d) => d['is_online'] == true || d['is_available'] == true).length;
      print('📡 [DriversPage] ${data.length} chauffeurs | $onlineCount en ligne | User: ${supabase.auth.currentUser?.email}');
      if (data.isEmpty) {
        print('⚠️ [DriversPage] 0 résultats ! Vérifiez les politiques RLS sur la table "drivers"');
      }
      if (mounted) {
        setState(() {
          _driversList = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      print('❌ [DriversPage] Erreur chargement: $e');
      if (mounted && _driversList.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorText = e.toString();
        });
      }
    }
  }

  Future<void> _loadAdminEmails() async {
    try {
      // La table admins ne stocke QUE l'email — on ne sélectionne que ça.
      final data = await supabase.from('admins').select('email');
      if (mounted) {
        setState(() {
          _adminEmails = {
            for (final row in data)
              if (row['email'] != null) row['email'].toString().toLowerCase().trim()
          };
        });
      }
    } catch (_) {
      // Échec silencieux : aucun chauffeur exclu par erreur
    }
  }

  /// Retourne true si cette ligne `drivers` est un compte fantôme d'admin.
  ///
  /// Règle : email connu comme admin  ET  aucune info réelle de chauffeur.
  /// → Un vrai chauffeur avec nom/téléphone/voiture n'est JAMAIS exclu.
  bool _isGhostAdminEntry(Map<String, dynamic> driver) {
    final email    = (driver['email'] ?? '').toString().toLowerCase().trim();
    final hasName  = (driver['name']?.toString() ?? '').trim().isNotEmpty
                     && !(driver['name'].toString().contains('@'));
    final hasPhone = (driver['phone']?.toString() ?? '').trim().isNotEmpty;
    final hasCar   = (driver['car_model']?.toString() ?? '').trim().isNotEmpty;

    // Si l'email n'est pas dans les admins, on affiche toujours
    if (!_adminEmails.contains(email)) return false;

    // Si l'email est un admin mais que le chauffeur a de vraies infos → afficher
    if (hasName || hasPhone || hasCar) return false;

    // Email admin + aucune info → fantôme
    return true;
  }

  // ── CORRECTION 2 : parse is_online / is_available + last_location_update ──
  // Supabase peut renvoyer bool, int (0/1) ou String selon la config de la table.
  // On vérifie aussi last_location_update : si < 5 min → considéré en ligne.
  bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is int) return val == 1;
    if (val is String) {
      final v = val.toLowerCase().trim();
      return v == 'true' || v == '1' || v == 'yes' || v == 'online';
    }
    return false;
  }

  bool _isDriverOnline(Map<String, dynamic> driver) {
    // 1) Champs booléens classiques
    if (_parseBool(driver['is_online'])) return true;
    if (_parseBool(driver['is_available'])) return true;

    // 2) Vérifier le timestamp de dernière mise à jour de position
    final lastUpdate = driver['last_location_update']?.toString();
    if (lastUpdate != null && lastUpdate.isNotEmpty) {
      final dt = DateTime.tryParse(lastUpdate);
      if (dt != null) {
        final diff = DateTime.now().toUtc().difference(dt.toUtc());
        if (diff.inMinutes < 5) return true;
      }
    }
    return false;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────
  Future<void> _handleBlockAction(String driverId, String currentStatus, String driverName) async {
    final bool isBlocking = currentStatus == "no";
    final confirmed = await cMethods.showConfirmationDialog(
      context,
      isBlocking ? "Bloquer le chauffeur" : "Approuver le chauffeur",
      isBlocking ? "Bloquer $driverName ?" : "Approuver $driverName ?",
    );
    if (confirmed) {
      try {
        await supabase.from("drivers")
            .update({"block_status": isBlocking ? "yes" : "no"})
            .eq("id", driverId);
        await AdminLogService.log(
          action: isBlocking ? 'Blocage chauffeur' : 'Déblocage chauffeur',
          targetType: 'driver', targetId: driverId,
          details: {'name': driverName},
        );
        if (mounted) cMethods.showSnackBar(context, isBlocking ? "Chauffeur bloqué" : "Chauffeur approuvé");
      } catch (e) {
        if (mounted) cMethods.showSnackBar(context, "Erreur : $e", isError: true);
      }
    }
  }

  Future<void> _handleSuspend(String driverId, String driverName) async {
    String? duration;
    await showDialog(context: context, builder: (ctx) {
      final reasonCtrl = TextEditingController();
      final dlgDark = Theme.of(context).brightness == Brightness.dark;
      return StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        backgroundColor: dlgDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Suspendre le chauffeur",
            style: TextStyle(color: dlgDark ? Colors.white : Colors.black87)),
        content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Suspendre $driverName temporairement",
              style: TextStyle(color: dlgDark ? Colors.grey.shade400 : Colors.grey.shade600)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            dropdownColor: dlgDark ? AppColors.darkCard : Colors.white,
            style: TextStyle(color: dlgDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
                labelText: "Durée",
                labelStyle: TextStyle(color: dlgDark ? Colors.white70 : Colors.black54)),
            items: [
              DropdownMenuItem(value: '1h',  child: Text("1 heure",   style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '12h', child: Text("12 heures", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '1d',  child: Text("1 jour",    style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '3d',  child: Text("3 jours",   style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '7d',  child: Text("1 semaine", style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
              DropdownMenuItem(value: '30d', child: Text("1 mois",    style: TextStyle(color: dlgDark ? Colors.white : Colors.black87))),
            ],
            onChanged: (v) => setDlg(() => duration = v),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: reasonCtrl, maxLines: 2,
            style: TextStyle(color: dlgDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
                labelText: "Raison",
                labelStyle: TextStyle(color: dlgDark ? Colors.white70 : Colors.black54)),
          ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
            child: const Text("Suspendre"),
            onPressed: () async {
              if (duration == null) return;
              final reason = reasonCtrl.text;
              Navigator.pop(ctx);
              DateTime until = DateTime.now();
              switch (duration) {
                case '1h':  until = until.add(const Duration(hours: 1));  break;
                case '12h': until = until.add(const Duration(hours: 12)); break;
                case '1d':  until = until.add(const Duration(days: 1));   break;
                case '3d':  until = until.add(const Duration(days: 3));   break;
                case '7d':  until = until.add(const Duration(days: 7));   break;
                case '30d': until = until.add(const Duration(days: 30));  break;
              }
              try {
                await supabase.from('suspensions').insert({
                  'target_type': 'driver', 'target_id': driverId,
                  'target_name': driverName,
                  'reason': reason.isEmpty ? 'Non spécifiée' : reason,
                  'suspended_until': until.toIso8601String(),
                  'admin_email': supabase.auth.currentUser?.email ?? 'admin',
                });
                await supabase.from("drivers").update({"block_status": "yes"}).eq("id", driverId);
                await AdminLogService.log(
                  action: 'Suspension chauffeur', targetType: 'suspension', targetId: driverId,
                  details: {'name': driverName, 'duration': duration, 'until': until.toIso8601String()},
                );
                if (mounted) cMethods.showSnackBar(context, "Chauffeur suspendu");
              } catch (e) {
                if (mounted) cMethods.showSnackBar(context, "Erreur: $e", isError: true);
              }
            },
          ),
        ],
      ));
    });
  }

  Future<void> _showSuspensionHistory(String driverId, String driverName) async {
    try {
      final data = await supabase.from('suspensions')
          .select()
          .eq('target_id', driverId)
          .eq('target_type', 'driver')
          .order('suspended_at', ascending: false);
      if (!mounted) return;
      final dlgDark = Theme.of(context).brightness == Brightness.dark;
      showDialog(context: context, builder: (ctx) => AlertDialog(
        backgroundColor: dlgDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Historique — $driverName",
            style: TextStyle(color: dlgDark ? Colors.white : Colors.black87)),
        content: SizedBox(width: 450, child: data.isEmpty
          ? Padding(padding: const EdgeInsets.all(20),
              child: Text("Aucune suspension enregistrée",
                  style: TextStyle(color: dlgDark ? Colors.white70 : Colors.black87)))
          : SizedBox(height: 300, child: ListView.builder(
              itemCount: data.length,
              itemBuilder: (c, i) {
                final s = data[i];
                final isActive = s['is_active'] == true &&
                    DateTime.tryParse(s['suspended_until'] ?? '')?.isAfter(DateTime.now()) == true;
                return ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: isActive
                        ? (dlgDark ? const Color(0xFFEF4444).withOpacity(0.2) : Colors.red.shade100)
                        : (dlgDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    child: Icon(isActive ? Icons.block : Icons.check, size: 16,
                        color: isActive ? (dlgDark ? const Color(0xFFF87171) : Colors.red) : Colors.grey),
                  ),
                  title: Text(s['reason']?.toString() ?? 'N/A',
                      style: TextStyle(fontSize: 13, color: dlgDark ? Colors.white : Colors.black87)),
                  subtitle: Text(
                      "Jusqu'au ${s['suspended_until']?.toString().substring(0, 10) ?? 'N/A'}",
                      style: TextStyle(fontSize: 11,
                          color: dlgDark ? Colors.grey.shade400 : Colors.grey.shade500)),
                  trailing: isActive ? TextButton(
                    onPressed: () async {
                      await supabase.from('suspensions').update({
                        'is_active': false,
                        'reactivated_at': DateTime.now().toIso8601String(),
                        'reactivated_by': supabase.auth.currentUser?.email,
                      }).eq('id', s['id']);
                      await supabase.from("drivers").update({"block_status": "no"}).eq("id", driverId);
                      await AdminLogService.log(
                        action: 'Réactivation chauffeur', targetType: 'suspension',
                        targetId: driverId, details: {'name': driverName},
                      );
                      Navigator.pop(ctx);
                      if (mounted) cMethods.showSnackBar(context, "Chauffeur réactivé");
                    },
                    child: const Text("Réactiver", style: TextStyle(color: Color(0xFF10B981), fontSize: 12)),
                  ) : null,
                );
              },
            ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer"))],
      ));
    } catch (e) {
      if (mounted) cMethods.showSnackBar(context, "Erreur: $e", isError: true);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── État de chargement ──
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    }

    if (_hasError) {
      return Center(child: Padding(padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          const Text("Erreur de chargement", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 8),
          Text(_errorText, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadDrivers, child: const Text("Réessayer")),
        ])));
    }

    if (_driversList.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Aucun chauffeur trouvé", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ])));
    }

    // ── Filtre : exclure les comptes fantômes admin ──
    List<Map<String, dynamic>> itemsList =
        _driversList.where((d) => !_isGhostAdminEntry(d)).toList();

    // ── Filtre recherche ──
    if (widget.searchQuery.isNotEmpty) {
      itemsList = itemsList.where((item) {
        final name      = (item["name"]?.toString() ?? "").toLowerCase();
        final phone     = (item["phone"]?.toString() ?? "").toLowerCase();
        final carModel  = (item["car_model"]?.toString() ?? "").toLowerCase();
        final carNumber = (item["car_number"]?.toString() ?? "").toLowerCase();
        return name.contains(widget.searchQuery)
            || phone.contains(widget.searchQuery)
            || carModel.contains(widget.searchQuery)
            || carNumber.contains(widget.searchQuery);
      }).toList();
    }

    if (itemsList.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(widget.searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(widget.searchQuery.isNotEmpty ? "Aucun résultat trouvé" : "Aucun chauffeur trouvé",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        ])));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisExtent: 230,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
      ),
      itemCount: itemsList.length,
      itemBuilder: (context, index) {
        final driver    = itemsList[index];
        final isBlocked = driver["block_status"] == "yes";
        final isOnline  = _isDriverOnline(driver);

        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Photo & Basic Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          driver["photo"]?.toString() ?? "",
                          width: 56, height: 56, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.person, color: Color(0xFF6366F1), size: 30),
                          ),
                        ),
                      ),
                      Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? AppColors.darkCard : Colors.white, width: 2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver["name"]?.toString() ?? "N/A",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.phone, size: 12, color: isDark ? Colors.white54 : Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            driver["phone"]?.toString() ?? "N/A",
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54),
                          ),
                        ]),
                        const SizedBox(height: 6),
                        DriverRatingWidget(driverId: driver["id"]?.toString() ?? "", isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              Divider(color: isDark ? AppColors.darkBorder : Colors.grey.shade100, height: 1),
              const SizedBox(height: 12),
              
              // 2. Vehicle Details
              Row(
                children: [
                  const Icon(Icons.directions_car_rounded, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "${driver['car_model'] ?? ''} ${driver['car_color'] ?? ''}".trim(),
                      style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      driver["car_number"]?.toString() ?? "N/A",
                      style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // 3. Status & Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  cMethods.buildStatusBadge(driver["block_status"] ?? "no", isDark: isDark),
                  
                  // Action Menu
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, color: isDark ? Colors.white70 : Colors.black87),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      position: PopupMenuPosition.under,
                      itemBuilder: (ctx) => [
                        PopupMenuItem(value: 'details', child: Row(children: [
                          const Icon(Icons.info_outline, size: 18, color: Color(0xFF6366F1)),
                          const SizedBox(width: 8),
                          const Text("Voir détails"),
                        ])),
                        PopupMenuItem(value: 'block', child: Row(children: [
                          Icon(isBlocked ? Icons.check_circle : Icons.block,
                              size: 18, color: isBlocked ? const Color(0xFF10B981) : Colors.red),
                          const SizedBox(width: 8),
                          Text(isBlocked ? "Approuver" : "Bloquer"),
                        ])),
                        if (!isBlocked) const PopupMenuItem(value: 'suspend', child: Row(children: [
                          Icon(Icons.timer_off, size: 18, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8), Text("Suspendre"),
                        ])),
                        const PopupMenuItem(value: 'message', child: Row(children: [
                          Icon(Icons.message, size: 18, color: Color(0xFF3B82F6)),
                          SizedBox(width: 8), Text("Envoyer un message"),
                        ])),
                        const PopupMenuItem(value: 'history', child: Row(children: [
                          Icon(Icons.history, size: 18, color: Color(0xFF6366F1)),
                          SizedBox(width: 8), Text("Historique"),
                        ])),
                        const PopupMenuItem(value: 'documents', child: Row(children: [
                          Icon(Icons.folder_special, size: 18, color: Color(0xFF8B5CF6)),
                          SizedBox(width: 8), Text("Voir documents"),
                        ])),
                      ],
                      onSelected: (val) {
                        final id   = driver["id"]?.toString() ?? "";
                        final name = driver["name"]?.toString() ?? "Chauffeur";
                        switch (val) {
                          case 'details': _showDriverDetails(driver, isDark); break;
                          case 'block':   _handleBlockAction(id, driver["block_status"] ?? "no", name); break;
                          case 'suspend': _handleSuspend(id, name); break;
                          case 'message':
                            final drawerState = context.findAncestorStateOfType<SideNavigationDrawerState>();
                            if (drawerState != null) {
                              drawerState.setChosenScreen(
                                CommunicationPage(
                                  initialRecipientId: id,
                                ),
                                CommunicationPage.id,
                              );
                            }
                            break;
                          case 'history': _showSuspensionHistory(id, name); break;
                          case 'documents': _openDocumentsDialog(driver, isDark); break;
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Dialog détails complets du chauffeur ──────────────────────────────────
  void _showDriverDetails(Map<String, dynamic> driver, bool isDark) {
    final isOnline = _isDriverOnline(driver);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Photo + statut
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      driver["photo"]?.toString() ?? "",
                      width: 100, height: 100, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person, color: Color(0xFF6366F1), size: 50),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF10B981) : Colors.grey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(isOnline ? "En ligne" : "Hors ligne",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(driver["name"]?.toString() ?? "N/A",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 4),
              Text(driver["email"]?.toString() ?? "",
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
              const SizedBox(height: 16),

              // Note
              DriverRatingWidget(driverId: driver["id"]?.toString() ?? "", isDark: isDark),
              const SizedBox(height: 20),
              Divider(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
              const SizedBox(height: 12),

              // Infos
              _detailRow(Icons.phone, "Téléphone", driver["phone"]?.toString() ?? "N/A", isDark),
              _detailRow(Icons.directions_car, "Véhicule", "${driver['car_model'] ?? ''} ${driver['car_color'] ?? ''}".trim(), isDark),
              _detailRow(Icons.pin, "Plaque", driver["car_number"]?.toString() ?? "N/A", isDark),
              if (driver["car_year"] != null) _detailRow(Icons.calendar_today, "Année", driver["car_year"].toString(), isDark),
              _detailRow(Icons.verified, "Vérifié", _parseBool(driver["verified"]) ? "Oui" : "Non", isDark),
              _detailRow(Icons.block, "Statut", driver["block_status"] == "yes" ? "Bloqué" : "Actif", isDark),
              _detailRow(Icons.folder_special, "Documents", _documentStatusLabel(driver["document_status"]?.toString()), isDark),
              if (driver["documents_rejection_note"] != null && driver["documents_rejection_note"].toString().isNotEmpty)
                _detailRow(Icons.info_outline, "Note rejet", driver["documents_rejection_note"].toString(), isDark),

              if (driver["current_latitude"] != null && driver["current_longitude"] != null) ...[
                const SizedBox(height: 8),
                _detailRow(Icons.location_on, "Position", "${driver['current_latitude']}, ${driver['current_longitude']}", isDark),
              ],
              if (driver["last_location_update"] != null)
                _detailRow(Icons.access_time, "Dernière activité", driver["last_location_update"].toString().substring(0, 19), isDark),
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Fermer"))],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: const Color(0xFF6366F1)),
        const SizedBox(width: 12),
        SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade600))),
        Expanded(child: Text(value, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87))),
      ]),
    );
  }

  String _documentStatusLabel(String? status) {
    const labels = {
      'pending': '⏳ En attente',
      'under_review': '🔍 En révision',
      'approved': '✅ Approuvé',
      'rejected': '❌ Rejeté',
      'documents_required': '⚠️ Docs manquants',
    };
    return labels[status] ?? status ?? 'N/A';
  }


  // ── Dialog documents d'un chauffeur (accès rapide depuis la liste) ──────────
  void _openDocumentsDialog(Map<String, dynamic> driver, bool isDark) {
    // Import : '../widgets/document_review_card.dart'
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DocumentReviewDialog(
        driver: driver,
        isDark: isDark,
        onStatusChanged: _loadDrivers,
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  const _PulsingDot();
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: 8, height: 8,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
    ),
  );
}