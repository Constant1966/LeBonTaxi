import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/theme/app_colors.dart';
import 'package:users_app/global/global_var_supabase.dart';

class ReferralPage extends StatefulWidget {
  const ReferralPage({super.key});

  @override
  State<ReferralPage> createState() => _ReferralPageState();
}

class _ReferralPageState extends State<ReferralPage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initReferralCode();
  }

  Future<void> _initReferralCode() async {
    try {
      final profile = await SupabaseService.getUserProfile();
      if (profile != null) {
        if (profile['referral_code'] == null || profile['referral_code'].toString().isEmpty) {
          final myName = profile['name']?.toString() ?? userName;
          await SupabaseService.generateAndSaveReferralCode(myName);
        }
      }
    } catch (e) {
      print("⚠️ Erreur initialisation code de parrainage: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _copyToClipboard() {
    final code = currentUserReferralCode ?? '';
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text("Code $code copié dans le presse-papiers !"),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _shareApp() {
    final code = currentUserReferralCode ?? '';
    if (code.isNotEmpty) {
      final message = globalReferralShareMessage.replaceAll('{code}', code);
      Share.share(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final codeToShow = currentUserReferralCode ?? 'LBT-XXXX';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.background : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Parrainage"),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.textPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ✅ En-tête avec illustration cadeau
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.card_giftcard,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Offrez des réductions, gagnez des trajets !",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Partagez votre code promo unique. Lorsque vos amis rejoignent LeBonTaxi, vous bénéficiez de réductions spéciales configurées par l'administration !",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ✅ Carte d'affichage du Code Promo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            "VOTRE CODE PROMO DE PARRAINAGE",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade500,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                codeToShow,
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                                tooltip: "Copier le code",
                                onPressed: _copyToClipboard,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: _shareApp,
                              icon: const Icon(Icons.share_rounded, color: Colors.white),
                              label: const Text(
                                "PARTAGER MON CODE",
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ✅ Section Historique des Parrainages
                    Text(
                      "Mes amis parrainés",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildReferralsList(isDark),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReferralsList(bool isDark) {
    if (SupabaseService.userId == null) {
      return const SizedBox();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchReferralRewards(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Impossible de charger l'historique : ${snapshot.error}",
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          );
        }

        final rewards = snapshot.data ?? [];

        if (rewards.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 12),
                Text(
                  "Aucun ami parrainé pour le moment",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rewards.length,
          itemBuilder: (context, index) {
            final reward = rewards[index];
            final referred = reward['referred'] as Map<String, dynamic>?;
            final isWelcome = reward.containsKey('is_welcome') && reward['is_welcome'] == true;

            final referredName = referred?['name']?.toString() ?? 
                (isWelcome ? 'Parrain' : 'Ami parrainé');
            final referredEmail = referred?['email']?.toString() ?? '';
            final isUsed = reward['status'] == 'used';
            final rewardValue = reward['reward_value'] as num? ?? 0;
            final rewardType = reward['reward_type'] == 'percentage' ? '%' : ' HTG';

            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isUsed 
                      ? Colors.grey.shade200 
                      : (isWelcome ? Colors.purple.withOpacity(0.12) : AppColors.primary.withOpacity(0.1)),
                  child: Icon(
                    isWelcome ? Icons.card_giftcard : Icons.person,
                    color: isUsed 
                        ? Colors.grey.shade600 
                        : (isWelcome ? Colors.purple.shade600 : AppColors.primary),
                  ),
                ),
                title: Text(
                  isWelcome ? "Récompense de Bienvenue" : referredName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                subtitle: Text(
                  isWelcome
                      ? "Parrainé par : $referredName\nGain : -$rewardValue$rewardType"
                      : "Gain : -$rewardValue$rewardType\n$referredEmail",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isUsed 
                        ? Colors.grey.shade200 
                        : AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isUsed ? "Utilisé" : "Disponible",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isUsed ? Colors.grey.shade700 : AppColors.success,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchReferralRewards() async {
    try {
      if (SupabaseService.userId == null) return [];
      try {
        final response = await SupabaseService.supabase
            .from('referral_rewards')
            .select('reward_value, reward_type, status, created_at, is_welcome, referred:referred_id(name, email)')
            .eq('referrer_id', SupabaseService.userId!)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response as List);
      } catch (dbErr) {
        print("⚠️ Colonne is_welcome absente de referral_rewards, fallback select: $dbErr");
        final response = await SupabaseService.supabase
            .from('referral_rewards')
            .select('reward_value, reward_type, status, created_at, referred:referred_id(name, email)')
            .eq('referrer_id', SupabaseService.userId!)
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response as List);
      }
    } catch (e) {
      print("❌ Erreur _fetchReferralRewards: $e");
      return [];
    }
  }
}
