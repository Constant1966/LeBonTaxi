import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/pages/edit_profile_page.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  bool _isLoading = true;
  Position? _currentPosition;
  String _emergencyName = "";
  String _emergencyPhone = "";

  // ✅ Services d'urgence en Haïti
  final List<EmergencyService> _emergencyServices = [
    // Police
    EmergencyService(
      name: "Police Nationale d'Haïti",
      type: EmergencyType.police,
      phone: "114",
      icon: Icons.local_police,
      color: const Color(0xFF1976D2),
    ),
    EmergencyService(
      name: "Police Touristique",
      type: EmergencyType.police,
      phone: "4111",
      icon: Icons.local_police,
      color: const Color(0xFF1976D2),
    ),

    // Pompiers
    EmergencyService(
      name: "Pompiers",
      type: EmergencyType.fire,
      phone: "115",
      icon: Icons.local_fire_department,
      color: const Color(0xFFE53935),
    ),

    // Ambulance
    EmergencyService(
      name: "Ambulance",
      type: EmergencyType.ambulance,
      phone: "116",
      icon: Icons.local_hospital,
      color: const Color(0xFFD32F2F),
    ),

    // Hôpitaux majeurs
    EmergencyService(
      name: "Hôpital Général",
      type: EmergencyType.hospital,
      phone: "2222-2323",
      address: "Port-au-Prince",
      icon: Icons.medical_services,
      color: const Color(0xFFE91E63),
    ),
    EmergencyService(
      name: "Hôpital Universitaire",
      type: EmergencyType.hospital,
      phone: "2245-7272",
      address: "Delmas",
      icon: Icons.medical_services,
      color: const Color(0xFFE91E63),
    ),
    EmergencyService(
      name: "Hôpital Français",
      type: EmergencyType.hospital,
      phone: "2816-3939",
      address: "Canapé-Vert",
      icon: Icons.medical_services,
      color: const Color(0xFFE91E63),
    ),
    EmergencyService(
      name: "Hôpital Espoir",
      type: EmergencyType.hospital,
      phone: "2813-4000",
      address: "Tabarre",
      icon: Icons.medical_services,
      color: const Color(0xFFE91E63),
    ),

    // Protection Civile
    EmergencyService(
      name: "Protection Civile",
      type: EmergencyType.civilDefense,
      phone: "117",
      icon: Icons.health_and_safety,
      color: const Color(0xFFFF9800),
    ),

    // Croix-Rouge
    EmergencyService(
      name: "Croix-Rouge Haïtienne",
      type: EmergencyType.civilDefense,
      phone: "2222-5052",
      address: "Port-au-Prince",
      icon: Icons.medical_services_outlined,
      color: const Color(0xFFE53935),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadEmergencyContact();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = pos;
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Erreur position: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadEmergencyContact() async {
    try {
      final profile = await SupabaseService.getUserProfile();
      if (profile != null && mounted) {
        setState(() {
          _emergencyName = profile['emergency_contact_name'] ?? '';
          _emergencyPhone = profile['emergency_contact_phone'] ?? '';
        });
      }
    } catch (e) {
      print("❌ Erreur chargement contact d'urgence: $e");
    }
  }

  Future<void> _sendSOS_SMS() async {
    final lat = _currentPosition?.latitude;
    final lng = _currentPosition?.longitude;
    final locationLink = (lat != null && lng != null)
        ? "https://www.google.com/maps/search/?api=1&query=$lat,$lng"
        : "[Localisation non disponible]";
    
    final message = "SOS ! Je suis actuellement en déplacement avec Le Bon Taxi et j'ai besoin d'aide. Ma position en direct : $locationLink";
    
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: _emergencyPhone,
      queryParameters: <String, String>{
        'body': message,
      },
    );
    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        // Fallback pour certains appareils
        final Uri fallbackUri = Uri.parse("sms:$_emergencyPhone?body=${Uri.encodeComponent(message)}");
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri);
        } else {
          throw Exception("Impossible d'ouvrir l'application de messagerie SMS");
        }
      }
    } catch (e) {
      print("❌ Erreur SOS SMS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur d'envoi SMS : $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildTrustContactSection() {
    final hasContact = _emergencyName.isNotEmpty && _emergencyPhone.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
        border: Border.all(
          color: hasContact ? AppColors.success.withOpacity(0.3) : AppColors.getBorderColor(context),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasContact ? Icons.verified_user : Icons.gpp_maybe_outlined,
                color: hasContact ? AppColors.success : AppColors.warning,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                "Contact de confiance",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.getTextPrimaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!hasContact) ...[
            Text(
              "Vous n'avez pas encore configuré de contact de confiance pour votre sécurité.",
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const EditProfilePage()),
                  );
                  if (result == true) {
                    _loadEmergencyContact();
                  }
                },
                icon: const Icon(Icons.add, size: 20),
                label: const Text("Configurer maintenant"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _emergencyName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.getTextPrimaryColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emergencyPhone,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.getTextSecondaryColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.call, color: Colors.white, size: 18),
                  ),
                  onPressed: () => _callNumber(_emergencyPhone, _emergencyName),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.message, color: Colors.white, size: 18),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Row(
                          children: [
                            Icon(Icons.warning, color: Color(0xFFE53935)),
                            SizedBox(width: 12),
                            Text("Alerte SOS"),
                          ],
                        ),
                        content: Text(
                          "Voulez-vous envoyer un SMS d'alerte SOS à $_emergencyName avec votre position actuelle ?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Annuler"),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _sendSOS_SMS();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935), foregroundColor: Colors.white),
                            child: const Text("Envoyer"),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackgroundColor(context),
      appBar: AppBar(
        title: const Text(
          "Urgences",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Alerte urgence
          _buildEmergencyAlert(),
          const SizedBox(height: 24),

          // Contact de confiance
          _buildTrustContactSection(),
          const SizedBox(height: 24),

          // Services d'urgence
          _buildSectionTitle("Services d'urgence", Icons.emergency),
          const SizedBox(height: 12),
          ..._buildEmergencyCards(EmergencyType.police),
          ..._buildEmergencyCards(EmergencyType.fire),
          ..._buildEmergencyCards(EmergencyType.ambulance),
          ..._buildEmergencyCards(EmergencyType.civilDefense),

          const SizedBox(height: 24),

          // Hôpitaux
          _buildSectionTitle("Hôpitaux", Icons.local_hospital),
          const SizedBox(height: 12),
          ..._buildEmergencyCards(EmergencyType.hospital),
        ],
      ),
    );
  }

  Widget _buildEmergencyAlert() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE53935).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 48,
          ),
          SizedBox(height: 12),
          Text(
            "En cas d'urgence",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Composez les numéros ci-dessous\npour une assistance immédiate",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.getTextPrimaryColor(context),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildEmergencyCards(EmergencyType type) {
    final services = _emergencyServices.where((s) => s.type == type).toList();

    return services.map((service) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.getSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: service.color.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _callNumber(service.phone, service.name),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icône
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: service.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      service.icon,
                      color: service.color,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.getTextPrimaryColor(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (service.address != null) ...[
                          Text(
                            service.address!,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.getTextSecondaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: service.color,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              service.phone,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: service.color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Bouton appel
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: service.color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: service.color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.call,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Future<void> _callNumber(String phoneNumber, String serviceName) async {
    // Confirmation avant d'appeler
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone, color: AppColors.primary),
            SizedBox(width: 12),
            Text("Appeler ?"),
          ],
        ),
        content: Text(
          "Voulez-vous appeler\n$serviceName\nau $phoneNumber ?",
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text("Appeler"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Impossible d'appeler $phoneNumber"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      print("❌ Erreur appel: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur: $e"),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

// ✅ MODÈLE DE SERVICE D'URGENCE
class EmergencyService {
  final String name;
  final EmergencyType type;
  final String phone;
  final String? address;
  final IconData icon;
  final Color color;

  EmergencyService({
    required this.name,
    required this.type,
    required this.phone,
    this.address,
    required this.icon,
    required this.color,
  });
}

enum EmergencyType {
  police,
  fire,
  ambulance,
  hospital,
  civilDefense,
}