import '../constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/admin_log_service.dart';

class ReviewsPage extends StatefulWidget {
  static const String id = "\\webPageReviews";
  const ReviewsPage({super.key});

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  final supabase = Supabase.instance.client;
  int? _ratingFilter;
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    try {
      var query = supabase.from('reviews').select();
      if (_ratingFilter != null) {
        query = query.eq('rating', _ratingFilter!);
      }
      final data = await query.order('created_at', ascending: false);
      if (mounted) setState(() { _reviews = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showReplyDialog(Map<String, dynamic> review) {
    final replyCtrl = TextEditingController(text: review['admin_response']?.toString() ?? '');
    String replyType = review['admin_response_type'] ?? 'public';

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Répondre au commentaire", style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: SizedBox(width: 450, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isDark ? AppColors.darkBg : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ...List.generate(5, (i) => Icon(Icons.star, size: 16, color: i < (review['rating'] ?? 0) ? const Color(0xFFF59E0B) : (isDark ? AppColors.darkBorder : Colors.grey.shade300))),
                  const SizedBox(width: 8),
                  Text(review['user_name']?.toString() ?? 'Client', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                ]),
                const SizedBox(height: 8),
                Text(review['comment']?.toString() ?? 'Pas de commentaire', style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              ChoiceChip(label: const Text("Public"), selected: replyType == 'public', selectedColor: const Color(0xFF6366F1), labelStyle: TextStyle(color: replyType == 'public' ? Colors.white : null), onSelected: (_) => setDlg(() => replyType = 'public')),
              const SizedBox(width: 8),
              ChoiceChip(label: const Text("Privé"), selected: replyType == 'private', selectedColor: const Color(0xFF6366F1), labelStyle: TextStyle(color: replyType == 'private' ? Colors.white : null), onSelected: (_) => setDlg(() => replyType = 'private')),
            ]),
            const SizedBox(height: 12),
            TextFormField(
              controller: replyCtrl, 
              maxLines: 4, 
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(labelText: "Votre réponse", labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54), alignLabelWithHint: true)
            ),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              if (replyCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await supabase.from('reviews').update({
                  'admin_response': replyCtrl.text,
                  'admin_response_type': replyType,
                  'admin_response_at': DateTime.now().toIso8601String(),
                }).eq('id', review['id']);
                await AdminLogService.log(action: 'Réponse commentaire', targetType: 'review', targetId: review['id']?.toString(), details: {'type': replyType});
                _loadReviews();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Réponse envoyée"), backgroundColor: Colors.green));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
            child: const Text("Envoyer"),
          ),
        ],
      );
    }));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Statistiques
    double avgRating = _reviews.isNotEmpty ? _reviews.fold<double>(0, (sum, r) => sum + ((r['rating'] ?? 0) as num).toDouble()) / _reviews.length : 0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Commentaires & Avis", style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("Gérer les avis clients et le support", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            ]),
            if (_reviews.isNotEmpty) Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFF59E0B).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 6),
                Text("${avgRating.toStringAsFixed(1)} / 5", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
                Text(" (${_reviews.length} avis)", style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 12)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          // Filtres par étoiles
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              FilterChip(label: const Text("Toutes"), selected: _ratingFilter == null, selectedColor: const Color(0xFF6366F1), checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: _ratingFilter == null ? Colors.white : null, fontSize: 12), onSelected: (_) { setState(() => _ratingFilter = null); _loadReviews(); }),
              const SizedBox(width: 8),
              ...List.generate(5, (i) {
                final stars = 5 - i;
                return Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(
                  label: Row(mainAxisSize: MainAxisSize.min, children: [Text("$stars "), const Icon(Icons.star, size: 14, color: Color(0xFFF59E0B))]),
                  selected: _ratingFilter == stars, selectedColor: const Color(0xFF6366F1), checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: _ratingFilter == stars ? Colors.white : null, fontSize: 12),
                  onSelected: (_) { setState(() => _ratingFilter = stars); _loadReviews(); },
                ));
              }),
            ]),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reviews.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.reviews_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text("Aucun avis trouvé", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                      ]))
                    : ListView.builder(itemCount: _reviews.length, itemBuilder: (ctx, i) => _buildReviewCard(_reviews[i], isDark)),
          ),
        ]),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review, bool isDark) {
    final rating = (review['rating'] ?? 0) as int;
    final hasResponse = review['admin_response'] != null && review['admin_response'].toString().isNotEmpty;
    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 10),
      color: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200)),
      child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 18, backgroundColor: const Color(0xFF8B5CF6).withOpacity(0.1), child: Text(
            (review['user_name']?.toString().isNotEmpty == true) ? review['user_name'].toString()[0].toUpperCase() : '?',
            style: const TextStyle(color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold),
          )),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(review['user_name']?.toString() ?? 'Client', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
            Text("Chauffeur: ${review['driver_name'] ?? 'N/A'}", style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
          ])),
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (i) => Icon(Icons.star, size: 16, color: i < rating ? const Color(0xFFF59E0B) : (isDark ? AppColors.darkBorder : Colors.grey.shade300)))),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showReplyDialog(review),
            icon: Icon(hasResponse ? Icons.edit : Icons.reply, size: 16),
            label: Text(hasResponse ? "Modifier" : "Répondre", style: const TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          ),
        ]),
        const SizedBox(height: 12),
        Text(review['comment']?.toString() ?? 'Pas de commentaire', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
        if (hasResponse) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF6366F1).withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.admin_panel_settings, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Text("Réponse admin (${review['admin_response_type'] ?? 'public'})", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
              ]),
              const SizedBox(height: 6),
              Text(review['admin_response'].toString(), style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87)),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        Text(review['created_at']?.toString().substring(0, 16) ?? '', style: TextStyle(fontSize: 11, color: isDark ? Colors.grey.shade400 : Colors.grey.shade500)),
      ])),
    );
  }
}