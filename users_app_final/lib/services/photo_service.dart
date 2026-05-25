import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PhotoService {
  static final ImagePicker _picker = ImagePicker();
  static final _supabase = Supabase.instance.client;

  /// Demander permission caméra
  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Prendre photo avec caméra
  static Future<File?> takePhoto() async {
    try {
      // Vérifier permission
      final hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        print("❌ Permission caméra refusée");
        return null;
      }

      // Prendre photo
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo == null) {
        print("⚠️ Aucune photo prise");
        return null;
      }

      print("✅ Photo prise: ${photo.path}");
      return File(photo.path);
    } catch (e) {
      print("❌ Erreur prise photo: $e");
      return null;
    }
  }

  /// Choisir photo depuis galerie
  static Future<File?> pickFromGallery() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo == null) return null;

      return File(photo.path);
    } catch (e) {
      print("❌ Erreur galerie: $e");
      return null;
    }
  }

  /// Uploader photo vers Supabase Storage
  static Future<String?> uploadPhoto(File photo, String userId) async {
    try {
      final fileName = 'profile_$userId.jpg';
      final filePath = 'profiles/$fileName';

      print("📤 Upload photo: $filePath");

      // Upload vers Supabase Storage
      await _supabase.storage
          .from('user-photos')
          .upload(
        filePath,
        photo,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );

      // Obtenir URL publique
      final photoUrl = _supabase.storage
          .from('user-photos')
          .getPublicUrl(filePath);

      print("✅ Photo uploadée: $photoUrl");
      return photoUrl;
    } catch (e) {
      print("❌ Erreur upload: $e");
      return null;
    }
  }

  /// Dialog pour choisir source (caméra ou galerie)
  static Future<File?> showPhotoSourceDialog(BuildContext context) async {
    return await showModalBottomSheet<File?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Choisir une photo",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Bouton Caméra
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.blue),
                ),
                title: const Text("Prendre une photo"),
                subtitle: const Text("Utilisez votre caméra"),
                onTap: () async {
                  final photo = await takePhoto();
                  if (context.mounted) {
                    Navigator.pop(context, photo);
                  }
                },
              ),

              const SizedBox(height: 12),

              // Bouton Galerie
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.green),
                ),
                title: const Text("Choisir depuis galerie"),
                subtitle: const Text("Sélectionnez une photo existante"),
                onTap: () async {
                  final photo = await pickFromGallery();
                  if (context.mounted) {
                    Navigator.pop(context, photo);
                  }
                },
              ),

              const SizedBox(height: 12),

              // Bouton Annuler
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Annuler"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}