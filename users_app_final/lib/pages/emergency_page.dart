import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyPage extends StatefulWidget {
  const EmergencyPage({super.key});

  @override
  State<EmergencyPage> createState() => _EmergencyPageState();
}

class _EmergencyPageState extends State<EmergencyPage> {
  bool _isLoading = true;

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
  }

  Future<void> _getCurrentLocation() async {
    try {
      await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print("❌ Erreur position: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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
          color: Colors.white,
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (service.address != null) ...[
                          Text(
                            service.address!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
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