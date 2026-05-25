import 'package:flutter/material.dart';
import 'package:users_app/services/supabase_service.dart';
import 'package:users_app/theme/app_colors.dart';

class RatingDialogSupabase extends StatefulWidget {
  final String tripID;
  final String driverID;
  final String driverName;

  const RatingDialogSupabase({
    super.key,
    required this.tripID,
    required this.driverID,
    required this.driverName,
  });

  @override
  State<RatingDialogSupabase> createState() => _RatingDialogSupabaseState();
}

class _RatingDialogSupabaseState extends State<RatingDialogSupabase>
    with SingleTickerProviderStateMixin {
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// Texte descriptif pour chaque note
  String _getRatingText() {
    switch (_rating) {
      case 1:
        return "Très mauvais 😡";
      case 2:
        return "Mauvais 😕";
      case 3:
        return "Correct 😐";
      case 4:
        return "Bon 😊";
      case 5:
        return "Excellent ! 🌟";
      default:
        return "Touchez une étoile";
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ✅ ICÔNE
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.sentiment_satisfied_alt,
                        size: 40,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ TITRE
                    const Text(
                      "Comment était votre course ?",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ✅ NOM DU CHAUFFEUR
                    Text(
                      "Avec ${widget.driverName}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ✅ ÉTOILES
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _rating = index + 1;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: AnimatedScale(
                              scale: index < _rating ? 1.2 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                index < _rating ? Icons.star_rounded : Icons.star_border_rounded,
                                size: 40,
                                color: index < _rating
                                    ? AppColors.warning
                                    : Colors.grey.shade300,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 8),

                    // ✅ TEXTE DESCRIPTIF
                    Text(
                      _getRatingText(),
                      style: TextStyle(
                        fontSize: 14,
                        color: _rating > 0 ? AppColors.warning : Colors.grey.shade500,
                        fontWeight: _rating > 0 ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ✅ CHAMP COMMENTAIRE (optionnel)
                    if (_rating > 0) ...[
                      TextField(
                        controller: _commentController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: "Un commentaire ? (optionnel)",
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ✅ BOUTON ENVOYER (visible quand étoile sélectionnée)
                    if (_rating > 0)
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : () => _submit(skip: false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  "Envoyer ($_rating étoile${_rating > 1 ? 's' : ''})",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                    if (_rating > 0) const SizedBox(height: 12),

                    // ✅ BOUTON PASSER
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: TextButton(
                        onPressed: _isSubmitting ? null : () => _submit(skip: true),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Passer",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit({required bool skip}) async {
    setState(() => _isSubmitting = true);

    try {
      if (!skip && _rating > 0) {
        // ✅ Sauvegarder la note
        await SupabaseService.supabase
            .from('trip_requests')
            .update({
          'rating': _rating,
          'comment': _commentController.text.trim().isNotEmpty
              ? _commentController.text.trim()
              : null,
          'rated_at': DateTime.now().toIso8601String(),
        })
            .eq('trip_id', widget.tripID);

        print("✅ Note sauvegardée: $_rating étoiles");

        // Mettre à jour la note moyenne du chauffeur
        await _updateDriverRating();
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      print("❌ Erreur rating: $e");
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  Future<void> _updateDriverRating() async {
    try {
      // Récupérer toutes les courses notées du chauffeur
      final trips = await SupabaseService.supabase
          .from('trip_requests')
          .select('rating')
          .eq('driver_id', widget.driverID)
          .not('rating', 'is', null);

      if (trips.isEmpty) return;

      int totalRating = 0;
      int ratingCount = 0;

      for (var trip in trips) {
        if (trip['rating'] != null) {
          totalRating += (trip['rating'] as int);
          ratingCount++;
        }
      }

      if (ratingCount > 0) {
        double averageRating = totalRating / ratingCount;

        // Mettre à jour le profil du chauffeur
        await SupabaseService.supabase
            .from('drivers')
            .update({
          'rating': averageRating,
        })
            .eq('id', widget.driverID);

        print("✅ Note moyenne mise à jour: $averageRating");
      }
    } catch (e) {
      print("❌ Erreur update rating: $e");
    }
  }
}