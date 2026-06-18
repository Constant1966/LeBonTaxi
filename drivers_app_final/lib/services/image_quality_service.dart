// lib/services/image_quality_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Result of an image quality check.
class ImageQualityResult {
  final bool isAcceptable;
  final double qualityScore; // 0.0 – 1.0
  final List<String> issues;
  final List<String> suggestions;

  const ImageQualityResult({
    required this.isAcceptable,
    required this.qualityScore,
    this.issues = const [],
    this.suggestions = const [],
  });

  /// Quick status label for UI badges.
  String get statusLabel {
    if (isAcceptable && qualityScore >= 0.75) return 'Bonne qualité';
    if (isAcceptable) return 'Qualité acceptable';
    return 'Qualité insuffisante';
  }

  /// 'good' | 'warning' | 'error'
  String get badgeLevel {
    if (isAcceptable && qualityScore >= 0.75) return 'good';
    if (isAcceptable) return 'warning';
    return 'error';
  }
}

/// Client-side image quality checker.
/// Validates file size, resolution, aspect ratio and brightness.
class ImageQualityService {
  // ── Thresholds ────────────────────────────────────────────────────────

  static const int _minFileSizeBytes = 50 * 1024; // 50 KB
  static const int _maxFileSizeBytes = 15 * 1024 * 1024; // 15 MB
  static const int _minWidth = 640;
  static const int _minHeight = 480;
  static const double _minAspectRatio = 0.4; // portrait max
  static const double _maxAspectRatio = 4.0; // landscape max
  static const double _minBrightness = 0.15; // too dark
  static const double _maxBrightness = 0.92; // too bright / overexposed
  static const double _minContrastStdDev = 20.0; // too flat / blurry proxy

  // ── Public API ────────────────────────────────────────────────────────

  /// Analyse [file] and return a quality result.
  /// Heavy decoding is done on an isolate to keep the UI thread free.
  static Future<ImageQualityResult> checkFile(File file) async {
    final List<String> issues = [];
    final List<String> suggestions = [];

    // 1. File size
    final int fileSize = await file.length();
    if (fileSize < _minFileSizeBytes) {
      issues.add('Fichier trop petit (${_kb(fileSize)} KB)');
      suggestions.add('Prenez la photo en résolution plus élevée');
      return _reject(issues, suggestions);
    }
    if (fileSize > _maxFileSizeBytes) {
      issues.add('Fichier trop grand (${_mb(fileSize)} MB)');
      suggestions.add('Réduisez la taille de l\'image');
    }

    // 2. Decode image in isolate
    final Uint8List bytes = await file.readAsBytes();
    final _ImageMetrics? metrics =
        await compute(_analyseImageBytes, bytes);

    if (metrics == null) {
      issues.add('Impossible de lire l\'image');
      suggestions.add('Vérifiez que le fichier est une image valide (JPG/PNG)');
      return _reject(issues, suggestions);
    }

    // 3. Resolution
    if (metrics.width < _minWidth || metrics.height < _minHeight) {
      issues.add(
          'Résolution trop faible (${metrics.width}x${metrics.height}px, minimum ${_minWidth}x${_minHeight}px)');
      suggestions.add('Utilisez la caméra principale de votre téléphone');
    }

    // 4. Aspect ratio
    final double ratio = metrics.width / metrics.height;
    if (ratio < _minAspectRatio || ratio > _maxAspectRatio) {
      issues.add('Format d\'image inhabituel (ratio ${ratio.toStringAsFixed(2)})');
      suggestions.add('Cadrez le document en position normale (portrait ou paysage)');
    }

    // 5. Brightness
    if (metrics.brightness < _minBrightness) {
      issues.add('Image trop sombre');
      suggestions.add('Prenez la photo dans un endroit mieux éclairé');
    } else if (metrics.brightness > _maxBrightness) {
      issues.add('Image surexposée / trop claire');
      suggestions.add('Évitez les reflets et la lumière directe sur le document');
    }

    // 6. Contrast / blur proxy
    if (metrics.contrastStdDev < _minContrastStdDev) {
      issues.add('Image floue ou peu contrastée');
      suggestions.add('Tenez le téléphone stable et attendez la mise au point');
    }

    // ── Score ─────────────────────────────────────────────────────────
    final double score = _computeScore(metrics, fileSize, issues.length);
    final bool acceptable = issues.isEmpty ||
        (issues.length == 1 && score >= 0.5);

    return ImageQualityResult(
      isAcceptable: acceptable,
      qualityScore: score,
      issues: issues,
      suggestions: suggestions,
    );
  }

  // ── Private helpers ───────────────────────────────────────────────────

  static ImageQualityResult _reject(
      List<String> issues, List<String> suggestions) {
    return ImageQualityResult(
      isAcceptable: false,
      qualityScore: 0.0,
      issues: issues,
      suggestions: suggestions,
    );
  }

  static double _computeScore(
      _ImageMetrics m, int fileSize, int issueCount) {
    double s = 1.0;
    // Resolution bonus
    final double resPx = m.width * m.height.toDouble();
    if (resPx < 640 * 480) s -= 0.4;
    else if (resPx < 1280 * 720) s -= 0.15;

    // Brightness penalty
    final double bDiff = (m.brightness - 0.5).abs();
    s -= bDiff * 0.3;

    // Contrast bonus
    if (m.contrastStdDev > 40) s += 0.05;
    else if (m.contrastStdDev < _minContrastStdDev) s -= 0.25;

    s -= issueCount * 0.1;
    return s.clamp(0.0, 1.0);
  }

  static int _kb(int bytes) => (bytes / 1024).round();
  static String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);
}

// ── Isolate-safe data class ───────────────────────────────────────────────

class _ImageMetrics {
  final int width;
  final int height;
  final double brightness; // 0.0–1.0
  final double contrastStdDev;

  const _ImageMetrics({
    required this.width,
    required this.height,
    required this.brightness,
    required this.contrastStdDev,
  });
}

/// Top-level function required by [compute].
_ImageMetrics? _analyseImageBytes(Uint8List bytes) {
  try {
    final img.Image? image = img.decodeImage(bytes);
    if (image == null) return null;

    final int w = image.width;
    final int h = image.height;
    final int total = w * h;

    double brightnessSum = 0.0;
    final List<double> greyValues = [];

    for (int y = 0; y < h; y += 4) {
      for (int x = 0; x < w; x += 4) {
        final pixel = image.getPixel(x, y);
        final double r = pixel.r / 255.0;
        final double g = pixel.g / 255.0;
        final double b = pixel.b / 255.0;
        // Perceptual luminance
        final double lum = 0.299 * r + 0.587 * g + 0.114 * b;
        brightnessSum += lum;
        greyValues.add(lum);
      }
    }

    final int sampledPixels = greyValues.length;
    final double brightness =
        sampledPixels > 0 ? brightnessSum / sampledPixels : 0.5;

    // Std dev of luminance ≈ contrast proxy
    double variance = 0.0;
    for (final v in greyValues) {
      variance += math.pow(v - brightness, 2);
    }
    final double stdDev =
        sampledPixels > 0 ? math.sqrt(variance / sampledPixels) * 255 : 0.0;

    return _ImageMetrics(
      width: w,
      height: h,
      brightness: brightness,
      contrastStdDev: stdDev,
    );
  } catch (_) {
    return null;
  }
}
