import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:users_app/theme/app_colors.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<_Feature> _features = const [
    _Feature(icon: Icons.security, title: "Courses sécurisées", color: AppColors.primary),
    _Feature(icon: Icons.attach_money, title: "Prix transparents", color: AppColors.success),
    _Feature(icon: Icons.speed, title: "Service rapide", color: AppColors.accent),
    _Feature(icon: Icons.support_agent, title: "Support 24/7", color: AppColors.info),
  ];

  final List<_ContactMethod> _contacts = [
    const _ContactMethod(
      icon: Icons.email,
      label: "Email",
      value: "constantlorvenson@gmail.com",
      action: _launchEmail,
    ),
    const _ContactMethod(
      icon: Icons.phone,
      label: "Support",
      value: "+509 1234-5678",
      action: _launchPhone,
    ),
    const _ContactMethod(
      icon: Icons.language,
      label: "Site web",
      value: "www.lebontaxi.com",
      action: _launchWebsite,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDescription(),
                    const SizedBox(height: 20),
                    _buildFeatures(),
                    const SizedBox(height: 20),
                    _buildContact(),
                    const SizedBox(height: 32),
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: const Text(
        "À Propos",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
      ),
      child: Column(
        children: [
          _buildLogo(),
          const SizedBox(height: 20),
          const Text(
            "Le Bon Taxi",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            "Version 1.0.0",
            style: TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Image.asset(
        "assets/images/lebontaxi_logo.png",
        width: 80,
        height: 80,
        errorBuilder: (_, __, ___) => const Icon(Icons.local_taxi, size: 80, color: AppColors.primary),
      ),
    );
  }

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.info_outline, "À propos de l'application", AppColors.primary),
          const SizedBox(height: 16),
          const Text(
            "Le Bon Taxi est votre service de transport préféré en Haïti. "
                "Nous offrons des courses sûres, fiables et abordables dans toute la région.",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatures() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.stars, "Nos avantages", AppColors.accent),
          const SizedBox(height: 16),
          ..._features.map((f) => _buildFeatureItem(f)),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(_Feature feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: feature.color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(feature.icon, size: 20, color: feature.color),
          ),
          const SizedBox(width: 12),
          Text(feature.title, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildContact() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _buildCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(Icons.contact_support, "Contactez-nous", AppColors.success),
          const SizedBox(height: 16),
          const Text(
            "Pour toute question ou signalement:",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          ..._contacts.map((c) => _buildContactItem(c)),
        ],
      ),
    );
  }

  Widget _buildContactItem(_ContactMethod contact) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => contact.action(contact.value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(contact.icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contact.label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      contact.value,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          "© ${DateTime.now().year} Le Bon Taxi. Tous droits réservés.",
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  BoxDecoration _buildCardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
    );
  }

  static Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email, query: 'subject=Support Le Bon Taxi');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'\s+'), ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static Future<void> _launchWebsite(String url) async {
    final uri = Uri.parse('https://$url');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final Color color;

  const _Feature({required this.icon, required this.title, required this.color});
}

class _ContactMethod {
  final IconData icon;
  final String label;
  final String value;
  final Function(String) action;

  const _ContactMethod({
    required this.icon,
    required this.label,
    required this.value,
    required this.action,
  });
}