import 'package:flutter/material.dart';

/// Constantes de couleurs centralisées — Style ECab Navy Dark
class AppColors {
  // ─── Dark mode (Navy blue ECab style) ─────
  static const Color darkBg = Color(0xFF0C1527);
  static const Color darkCard = Color(0xFF111C32);
  static const Color darkCardHover = Color(0xFF162240);
  static const Color darkBorder = Color(0xFF1E3254);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);
  static const Color darkDivider = Color(0xFF1E3254);

  // ─── Light mode ───────────────────────
  static const Color lightBg = Color(0xFFF8F9FB);
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightTextSecondary = Color(0xFF6B7280);

  // ─── Brand ────────────────────────────
  static const Color primary = Color(0xFF6366F1);
  static const Color success = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color cyan = Color(0xFF06B6D4);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color pink = Color(0xFFEC4899);
  static const Color taxiYellow = Color(0xFFFBBF24);

  // ─── Helpers ──────────────────────────
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color card(bool isDark) => isDark ? darkCard : lightCard;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color textPrimary(bool isDark) => isDark ? darkTextPrimary : const Color(0xFF1F2937);
  static Color textSecondary(bool isDark) => isDark ? darkTextSecondary : lightTextSecondary;
  static Color textTertiary(bool isDark) => isDark ? darkTextTertiary : const Color(0xFF9CA3AF);
}
